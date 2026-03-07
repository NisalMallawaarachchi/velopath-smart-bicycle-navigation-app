import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';

/// User model for in-memory state
class AppUser {
  final String id;
  final String username;
  final String email;
  final String? country;
  final double reputationScore;
  final int totalContributions;

  AppUser({
    required this.id,
    required this.username,
    required this.email,
    this.country,
    this.reputationScore = 5.0,
    this.totalContributions = 0,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      country: json['country'],
      reputationScore: (json['reputationScore'] ?? 5.0).toDouble(),
      totalContributions: json['totalContributions'] ?? 0,
    );
  }
}

/// Global authentication state provider.
/// Manages JWT token securely and holds current user info.
class AuthProvider extends ChangeNotifier {
  static const _tokenKey = 'velopath_jwt_token';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AppUser? _user;
  String? _token;
  bool _isLoading = false;
  String? _errorMessage;

  AppUser? get user => _user;
  String? get token => _token;
  bool get isLoggedIn => _token != null && _user != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Login with email/password
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await AuthService.login(
        email: email,
        password: password,
      );

      _token = response['token'];
      _user = AppUser.fromJson(response['user']);

      // Securely store token
      await _storage.write(key: _tokenKey, value: _token);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Register new account
  Future<bool> register(
    String username,
    String email,
    String password, {
    String? country,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await AuthService.register(
        username: username,
        email: email,
        password: password,
        country: country,
      );

      _token = response['token'];
      _user = AppUser.fromJson(response['user']);

      // Securely store token
      await _storage.write(key: _tokenKey, value: _token);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout — clear token and user
  Future<void> logout() async {
    _token = null;
    _user = null;
    _errorMessage = null;
    await _storage.delete(key: _tokenKey);
    notifyListeners();
  }

  /// Try to restore session from stored token.
  /// Call this on app startup (splash screen).
  /// Returns true if a valid session was restored.
  Future<bool> tryAutoLogin() async {
    try {
      final storedToken = await _storage.read(key: _tokenKey);
      if (storedToken == null) return false;

      // Verify token is still valid by fetching profile
      final userData = await AuthService.getProfile(storedToken);
      _token = storedToken;
      _user = AppUser.fromJson(userData);
      notifyListeners();
      return true;
    } catch (_) {
      // Token expired or invalid — clear it
      await _storage.delete(key: _tokenKey);
      return false;
    }
  }

  /// Update profile (username, country)
  Future<bool> updateProfile(String username, {String? country}) async {
    if (_token == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userData = await AuthService.updateProfile(
        token: _token!,
        username: username,
        country: country,
      );
      _user = AppUser.fromJson(userData);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Clear error (e.g., when user starts typing again)
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
