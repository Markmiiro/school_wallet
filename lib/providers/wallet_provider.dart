// ChangeNotifier holding the parent's students and their wallet
// balances. Used by the Dashboard and Child Wallet Detail screens.

import 'package:flutter/material.dart';
import '../data/services/wallet_service.dart';
import '../data/models/student.dart';
import '../data/models/wallet_balance.dart';

class WalletProvider extends ChangeNotifier {
  final WalletService _walletService = WalletService();

  bool isLoading = false;
  String? errorMessage;

  List<Student> students = [];
  Map<int, WalletBalance> balances = {};

  /// Loads all of a parent's children, then loads each child's wallet
  /// balance. A single wallet failing doesn't fail the whole screen —
  /// that student just won't have a balance entry.
  Future<void> loadForParent(int parentId) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final loadedStudents =
          await _walletService.getStudentsForParent(parentId);
      final loadedBalances = <int, WalletBalance>{};

      for (final student in loadedStudents) {
        try {
          loadedBalances[student.id] =
              await _walletService.getWalletBalance(student.id);
        } catch (_) {
          // Skip this student's balance rather than failing the
          // whole screen — other children may still load fine.
        }
      }

      students = loadedStudents;
      balances = loadedBalances;
      isLoading = false;
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      isLoading = false;
      notifyListeners();
    }
  }

  WalletBalance? balanceFor(int studentId) => balances[studentId];

  Future<bool> createStudent({
    required String name,
    required int schoolId,
    required int parentId,
  }) async {
    try {
      await _walletService.createStudent(
        name: name,
        schoolId: schoolId,
        parentId: parentId,
      );
      // Reload the full list so the new student (with its
      // auto-created wallet) shows up immediately.
      await loadForParent(parentId);
      return true;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}