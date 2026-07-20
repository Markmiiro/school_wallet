// Fetches a parent's students and each student's wallet balance.
// Talks to the confirmed /students/* and /wallets/* endpoints.

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import 'api_client.dart';
import '../models/student.dart';
import '../models/wallet_balance.dart';

class WalletService {
  /// GET /students/parent/{parentId}
  /// Returns the list of children belonging to a parent.
  Future<List<Student>> getStudentsForParent(int parentId) async {
    final headers = await ApiClient.authHeaders();
    final response = await http.get(
      Uri.parse(ApiConstants.studentsForParent(parentId)),
      headers: headers,
    );

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

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return WalletBalance.fromJson(studentId, data);
    } else if (response.statusCode == 404) {
      throw Exception('Wallet not found for this student.');
    } else {
      throw Exception('Failed to load wallet (${response.statusCode})');
    }
  }
}
