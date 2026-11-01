import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class Api {
  // Local browser testing ke liye backend isi PC par chalayein.
  static String baseUrl = 'http://localhost:5000';
  static String? token;
  static String userName = 'Owner';
  static void Function()? onUnauthorized;

  static Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    baseUrl = p.getString('baseUrl') ?? baseUrl;
    token = p.getString('token');
    userName = p.getString('userName') ?? userName;
  }

  static Future<void> saveBaseUrl(String url) async {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (u.isNotEmpty && !u.startsWith('http')) u = 'http://$u';
    baseUrl = u;
    final p = await SharedPreferences.getInstance();
    await p.setString('baseUrl', u);
  }

  static Future<void> saveToken(String? t) async {
    token = t;
    final p = await SharedPreferences.getInstance();
    if (t == null) {
      await p.remove('token');
    } else {
      await p.setString('token', t);
    }
  }

  static Future<void> saveUserName(String name) async {
    final n = name.trim();
    userName = n.isEmpty ? 'Owner' : n[0].toUpperCase() + n.substring(1);
    final p = await SharedPreferences.getInstance();
    await p.setString('userName', userName);
  }

  static Future<void> logout() => saveToken(null);

  static String fileUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    final uri = Uri.tryParse(path);
    return uri != null && uri.hasScheme ? path : '$baseUrl$path';
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static dynamic _handle(http.Response r) {
    dynamic body;
    try {
      body = jsonDecode(r.body);
    } catch (_) {}
    if (r.statusCode >= 200 && r.statusCode < 300) return body;
    if (r.statusCode == 401 && token != null) {
      logout();
      onUnauthorized?.call();
    }
    throw ApiException(body is Map && body['error'] != null ? '${body['error']}' : 'Error ${r.statusCode}');
  }

  static Future<dynamic> _send(Future<http.Response> Function() fn, {Duration timeout = const Duration(seconds: 30)}) async {
    try {
      return _handle(await fn().timeout(timeout));
    } on TimeoutException {
      throw ApiException('Server ne jawab nahi diya. Dobara try karein.');
    } on http.ClientException {
      throw ApiException('Network error. Server URL check karein.');
    } on FormatException {
      throw ApiException('Server URL galat hai.');
    }
  }

  static Uri _u(String path) => Uri.parse('$baseUrl/api$path');

  static Future<dynamic> get(String path) => _send(() => http.get(_u(path), headers: _headers));

  static Future<dynamic> post(String path, Map<String, dynamic> body) =>
      _send(() => http.post(_u(path), headers: _headers, body: jsonEncode(body)));

  static Future<dynamic> delete(String path) => _send(() => http.delete(_u(path), headers: _headers));

  static Future<dynamic> multipart(String method, String path, Map<String, String> fields, Map<String, XFile?> files) {
    return _send(() async {
      final req = http.MultipartRequest(method, _u(path));
      if (token != null) req.headers['Authorization'] = 'Bearer $token';
      req.fields.addAll(fields);
      for (final e in files.entries) {
        final file = e.value;
        if (file != null) {
          final extension = file.name.split('.').last.toLowerCase();
          final subtype = extension == 'jpg' ? 'jpeg' : extension;
          req.files.add(http.MultipartFile.fromBytes(
            e.key,
            await file.readAsBytes(),
            filename: file.name,
            contentType: MediaType('image', subtype),
          ));
        }
      }
      return http.Response.fromStream(await req.send());
    }, timeout: const Duration(seconds: 120));
  }
}
