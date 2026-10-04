// ChangeNotifier holding the parent's students, their wallet balances,
// and a merged family-transactions feed. Used by the Dashboard, Child
// Wallet Detail, and Transactions screens.

import 'package:flutter/material.dart';
import '../core/load_error.dart';
import '../data/services/api_client.dart';
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
  final WalletService _walletService;

  WalletProvider({WalletService? service})
      : _walletService = service ?? WalletService();

  bool isLoading = false;
  String? errorMessage;

  /// True once this parent's children have loaded at least once. Until
  /// then an empty [students] means "not known yet", not "no children":
  /// screens show a loading or an error state, never an empty one.
  bool hasLoaded = false;

  List<Student> students = [];
  Map<int, WalletBalance> balances = {};

  // Whose data is currently held. If a different parent logs in on the
  // same device, everything below is dropped before anything is shown.
  int? _parentId;
  Future<void>? _loading;
  Future<void>? _historyLoading;

  // Merged family-transactions feed state.
  bool isHistoryLoading = false;
  String? historyError;

  /// Children whose history could not be read on the last load.
  List<String> historyFailedFor = [];
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

  /// Whether money has ever gone into any child's wallet. Null while it
  /// is not known: a balance of zero may be money already spent, so the
  /// answer then needs every child's history.
  bool? get hasToppedUp {
    if (balances.values.any((b) => b.balance > 0)) return true;
    if (students.any((s) => (_inByStudent[s.id] ?? 0) > 0)) return true;
    if (students.every((s) => _inByStudent.containsKey(s.id))) return false;
    return null;
  }

  /// Loads all of a parent's children, then loads each child's wallet
  /// balance. A single wallet failing doesn't fail the whole screen —
  /// that student just won't have a balance entry.
  ///
  /// Home and Transactions both ask at startup; a second call for the
  /// same parent while one is running waits for that one.
  Future<void> loadForParent(int parentId) {
    final running = _loading;
    if (running != null && _parentId == parentId) return running;
    final load = _loadForParent(parentId);
    _loading = load;
    return load.whenComplete(() {
      if (identical(_loading, load)) _loading = null;
    });
  }

  Future<void> _loadForParent(int parentId) async {
    if (_parentId != parentId) {
      _parentId = parentId;
      hasLoaded = false;
      students = [];
      balances = {};
      familyTransactions = [];
      historyFailedFor = [];
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

      if (_parentId != parentId) return; // another parent signed in meanwhile
      students = loadedStudents;
      balances = loadedBalances;
      hasLoaded = true;
      isLoading = false;
      notifyListeners();
    } on SessionExpiredException {
      // The router is already on its way back to the login screen.
      isLoading = false;
      notifyListeners();
    } catch (e) {
      errorMessage = loadErrorText(e);
      isLoading = false;
      notifyListeners();
    }
  }

  WalletBalance? balanceFor(int studentId) => balances[studentId];

  /// Loads every child's wallet history and merges them into one
  /// newest-first family feed. Individual failures are skipped so one
  /// child's error doesn't break the whole feed. Loads in parallel.
  ///
  /// Home and Transactions both ask; a call made while one is running
  /// waits for that one.
  Future<void> loadFamilyTransactions() {
    final running = _historyLoading;
    if (running != null) return running;
    final load = _loadFamilyTransactions();
    _historyLoading = load;
    return load.whenComplete(() {
      if (identical(_historyLoading, load)) _historyLoading = null;
    });
  }

  Future<void> _loadFamilyTransactions() async {
    if (students.isEmpty) {
      familyTransactions = [];
      historyFailedFor = [];
      historyError = null;
      totalIn = 0;
      totalOut = 0;
      _inByStudent = {};
      _outByStudent = {};
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
          } on SessionExpiredException {
            rethrow;
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
      final failed = <String>[];

      for (final entry in results) {
        final student = entry.key;
        final history = entry.value;
        if (history == null) {
          failed.add(student.name);
          continue;
        }
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
      historyFailedFor = failed;
      // Nothing came back for anyone: that is a failure, not "no
      // transactions yet".
      if (failed.length == results.length) {
        historyError = 'Could not load the transactions. Check your '
            'connection and try again.';
      }
      isHistoryLoading = false;
      notifyListeners();
    } on SessionExpiredException {
      isHistoryLoading = false;
      notifyListeners();
    } catch (e) {
      historyError = loadErrorText(e);
      isHistoryLoading = false;
      notifyListeners();
    }
  }
}