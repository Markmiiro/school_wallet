// Handles login, registration, session check, logout, and PIN change.
// Talks to the confirmed /auth/* endpoints on the backend.

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import 'api_client.dart';
import '../models/auth_user.dart';

class AuthResult {
  final bool success;
  final String? errorMessage;
  final String? token;
  final AuthUser? user;

  AuthResult({
    required this.success,
    this.errorMessage,
    this.token,
    this.user,
  });
}

class AuthService {
  Future<AuthResult> login(String phone, String pin) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConstants.login),
            headers: ApiClient.baseHeaders(),
            body: jsonEncode({'phone': phone, 'pin': pin}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final token = data['token'] as String;
        final user = AuthUser.fromJson(data['user']);

        await ApiClient.saveSession(
          token: token,
          userJson: jsonEncode(user.toJson()),
        );

        return AuthResult(success: true, token: token, user: user);
      } else {
        return AuthResult(
          success: false,
          errorMessage: data['detail'] ?? 'Login failed. Please try again.',
        );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        errorMessage: 'Could not reach the server. Check your connection.',
      );
    }
  }

  /// Registers a new user. role defaults to 'parent' since that's the
  /// only self-serve role in the app.
  Future<AuthResult> register({
    required String name,
    required String phone,
    required String pin,
    String role = 'parent',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConstants.register),
            headers: ApiClient.baseHeaders(),
            body: jsonEncode({
              'name': name,
              'phone': phone,
              'pin': pin,
              'role': role,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Registration succeeded. The endpoint may or may not return a
        // token directly — if not, the caller should log in immediately
        // after with the same credentials.
        if (data['token'] != null && data['user'] != null) {
          final token = data['token'] as String;
          final user = AuthUser.fromJson(data['user']);
          await ApiClient.saveSession(
            token: token,
            userJson: jsonEncode(user.toJson()),
          );
          return AuthResult(success: true, token: token, user: user);
        }
        return AuthResult(success: true);
      } else {
        return AuthResult(
          success: false,
          errorMessage:
              data['detail'] ?? 'Registration failed. Please try again.',
        );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        errorMessage: 'Could not reach the server. Check your connection.',
      );
    }
  }

  Future<AuthUser?> checkExistingSession() async {
    final token = await ApiClient.getToken();
    final userJson = await ApiClient.getStoredUserJson();
    if (token == null || userJson == null) return null;
    return AuthUser.fromJson(jsonDecode(userJson));
  }

  /// POST /auth/change-pin
  /// Requires the current PIN for verification. Returns success on 200.
  /// NOTE: the backend invalidates the session on success ("Please
  /// login again with your new PIN"), so the caller should log the
  /// user out afterward.
  Future<AuthResult> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    try {
      final headers = await ApiClient.authHeaders();
      final response = await http
          .post(
            Uri.parse(ApiConstants.changePin),
            headers: headers,
            body: jsonEncode({
              'current_pin': currentPin,
              'new_pin': newPin,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return AuthResult(success: true);
      } else {
        // Validation errors come as a list under 'detail'; simple
        // errors come as a string.
        final detail = data['detail'];
        if (detail is List && detail.isNotEmpty) {
          return AuthResult(
            success: false,
            errorMessage: detail.first['msg'] ?? 'Could not change PIN.',
          );
        }
        return AuthResult(
          success: false,
          errorMessage: detail?.toString() ?? 'Could not change PIN.',
        );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        errorMessage: 'Could not reach the server. Check your connection.',
      );
    }
  }

  Future<void> logout() async {
    await ApiClient.clearSession();
  }
}