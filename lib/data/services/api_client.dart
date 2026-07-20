// Shared HTTP client logic used by every service (auth, wallet, etc.).
// Centralizes token retrieval and header construction so each service
// file doesn't repeat the same boilerplate.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  static const _storage = FlutterSecureStorage();
  static const String tokenKey = 'jwt_token';
  static const String userJsonKey = 'user_json';

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