import 'package:another_telephony/telephony.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'widgets.dart';

num n(dynamic v) => v is num ? v : (num.tryParse('${v ?? ''}') ?? 0);

String rupee(dynamic v) {
  final x = n(v);
  return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: x % 1 == 0 ? 0 : 2).format(x);
}

String fmtNum(dynamic v) {
  final x = n(v);
  return x % 1 == 0 ? x.toInt().toString() : x.toStringAsFixed(2);
}

DateTime parseD(dynamic s) => s is DateTime ? s : DateTime.parse('$s');
String fmtDate(dynamic s) => DateFormat('dd MMM yyyy').format(parseD(s));
String fmtMonth(dynamic s) => DateFormat('MMMM yyyy').format(parseD(s));
String apiDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

String ordinal(int d) {
  if (d >= 11 && d <= 13) return '${d}th';
  switch (d % 10) {
    case 1:
      return '${d}st';
    case 2:
      return '${d}nd';
    case 3:
      return '${d}rd';
    default:
      return '${d}th';
  }
}

String waNumber(String phone) {
  var d = phone.replaceAll(RegExp(r'\D'), '');
  if (d.length == 10) {
    d = '91$d';
  } else if (d.length == 11 && d.startsWith('0')) {
    d = '91${d.substring(1)}';
  }
  return d;
}

String reminderText({
  required String name,
  required String property,
  required String room,
  required dynamic balance,
  required int dueDay,
}) {
  return 'नमस्ते $name जी,\n'
      '$property - $room का ${rupee(balance)} अभी बकाया है। '
      'किराया हर महीने $dueDay तारीख़ को देय होता है। कृपया शीघ्र भुगतान करें।\n'
      'धन्यवाद - EstateSathi';
}

String billText(Map bill, Map detail, num balance) {
  final t = detail['tenant'];
  final b = bill;
  return 'नमस्ते ${t['name']} जी,\n'
      '${detail['property']?['name'] ?? ''} - ${detail['room']?['name'] ?? ''}\n'
      'बिल (${fmtMonth(b['billDate'])})\n'
      'किराया: ${rupee(b['rent'])}\n'
      'बिजली: ${fmtNum(b['units'])} यूनिट × ${rupee(b['rate'])} = ${rupee(b['electricity'])} '
      '(मीटर रीडिंग ${fmtNum(b['prevReading'])} से ${fmtNum(b['newReading'])} तक)\n'
      'पानी: ${rupee(b['water'])}\n'
      'कचरा शुल्क: ${rupee(b['garbage'])}\n'
      'इस बिल का कुल योग: ${rupee(b['total'])}\n'
      'कुल बकाया (सभी मिलाकर): ${rupee(balance)}\n'
      'कृपया समय पर भुगतान करें। - EstateSathi';
}

Future<void> sendWhatsApp(BuildContext c, String phone, String text) async {
  final uri = Uri.parse('https://wa.me/${waNumber(phone)}?text=${Uri.encodeComponent(text)}');
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && c.mounted) toast(c, 'WhatsApp नहीं खुल सका', error: true);
  } catch (_) {
    if (c.mounted) toast(c, 'WhatsApp नहीं खुल सका', error: true);
  }
}

/// अनुमति लेकर सीधे SMS भेजता है। अनुमति न मिले तो SMS ऐप खोलता है।
Future<void> sendSms(BuildContext c, String phone, String text) async {
  final number = phone.replaceAll(RegExp(r'[^\d+]'), '');
  try {
    final granted = await Telephony.instance.requestPhoneAndSmsPermissions;
    if (granted == true) {
      await Telephony.instance.sendSms(to: number, message: text);
      if (c.mounted) toast(c, 'SMS भेज दिया गया');
      return;
    }
  } catch (_) {}
  try {
    await launchUrl(Uri.parse('sms:$number?body=${Uri.encodeComponent(text)}'), mode: LaunchMode.externalApplication);
  } catch (_) {
    if (c.mounted) toast(c, 'SMS नहीं भेजा जा सका', error: true);
  }
}

Future<void> callNumber(String phone) async {
  try {
    await launchUrl(Uri.parse('tel:${phone.replaceAll(RegExp(r'[^\d+]'), '')}'));
  } catch (_) {}
}
