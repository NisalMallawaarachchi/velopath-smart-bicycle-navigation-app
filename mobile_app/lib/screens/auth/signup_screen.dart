import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    // Test connection when screen loads (optional)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _testBackendConnection();
    });
  }

  Future<void> _testBackendConnection() async {
    print("Testing backend connection...");
    try {
      final response = await http.get(
        Uri.parse("http://10.0.2.2:5001"),
      ).timeout(const Duration(seconds: 5));
      print("Backend is reachable. Status: ${response.statusCode}");
    } catch (e) {
      print("Backend connection test failed: $e");
    }
  }

  Future<void> handleSignup() async {
    print("=== SIGNUP PROCESS STARTED ===");
    
    // Validate form
    if (!_formKey.currentState!.validate()) {
      print("Form validation failed");
      return;
    }

    // Check if passwords match
    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Passwords do not match"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      print("Calling AuthService.register...");
      print("Data: ${{
        'username': nameController.text.trim(),
        'email': emailController.text.trim(),
        'password': '***' // Don't log actual password
      }}");

      await AuthService.register(
        username: nameController.text.trim(),
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      print("Registration API call successful");

      if (!mounted) {
        print("Widget not mounted after registration");
        return;
      }

      // Show success dialog
      await _showSuccessDialog();

      // Navigate back to login
      Navigator.pop(context);

    } catch (e) {
      print("=== REGISTRATION ERROR ===");
      print("Error type: ${e.runtimeType}");
      print("Error message: $e");
      
      if (!mounted) return;
      
      _showErrorDialog(e.toString());
      
    } finally {
      print("Setting isLoading to false");
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _showSuccessDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Success!", style: TextStyle(color: Colors.green)),
        content: const Text("Account created successfully. You can now login."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    // First show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Error: $error"),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
    
    // Then show a dialog for more details
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Registration Failed"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Could not create account. Possible reasons:"),
            const SizedBox(height: 10),
            Text("• $error", style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 10),
            const Text("• Backend server not running"),
            const Text("• Network connection issue"),
            const Text("• Email already registered"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _testBackendConnection();
            },
            child: const Text("Test Connection"),
          ),
        ],
      ),
    );
  }

  // Form validation methods
  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your name';
    }
    if (value.length < 3) {
      return 'Name must be at least 3 characters';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Back to Login',
                ),

                const SizedBox(height: 10),

                // Logo
                Center(
                  child: Image.asset(
                    'assets/logo.png',
                    height: 120,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.account_circle, size: 100, color: Colors.blue);
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // Title
                const Center(
                  child: Text(
                    "Create Account",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0E417A),
                    ),
                  ),
                ),

                const SizedBox(height: 5),

                const Center(
                  child: Text(
                    "Join our community today",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Username field
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "Full Name",
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                    hintText: "Enter your full name",
                  ),
                  validator: _validateName,
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 20),

                // Email field
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: "Email Address",
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                    hintText: "Enter your email",
                  ),
                  validator: _validateEmail,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 20),

                // Password field
                TextFormField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    hintText: "Enter your password",
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: _validatePassword,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 20),

                // Confirm Password field
                TextFormField(
                  controller: confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: "Confirm Password",
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    hintText: "Re-enter your password",
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                  validator: _validateConfirmPassword,
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => handleSignup(),
                ),

                const SizedBox(height: 30),

                // Terms and conditions
                Row(
                  children: [
                    Checkbox(
                      value: true,
                      onChanged: (value) {},
                      activeColor: const Color(0xFF0E417A),
                    ),
                    Expanded(
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(color: Colors.black, fontSize: 14),
                          children: [
                            TextSpan(text: "I agree to the "),
                            TextSpan(
                              text: "Terms & Conditions",
                              style: TextStyle(
                                color: Color(0xFF0E417A),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(text: " and "),
                            TextSpan(
                              text: "Privacy Policy",
                              style: TextStyle(
                                color: Color(0xFF0E417A),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // Sign Up Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0E417A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 3,
                    ),
                    onPressed: isLoading ? null : handleSignup,
                    child: isLoading
                        ? const SizedBox(
                            height: 25,
                            width: 25,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : const Text(
                            "Create Account",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // Divider
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: Colors.grey[400],
                        thickness: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "or sign up with",
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: Colors.grey[400],
                        thickness: 1,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Social buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon: Image.asset(
                        'assets/google.png',
                        height: 40,
                        width: 40,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(width: 20),
                    IconButton(
                      onPressed: () {},
                      icon: Image.asset(
                        'assets/facebook.png',
                        height: 40,
                        width: 40,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // Login link
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                        children: [
                          TextSpan(text: "Already have an account? "),
                          TextSpan(
                            text: "Login",
                            style: TextStyle(
                              color: Color(0xFF0E417A),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}