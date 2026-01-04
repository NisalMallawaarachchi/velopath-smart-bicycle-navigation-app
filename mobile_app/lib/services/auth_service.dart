import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;

class AuthService {
  // 🔁 Emulator → 10.0.2.2
  // 📱 Real device → your PC IP
  static const String baseUrl = "http://10.0.2.2:5001/api/auth";

  // LOGIN
  static Future<String> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "password": password,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data["token"];
    } else {
      throw Exception(data["message"]);
    }
  }

  /// REGISTER
  static Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      print("Sending request to: $baseUrl/register");

      final response = await http
          .post(
            Uri.parse("$baseUrl/register"),
            headers: {
              "Content-Type": "application/json",
            },
            body: jsonEncode({
              "username": username,
              "email": email,
              "password": password,
            }),
          )
          .timeout(const Duration(seconds: 10));

      print("Status code: ${response.statusCode}");
      print("Response body: ${response.body}");

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return;
      } else {
        throw Exception(data["message"] ?? "Registration failed");
      }
    } on SocketException {
      throw Exception("No internet connection or backend unreachable");
    } on TimeoutException {
      throw Exception("Request timeout");
    } on FormatException {
      throw Exception("Invalid server response");
    } catch (e) {
      rethrow;
    }
  }
}
