// Handles wallet top-ups via the /topup endpoints (Yo Uganda / MTN /
// Airtel). Confirmed from app/routes/topup.py on 21 July 2026.
//
// The flow is asynchronous: initiateTopUp() returns a reference_id and
// a "pending" status (a USSD prompt is sent to the parent's phone).
// The wallet is only credited once the parent approves with their MoMo
// PIN — so the caller must poll checkStatus() until it resolves to
// "completed" or "failed".

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import 'api_client.dart';

class TopUpInitResult {
  final String referenceId;
  final String status; // always "pending" on success
  final String message;

  TopUpInitResult({
    required this.referenceId,
    required this.status,
    required this.message,
  });
}

class TopUpService {
  /// POST /topup/
  /// amount: 500–5,000,000 UGX. phone must be 256XXXXXXXXX (12 digits).
  /// network must be "MTN" or "AIRTEL".
  Future<TopUpInitResult> initiateTopUp({
    required int walletId,
    required int amount,
    required String phoneNumber,
    required String network,
    String? note,
  }) async {
    final headers = await ApiClient.authHeaders();
    final response = await http.post(
      Uri.parse(ApiConstants.topup),
      headers: headers,
      body: jsonEncode({
        'wallet_id': walletId,
        'amount': amount,
        'phone_number': phoneNumber,
        'network': network,
        if (note != null && note.isNotEmpty) 'note': note,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return TopUpInitResult(
        referenceId: data['reference_id'] as String,
        status: data['status'] as String,
        message: data['message'] as String,
      );
    } else {
      // FastAPI validation errors come back as a list under 'detail';
      // simple errors come back as a string. Handle both.
      final detail = data['detail'];
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        throw Exception(first['msg'] ?? 'Top-up failed.');
      }
      throw Exception(detail?.toString() ?? 'Top-up failed.');
    }
  }

  /// GET /topup/{referenceId}
  /// Returns the current status: "pending" | "completed" | "failed".
  Future<String> checkStatus(String referenceId) async {
    final headers = await ApiClient.authHeaders();
    final response = await http.get(
      Uri.parse(ApiConstants.topupStatus(referenceId)),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['status'] as String;
    } else {
      throw Exception('Could not check top-up status.');
    }
  }
}