// Gets a parent their children from the school's roster, via /family
// (app/routes/family.py). The roster names each child's guardian phone;
// the parent proves once, by SMS code, that they hold that number.

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import 'api_client.dart';

class FamilyClaimable {
  final int count;
  final bool verified;

  FamilyClaimable({required this.count, required this.verified});

  factory FamilyClaimable.fromJson(Map<String, dynamic> json) => FamilyClaimable(
        count: (json['count'] as num).toInt(),
        verified: json['verified'] as bool,
      );
}

class FamilyService {
  static Map<String, String> claimBody(String? code) =>
      code == null ? <String, String>{} : {'code': code};

  /// How many roster children wait on this parent's number. No names
  /// until the number is proved.
  Future<FamilyClaimable> claimable() async {
    final response = await http
        .get(Uri.parse(ApiConstants.familyClaimable),
            headers: await ApiClient.authHeaders())
        .timeout(const Duration(seconds: 15));
    await ApiClient.ensureAuthorized(response);
    if (response.statusCode != 200) {
      throw Exception(_detail(response.body, 'Could not check for children.'));
    }
    return FamilyClaimable.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> sendCode() async {
    final response = await http
        .post(Uri.parse(ApiConstants.familySendCode),
            headers: await ApiClient.authHeaders())
        .timeout(const Duration(seconds: 20));
    await ApiClient.ensureAuthorized(response);
    if (response.statusCode != 200) {
      throw Exception(_detail(response.body, 'Could not send the code.'));
    }
  }

  /// Attaches the waiting children. Returns their names.
  Future<List<String>> claim(String? code) async {
    final response = await http
        .post(Uri.parse(ApiConstants.familyClaim),
            headers: await ApiClient.authHeaders(),
            body: jsonEncode(claimBody(code)))
        .timeout(const Duration(seconds: 20));
    await ApiClient.ensureAuthorized(response);
    if (response.statusCode != 200) {
      throw Exception(_detail(response.body, 'Could not add your children.'));
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['added'] as List).cast<String>();
  }

  static String _detail(String body, String fallback) {
    try {
      final detail = (jsonDecode(body) as Map)['detail'];
      if (detail is List && detail.isNotEmpty) return detail.first['msg'].toString();
      return detail?.toString() ?? fallback;
    } catch (_) {
      return fallback;
    }
  }
}
