// Buys a Smart Card for a child who already exists, via the /cards
// endpoints (app/routes/cards.py).
//
// Asynchronous like a top-up: buyCard() returns a reference_id and a
// "pending" status while a prompt goes to the payer's phone. The caller
// polls checkStatus() until it resolves to "paid" or "failed". The card
// fee never goes into the child's wallet.

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import 'api_client.dart';

class CardOrderResult {
  final String referenceId;
  final String status; // always "pending" on success
  final String message;

  CardOrderResult({
    required this.referenceId,
    required this.status,
    required this.message,
  });
}

class CardService {
  /// The fixed price of a card, for display. The server sets the amount
  /// actually charged.
  static const int cardPriceUgx = 25000;

  /// Normalises a typed Ugandan number to 256XXXXXXXXX, or returns null
  /// if it is not a full number. Accepts 0771234567, 771234567,
  /// 256771234567 and +256 771 234 567.
  static String? normalizePhone(String raw) {
    String phone = raw.replaceAll(RegExp(r'\D'), '');
    if (phone.startsWith('0')) {
      phone = '256${phone.substring(1)}';
    } else if (!phone.startsWith('256')) {
      phone = '256$phone';
    }
    return phone.length == 12 ? phone : null;
  }

  /// POST /cards/orders
  /// cardColor: Blue | Green | Yellow | Red. phone must be 256XXXXXXXXX.
  /// network must be "MTN" or "AIRTEL".
  Future<CardOrderResult> buyCard({
    required int studentId,
    required String cardColor,
    required String phoneNumber,
    required String network,
  }) async {
    final headers = await ApiClient.authHeaders();
    final response = await http.post(
      Uri.parse(ApiConstants.cardOrders),
      headers: headers,
      body: jsonEncode({
        'student_id': studentId,
        'card_color': cardColor,
        'phone_number': phoneNumber,
        'network': network,
      }),
    );
    await ApiClient.ensureAuthorized(response);

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return CardOrderResult(
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
        throw Exception(first['msg'] ?? 'Could not start the payment.');
      }
      throw Exception(detail?.toString() ?? 'Could not start the payment.');
    }
  }

  /// GET /cards/orders/{referenceId}
  /// Returns "pending" | "paid" | "failed" | "fulfilled".
  Future<String> checkStatus(String referenceId) async {
    final headers = await ApiClient.authHeaders();
    final response = await http.get(
      Uri.parse(ApiConstants.cardOrderStatus(referenceId)),
      headers: headers,
    );
    await ApiClient.ensureAuthorized(response);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['status'] as String;
    } else {
      throw Exception('Could not check the card payment.');
    }
  }
}
