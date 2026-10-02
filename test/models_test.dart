// Parsing tests for the models the parent app builds from backend
// responses. Payloads mirror what app/routes/students.py and
// app/routes/wallets.py actually return.

import 'package:flutter_test/flutter_test.dart';
import 'package:school_wallet/data/models/student.dart';
import 'package:school_wallet/data/models/wallet_balance.dart';
import 'package:school_wallet/data/models/wallet_history.dart';

Map<String, dynamic> _tx({
  required String type,
  required String status,
  String direction = 'IN',
}) =>
    {
      'id': 1,
      'type': type,
      'direction': direction,
      'amount': 5000,
      'status': status,
      'reference': 'ref-1',
      'description': null,
      'date': '2026-10-01T09:30:00',
    };

void main() {
  group('Student', () {
    test('reads school, account number and card status', () {
      final s = Student.fromJson({
        'id': 7,
        'name': 'Amara Namukasa',
        'school_id': 3,
        'school_name': 'Seeta Primary',
        'parent_id': 12,
        'account_number': '003482917604',
        'nfc': {'tag_uid': '04A21B', 'status': 'assigned'},
      });

      expect(s.schoolName, 'Seeta Primary');
      expect(s.accountNumber, '003482917604');
      expect(s.cardStatus, 'assigned');
      expect(s.cardUid, '04A21B');
      expect(s.hasActiveCard, isTrue);
    });

    test('a reported card is not active', () {
      final s = Student.fromJson({
        'id': 7,
        'name': 'Amara',
        'school_id': 3,
        'nfc': {'tag_uid': null, 'status': 'stolen'},
      });
      expect(s.hasActiveCard, isFalse);
    });

    test('still parses the minimal create-student response', () {
      final s = Student.fromJson({'id': 7, 'name': 'Amara', 'school_id': 3});
      expect(s.accountNumber, isNull);
      expect(s.cardStatus, isNull);
      expect(s.hasActiveCard, isFalse);
    });
  });

  group('WalletBalance', () {
    test('reads the daily limit', () {
      final b = WalletBalance.fromJson(7, {
        'student': 'Amara',
        'wallet_id': 9,
        'balance': 12000,
        'is_active': true,
        'daily_limit': 20000,
      });
      expect(b.balance, 12000);
      expect(b.dailyLimit, 20000);
    });

    test('tolerates a response without a daily limit', () {
      final b = WalletBalance.fromJson(
          7, {'wallet_id': 9, 'balance': 0, 'is_active': false});
      expect(b.dailyLimit, isNull);
      expect(b.isActive, isFalse);
    });
  });

  group('WalletHistory', () {
    Map<String, dynamic> history(List<Map<String, dynamic>> txs) => {
          'student_id': 7,
          'wallet_id': 9,
          'current_balance': 12000,
          'is_active': true,
          'daily_limit': 15000,
          'currency': 'UGX',
          'summary': {
            'total_topped_up': 20000,
            'total_spent': 8000,
            'number_of_transactions': txs.length,
          },
          'transactions': txs,
        };

    test('reads limit, active flag and totals', () {
      final h = WalletHistory.fromJson(history([]));
      expect(h.dailyLimit, 15000);
      expect(h.isActive, isTrue);
      expect(h.totalToppedUp, 20000);
      expect(h.totalSpent, 8000);
    });

    test('a failed top-up is money-in by type but not completed', () {
      final h = WalletHistory.fromJson(
          history([_tx(type: 'topup', status: 'failed')]));
      final tx = h.transactions.single;
      expect(tx.isIn, isTrue);
      expect(tx.isFailed, isTrue);
      expect(tx.isCompleted, isFalse);
    });

    test('a pending top-up is flagged pending', () {
      final tx = Transaction.fromJson(_tx(type: 'topup', status: 'pending'));
      expect(tx.isPending, isTrue);
      expect(tx.isCompleted, isFalse);
    });

    test('payments and registration fees are money out', () {
      expect(
        Transaction.fromJson(
            _tx(type: 'payment', status: 'completed', direction: 'OUT')).isIn,
        isFalse,
      );
      expect(
        Transaction.fromJson(_tx(
            type: 'registration', status: 'completed', direction: 'OUT')).isIn,
        isFalse,
      );
    });

    test('an unmarked backend time is read as UTC, not device time', () {
      final t = parseBackendTime('2026-10-01T09:30:00');
      expect(t.isUtc, isFalse);
      expect(t.toUtc(), DateTime.utc(2026, 10, 1, 9, 30));
      // A time that already carries a zone is left meaning what it says.
      expect(parseBackendTime('2026-10-01T09:30:00Z').toUtc(),
          DateTime.utc(2026, 10, 1, 9, 30));
    });

    test('older emoji direction strings still read as money in', () {
      final tx = Transaction.fromJson(
          _tx(type: 'topup', status: 'completed', direction: '⬆️ IN'));
      expect(tx.isIn, isTrue);
    });
  });
}
