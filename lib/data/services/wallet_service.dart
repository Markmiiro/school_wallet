// Fetches a parent's students, wallet balances, and wallet history,
// links cards by number, sets daily limits and blocks lost cards. Talks to the confirmed /students/* and
// /wallets/* endpoints.

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import 'api_client.dart';
import '../models/student.dart';
import '../models/wallet_balance.dart';
import '../models/wallet_history.dart';

class WalletService {
  /// GET /students/parent/{parentId}
  /// Returns the list of children belonging to a parent.
  Future<List<Student>> getStudentsForParent(int parentId) async {
    final headers = await ApiClient.authHeaders();
    final response = await http.get(
      Uri.parse(ApiConstants.studentsForParent(parentId)),
      headers: headers,
    );
    await ApiClient.ensureAuthorized(response);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final students = data['students'] as List<dynamic>;
      return students
          .map((s) => Student.fromJson(s as Map<String, dynamic>))
          .toList();
    } else if (response.statusCode == 404) {
      throw Exception('Parent not found.');
    } else {
      throw Exception('Failed to load students (${response.statusCode})');
    }
  }

  /// GET /wallets/wallets/{studentId}
  /// NOTE: the double "/wallets/wallets/" is intentional — see
  /// ApiConstants.walletBalance for the full explanation.
  Future<WalletBalance> getWalletBalance(int studentId) async {
    final headers = await ApiClient.authHeaders();
    final response = await http.get(
      Uri.parse(ApiConstants.walletBalance(studentId)),
      headers: headers,
    );
    await ApiClient.ensureAuthorized(response);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return WalletBalance.fromJson(studentId, data);
    } else if (response.statusCode == 404) {
      throw Exception('Wallet not found for this student.');
    } else {
      throw Exception('Failed to load wallet (${response.statusCode})');
    }
  }

  /// GET /wallets/{studentId}/history
  /// NOT double-prefixed — confirmed correct as written (unlike the
  /// balance endpoint above).
  Future<WalletHistory> getWalletHistory(int studentId, {int limit = 20}) async {
    final headers = await ApiClient.authHeaders();
    final response = await http.get(
      Uri.parse(ApiConstants.walletHistory(studentId, limit: limit)),
      headers: headers,
    );
    await ApiClient.ensureAuthorized(response);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return WalletHistory.fromJson(data);
    } else if (response.statusCode == 404) {
      throw Exception('No wallet found for this student.');
    } else {
      throw Exception('Failed to load wallet history (${response.statusCode})');
    }
  }

  /// PUT /students/{studentId}/assign-nfc?tag_uid={card number}
  /// Links a card to a child who already exists, by the card's number
  /// (its UID in hex). A parent may do this only for their own child and
  /// only when the child has no working card; the backend rejects a
  /// number that is already linked or retired.
  ///
  /// NOTE: the backend declares tag_uid as a plain function parameter,
  /// so FastAPI binds it as a QUERY parameter, not a JSON body.
  Future<void> assignNfc({
    required int studentId,
    required String tagUid,
  }) async {
    final headers = await ApiClient.authHeaders();
    final uri = Uri.parse(ApiConstants.assignNfc(studentId)).replace(
      queryParameters: {'tag_uid': tagUid},
    );
    final response = await http.put(uri, headers: headers);
    await ApiClient.ensureAuthorized(response);

    if (response.statusCode == 200) {
      return;
    } else {
      final data = jsonDecode(response.body);
      throw Exception(_detail(data, 'Could not link the card.'));
    }
  }

  /// PUT /wallets/{studentId}/limit?daily_limit=N
  /// Sets how much the child may spend per day (UGX 500–5,000,000).
  /// Returns the limit the backend stored.
  Future<int> setDailyLimit({
    required int studentId,
    required int dailyLimit,
  }) async {
    final headers = await ApiClient.authHeaders();
    final uri = Uri.parse(ApiConstants.walletLimit(studentId)).replace(
      queryParameters: {'daily_limit': dailyLimit.toString()},
    );
    final response = await http.put(uri, headers: headers);
    await ApiClient.ensureAuthorized(response);

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return (data['daily_limit'] as num).toInt();
    }
    throw Exception(_detail(data, 'Could not update the daily limit.'));
  }

  /// POST /students/{studentId}/report-stolen?reason=lost|stolen
  /// Blocks the child's current card straight away. The wallet and its
  /// balance are untouched; the school issues a replacement card.
  Future<void> reportCard({
    required int studentId,
    required String reason,
  }) async {
    final headers = await ApiClient.authHeaders();
    final uri = Uri.parse(ApiConstants.reportCard(studentId)).replace(
      queryParameters: {'reason': reason},
    );
    final response = await http.post(uri, headers: headers);
    await ApiClient.ensureAuthorized(response);

    if (response.statusCode == 200) return;
    throw Exception(
      _detail(jsonDecode(response.body), 'Could not block the card.'),
    );
  }

  /// FastAPI sends validation errors as a list under 'detail' and
  /// simple errors as a string.
  String _detail(dynamic data, String fallback) {
    final detail = data is Map ? data['detail'] : null;
    if (detail is List && detail.isNotEmpty) {
      return detail.first['msg']?.toString() ?? fallback;
    }
    return detail?.toString() ?? fallback;
  }
}