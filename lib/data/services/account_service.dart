// Deleting the parent's account, via /account (app/routes/account.py).
//
// The request starts a 72-hour hold on the server: cards stop and every
// session ends at once, so the caller logs out locally on success.

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../models/account_closure.dart';
import 'api_client.dart';

class ClosureResult {
  final bool success;
  final String message;

  ClosureResult({required this.success, required this.message});
}

class AccountService {
  static Map<String, String> closureBody({
    required String pin,
    required String confirm,
  }) =>
      {'pin': pin, 'confirm': confirm};

  Future<ClosurePreview> fetchPreview() async {
    final response = await http
        .get(Uri.parse(ApiConstants.closurePreview),
            headers: await ApiClient.authHeaders())
        .timeout(const Duration(seconds: 15));
    await ApiClient.ensureAuthorized(response);
    if (response.statusCode != 200) {
      throw Exception(_detail(response.body) ?? 'Could not load your account.');
    }
    return ClosurePreview.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<ClosureResult> requestClosure({
    required String pin,
    required String confirm,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConstants.closure),
            headers: await ApiClient.authHeaders(),
            body: jsonEncode(closureBody(pin: pin, confirm: confirm)),
          )
          .timeout(const Duration(seconds: 20));
      final detail = _detail(response.body);
      if (response.statusCode == 202) {
        return ClosureResult(success: true, message: detail ?? 'Your account is closing.');
      }
      return ClosureResult(
          success: false, message: detail ?? 'Could not delete your account.');
    } catch (e) {
      return ClosureResult(
        success: false,
        message: 'Could not reach the server. Check your connection.',
      );
    }
  }

  // The 202 answer carries "message"; errors carry "detail", a string or
  // a list of validation errors.
  static String? _detail(String body) {
    try {
      final data = jsonDecode(body);
      if (data is! Map) return null;
      final value = data['message'] ?? data['detail'];
      if (value is List && value.isNotEmpty) return value.first['msg']?.toString();
      return value?.toString();
    } catch (_) {
      return null;
    }
  }
}
