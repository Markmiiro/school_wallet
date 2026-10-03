// ChangeNotifier holding the parent's students, their wallet balances,
// and a merged family-transactions feed. Used by the Dashboard, Child
// Wallet Detail, and Transactions screens.

import 'package:flutter/material.dart';
import '../data/services/wallet_service.dart';
import '../data/models/student.dart';
import '../data/models/wallet_balance.dart';
import '../data/models/wallet_history.dart';

/// A single transaction paired with the child it belongs to, for the
/// merged family transactions feed.
class FamilyTransaction {
  final String studentName;
  final int studentId;
  final Transaction tx;

  FamilyTransaction({
    required this.studentName,
    required this.studentId,
    required this.tx,
  });
}

class WalletProvider extends ChangeNotifier {
  final WalletService _walletService = WalletService();

  bool isLoading = false;
  String? errorMessage;

  List<Student> students = [];
  Map<int, WalletBalance> balances = {};

  // Whose data is currently held. If a different parent logs in on the
  // same device, everything below is dropped before anything is shown.
  int? _parentId;

  // Merged family-transactions feed state.
  bool isHistoryLoading = false;
  String? historyError;
  List<FamilyTransaction> familyTransactions = [];
  double totalIn = 0;
  double totalOut = 0;

  // The same totals per child, for the per-child filter.
  Map<int, double> _inByStudent = {};
  Map<int, double> _outByStudent = {};

  /// Topped up, for the family or for one child.
  double totalInFor(int? studentId) =>
      studentId == null ? totalIn : (_inByStudent[studentId] ?? 0);

  /// Spent, for the family or for one child.
  double totalOutFor(int? studentId) =>
      studentId == null ? totalOut : (_outByStudent[studentId] ?? 0);

  /// Loads all of a parent's children, then loads each child's wallet
  /// balance. A single wallet failing doesn't fail the whole screen —
  /// that student just won't have a balance entry.
  Future<void> loadForParent(int parentId) async {
    if (_parentId != parentId) {
      _parentId = parentId;
      students = [];
      balances = {};
      familyTransactions = [];
      totalIn = 0;
      totalOut = 0;
      _inByStudent = {};
      _outByStudent = {};
    }
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

  /// Loads every child's wallet history and merges them into one
  /// newest-first family feed. Individual failures are skipped so one
  /// child's error doesn't break the whole feed. Loads in parallel.
  Future<void> loadFamilyTransactions() async {
    if (students.isEmpty) {
      familyTransactions = [];
      totalIn = 0;
      totalOut = 0;
      notifyListeners();
      return;
    }

    isHistoryLoading = true;
    historyError = null;
    notifyListeners();

    try {
      final results = await Future.wait(
        students.map((s) async {
          try {
            final history = await _walletService.getWalletHistory(s.id);
            return MapEntry(s, history);
          } catch (_) {
            return MapEntry<Student, WalletHistory?>(s, null);
          }
        }),
      );

      final merged = <FamilyTransaction>[];
      double tIn = 0;
      double tOut = 0;
      final inBy = <int, double>{};
      final outBy = <int, double>{};

      for (final entry in results) {
        final student = entry.key;
        final history = entry.value;
        if (history == null) continue;
        tIn += history.totalToppedUp;
        tOut += history.totalSpent;
        inBy[student.id] = history.totalToppedUp;
        outBy[student.id] = history.totalSpent;
        for (final tx in history.transactions) {
          merged.add(FamilyTransaction(
            studentName: student.name,
            studentId: student.id,
            tx: tx,
          ));
        }
      }

      merged.sort((a, b) => b.tx.date.compareTo(a.tx.date));

      familyTransactions = merged;
      totalIn = tIn;
      totalOut = tOut;
      _inByStudent = inBy;
      _outByStudent = outBy;
      isHistoryLoading = false;
      notifyListeners();
    } catch (e) {
      historyError = e.toString();
      isHistoryLoading = false;
      notifyListeners();
    }
  }
}