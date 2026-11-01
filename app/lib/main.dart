import 'package:flutter/material.dart';
import 'api.dart';
import 'theme.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.init();
  Api.onUnauthorized = () {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  };
  runApp(const EstateSathiApp());
}

class EstateSathiApp extends StatelessWidget {
  const EstateSathiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EstateSathi',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: buildTheme(),
      home: const EstateSathiSplashScreen(),
    );
  }
}

class EstateSathiSplashScreen extends StatefulWidget {
  const EstateSathiSplashScreen({super.key});

  @override
  State<EstateSathiSplashScreen> createState() =>
      _EstateSathiSplashScreenState();
}

class _EstateSathiSplashScreenState extends State<EstateSathiSplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              Api.token != null ? const HomeShell() : const LoginScreen(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF003B35),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'web/estateSathi.png',
              width: 260,
              height: 260,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            const Text(
              'ek rishta ghar k sath',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFFFD27A),
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
