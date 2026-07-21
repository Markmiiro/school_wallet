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

  /// POST /students/
  /// Registers a new child under the given parent. parentId should
  /// always come from the logged-in user's own session (AuthProvider),
  /// never typed in by hand — the backend does not yet verify this
  /// server-side, so the app must be careful not to let this be spoofed.
  ///
  /// NOTE: the backend's create_student route declares name/school_id/
  /// parent_id as plain function parameters (no Pydantic body model),
  /// which FastAPI binds as QUERY parameters, not JSON body fields.
  /// Confirmed live on 21 July 2026 — sending these as a JSON body
  /// produces a 422 "Field required" error for all three fields.
  Future<Student> createStudent({
    required String name,
    required int schoolId,
    required int parentId,
  }) async {
    final headers = await ApiClient.authHeaders();
    final uri = Uri.parse(ApiConstants.createStudent).replace(
      queryParameters: {
        'name': name,
        'school_id': schoolId.toString(),
        'parent_id': parentId.toString(),
      },
    );
    final response = await http.post(
      uri,
      headers: headers,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final studentJson = data['student'] as Map<String, dynamic>;
      return Student.fromJson(studentJson);
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['detail'] ?? 'Failed to register student.');
    }
  }
}