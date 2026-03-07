import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'auth/login_screen.dart';
import 'main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Show splash for at least 1.5s
    final minDelay = Future.delayed(const Duration(milliseconds: 1500));

    final auth = context.read<AuthProvider>();
    final hasSession = await auth.tryAutoLogin();

    await minDelay; // wait for splash animation

    if (!mounted) return;

    if (hasSession) {
      // Token valid → go straight to app
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } else {
      // No token or expired → login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(174, 122, 212, 188),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo.png',
              width: 400,
              height: 400,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
