// The stored JWT is checked for expiry before the app trusts a saved
// session. Only the payload is read here; the server checks the
// signature.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_wallet/data/services/api_client.dart';

String _jwt(Map<String, dynamic> payload) {
  String part(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part(payload)}.signature';
}

void main() {
  final now = DateTime.utc(2026, 10, 1, 12);
  int secs(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

  test('a token with a future exp is live', () {
    final token =
        _jwt({'sub': '256700111222', 'exp': secs(now.add(const Duration(hours: 1)))});
    expect(ApiClient.isTokenExpired(token, now: now), isFalse);
  });

  test('a token past its exp is expired', () {
    final token = _jwt(
        {'sub': '256700111222', 'exp': secs(now.subtract(const Duration(seconds: 1)))});
    expect(ApiClient.isTokenExpired(token, now: now), isTrue);
  });

  test('a token expiring exactly now is expired', () {
    final token = _jwt({'sub': '256700111222', 'exp': secs(now)});
    expect(ApiClient.isTokenExpired(token, now: now), isTrue);
  });

  test('a token with no exp is treated as expired', () {
    expect(ApiClient.isTokenExpired(_jwt({'sub': 'x'}), now: now), isTrue);
  });

  test('garbage is treated as expired', () {
    expect(ApiClient.isTokenExpired('not-a-jwt', now: now), isTrue);
    expect(ApiClient.isTokenExpired('a.b.c', now: now), isTrue);
    expect(ApiClient.isTokenExpired('', now: now), isTrue);
  });
}
