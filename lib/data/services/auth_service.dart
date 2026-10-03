// Handles login, registration, session check, logout, and PIN change.
// Talks to the confirmed /auth/* endpoints on the backend.

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import 'api_client.dart';
import '../models/auth_user.dart';
import '../models/terms.dart';

class AuthResult {
  final bool success;
  final String? errorMessage;
  final String? token;
  final AuthUser? user;

  /// Set when the PIN was right but the backend will not issue a token
  /// until this version of the terms is accepted.
  final String? termsRequiredVersion;

  AuthResult({
    required this.success,
    this.errorMessage,
    this.token,
    this.user,
    this.termsRequiredVersion,
  });
}

class AuthService {
  /// GET /auth/terms — the text the parent is asked to accept, with the
  /// version that acceptance will be recorded against.
  Future<Terms> fetchTerms() async {
    final response = await http
        .get(Uri.parse(ApiConstants.terms), headers: ApiClient.baseHeaders())
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Could not load the terms. Please try again.');
    }
    return Terms.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Body for POST /auth/login. [acceptTermsVersion] is sent only when
  /// the parent has just accepted that version on the terms screen.
  static Map<String, dynamic> loginBody(
    String phone,
    String pin, {
    String? acceptTermsVersion,
  }) =>
      {
        'phone': phone,
        'pin': pin,
        'accept_terms_version': ?acceptTermsVersion,
      };

  /// Body for POST /auth/register. The backend creates no account
  /// unless [termsVersion] is the current version.
  static Map<String, dynamic> registerBody({
    required String name,
    required String phone,
    required String pin,
    required String termsVersion,
    String role = 'parent',
  }) =>
      {
        'name': name,
        'phone': phone,
        'pin': pin,
        'role': role,
        'terms_version': termsVersion,
      };

  /// The terms version the backend is asking the parent to accept, or
  /// null if this login response is anything else (wrong PIN, lockout,
  /// success).
  static String? termsRequiredVersion(int statusCode, dynamic data) {
    if (statusCode != 403 || data is! Map) return null;
    if (data['code'] != 'terms_required') return null;
    final version = data['terms_version'];
    return version is String ? version : null;
  }

  Future<AuthResult> login(
    String phone,
    String pin, {
    String? acceptTermsVersion,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConstants.login),
            headers: ApiClient.baseHeaders(),
            body: jsonEncode(loginBody(phone, pin,
                acceptTermsVersion: acceptTermsVersion)),
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
          termsRequiredVersion:
              termsRequiredVersion(response.statusCode, data),
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
    required String termsVersion,
    String role = 'parent',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConstants.register),
            headers: ApiClient.baseHeaders(),
            body: jsonEncode(registerBody(
              name: name,
              phone: phone,
              pin: pin,
              termsVersion: termsVersion,
              role: role,
            )),
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
    if (ApiClient.isTokenExpired(token)) {
      await ApiClient.clearSession();
      return null;
    }
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

  /// POST /auth/unlock — the lock screen's PIN check. Returns null when
  /// the PIN is right, or the message to show. A wrong PIN is 400 (not
  /// 401), so only a session that has really ended signs the parent out.
  Future<String?> unlock(String pin) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConstants.unlock),
            headers: await ApiClient.authHeaders(),
            body: jsonEncode({'pin': pin}),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) return null;
      if (response.statusCode == 401) {
        await ApiClient.ensureAuthorized(response);
      }
      final detail = jsonDecode(response.body)['detail'];
      return detail?.toString() ?? 'Could not check your PIN.';
    } on SessionExpiredException {
      return 'Your session has ended. Please log in again.';
    } catch (_) {
      return 'Could not reach the server to check your PIN. '
          'Check your connection and try again.';
    }
  }

  Future<void> logout() async {
    await ApiClient.clearSession();
  }
}