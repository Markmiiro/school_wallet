// Shared HTTP client logic used by every service (auth, wallet, etc.).
// Centralizes token retrieval and header construction so each service
// file doesn't repeat the same boilerplate.

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Thrown when the backend rejects the stored token (HTTP 401).
class SessionExpiredException implements Exception {
  @override
  String toString() => 'Your session has expired. Please log in again.';
}

class ApiClient {
  static const _storage = FlutterSecureStorage();
  static const String tokenKey = 'jwt_token';
  static const String userJsonKey = 'user_json';

  /// Set by AuthProvider. Called once the stored session has been
  /// cleared after a 401, so the app can return to the login screen.
  static void Function()? onSessionExpired;

  /// Call on every authenticated response. Tokens last 24 hours and
  /// there is no refresh, so a 401 means "log in again": clear the
  /// stored session, tell the app, and stop the caller.
  static Future<void> ensureAuthorized(http.Response response) async {
    if (response.statusCode != 401) return;
    await clearSession();
    onSessionExpired?.call();
    throw SessionExpiredException();
  }

  /// True if [token] is a JWT whose `exp` is in the past, or is not a
  /// readable JWT at all. This only reads the payload; the signature
  /// is checked by the server, not here.
  static bool isTokenExpired(String token, {DateTime? now}) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is! num) return true;
      final expiry =
          DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
      return !(now ?? DateTime.now().toUtc()).isBefore(expiry);
    } catch (_) {
      return true;
    }
  }

  /// Reads the stored JWT token, or null if not logged in.
  static Future<String?> getToken() async {
    return _storage.read(key: tokenKey);
  }

  /// Standard headers for an authenticated request.
  /// If no token exists yet (e.g. login/register calls), the
  /// Authorization header is simply omitted.
  static Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Headers for unauthenticated requests (login, register).
  static Map<String, String> baseHeaders() {
    return {'Content-Type': 'application/json'};
  }

  static Future<void> saveSession({
    required String token,
    required String userJson,
  }) async {
    await _storage.write(key: tokenKey, value: token);
    await _storage.write(key: userJsonKey, value: userJson);
  }

  static Future<String?> getStoredUserJson() async {
    return _storage.read(key: userJsonKey);
  }

  static Future<void> clearSession() async {
    await _storage.delete(key: tokenKey);
    await _storage.delete(key: userJsonKey);
  }
}