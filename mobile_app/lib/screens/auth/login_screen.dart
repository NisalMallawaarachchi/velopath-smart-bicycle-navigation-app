import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'signup_screen.dart';
import '../dashboard_screen.dart';
import '../../modules/motion_trace/providers/motion_trace_provider.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                Center(child: Image.asset('assets/logo.png', height: 120)),

                const SizedBox(height: 30),

                const Text(
                  "Welcome Back 👋",
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 10),

                const Text(
                  "Login to continue",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),

                const SizedBox(height: 40),

                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 20),

                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Password",
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromARGB(255, 28, 76, 128),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () async {
                      // Navigate to dashboard
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) {
                            // Request sensor permissions after first login
                            Future.delayed(
                                const Duration(milliseconds: 500), () {
                              final motionTrace =
                                  ctx.read<MotionTraceProvider>();
                              if (!motionTrace.allPermissionsGranted) {
                                motionTrace
                                    .requestPermissionsAfterLogin(ctx);
                              }
                            });
                            return const DashboardScreen();
                          },
                        ),
                      );
                    },
                    child: const Text(
                      "Login",
                      style: TextStyle(fontSize: 20, color: Colors.white),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? "),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SignupScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        "Sign Up",
                        style: TextStyle(
                          color: Color.fromARGB(255, 15, 73, 124),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
