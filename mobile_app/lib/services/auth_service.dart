import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class AuthService {
  static String get baseUrl => "${ApiConfig.baseUrl}/api/auth";

  /// LOGIN — returns full response with token + user data
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/login"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"email": email, "password": password}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Login failed');
      }
    } on SocketException {
      throw Exception('Cannot reach server. Check your network connection.');
    } on TimeoutException {
      throw Exception('Request timed out. Please try again.');
    } on FormatException {
      throw Exception('Invalid server response');
    }
  }

  /// REGISTER — returns full response with token + user data
  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    String? country,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/register"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "username": username,
              "email": email,
              "password": password,
              if (country != null) "country": country,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Registration failed');
      }
    } on SocketException {
      throw Exception('Cannot reach server. Check your network connection.');
    } on TimeoutException {
      throw Exception('Request timed out. Please try again.');
    } on FormatException {
      throw Exception('Invalid server response');
    }
  }

  /// GET PROFILE — fetch current user info from token
  static Future<Map<String, dynamic>> getProfile(String token) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/me"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return data['user'];
      } else {
        throw Exception(data['message'] ?? 'Failed to fetch profile');
      }
    } on SocketException {
      throw Exception('Cannot reach server');
    } on TimeoutException {
      throw Exception('Request timed out');
    }
  }

  /// UPDATE PROFILE — update username and country
  static Future<Map<String, dynamic>> updateProfile({
    required String token,
    required String username,
    String? country,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse("$baseUrl/me"),
            headers: {
              "Content-Type": "application/json",
              "Authorization": "Bearer $token",
            },
            body: jsonEncode({
              "username": username,
              if (country != null) "country": country,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return data['user'];
      } else {
        throw Exception(data['message'] ?? 'Failed to update profile');
      }
    } on SocketException {
      throw Exception('Cannot reach server');
    } on TimeoutException {
      throw Exception('Request timed out');
    }
  }

  /// GOOGLE LOGIN
  static Future<Map<String, dynamic>> googleLogin(String idToken) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/google"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"idToken": idToken}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Google Login failed');
      }
    } on SocketException {
      throw Exception('Cannot reach server. Check your network connection.');
    } on TimeoutException {
      throw Exception('Request timed out. Please try again.');
    } on FormatException {
      throw Exception('Invalid server response');
    }
  }
}
