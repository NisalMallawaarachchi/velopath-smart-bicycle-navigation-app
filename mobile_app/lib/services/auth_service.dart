import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static const String baseUrl =
      "http://192.168.8.191:3000/api/auth";

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

  // REGISTER
  static Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "username": username,
        "email": email,
        "password": password,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 201) {
      throw Exception(data["message"]);
    }
  }
}
