import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import '../widgets.dart';
import 'home_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _hide = true;

  Future<void> _login() async {
    if (_user.text.trim().isEmpty || _pass.text.isEmpty) {
      toast(context, 'User ID aur password daalein', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await Api.post('/login', {'userId': _user.text.trim(), 'password': _pass.text});
      await Api.saveToken(r['token'] as String);
      await Api.saveUserName(_user.text);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeShell()), (_) => false);
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF062B20), kPrimary], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: Stack(
          children: [
            Positioned(
              bottom: -40,
              right: -40,
              child: Icon(Icons.home_work_rounded, size: 300, color: Colors.white.withAlpha(14)),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.home_work_rounded, color: kGold, size: 64),
                      const SizedBox(height: 8),
                      const Text('EstateSathi',
                          style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('Rent Management\nMade Simple',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 15, height: 1.4)),
                      const SizedBox(height: 30),
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                        child: Column(
                          children: [
                            const Text('Welcome Back', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            const Text('Login to manage your properties', style: TextStyle(color: kGrey, fontSize: 13)),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _user,
                              decoration: const InputDecoration(labelText: 'Email / User ID', prefixIcon: Icon(Icons.person_outline_rounded)),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _pass,
                              obscureText: _hide,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                  onPressed: () => setState(() => _hide = !_hide),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _busy ? null : _login,
                                child: _busy
                                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text('Login'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: Colors.white70),
                        onPressed: () async {
                          await editServerUrl(context);
                        },
                        icon: const Icon(Icons.dns_outlined, size: 18),
                        label: const Text('Server settings'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
