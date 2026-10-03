// A child's spending controls (GET /wallets/{id}/controls). The limit and
// the card are money controls: every change sends the parent's PIN, and
// every change is listed in the history the backend keeps.

import 'package:flutter_test/flutter_test.dart';
import 'package:school_wallet/data/models/spending_controls.dart';
import 'package:school_wallet/data/models/student.dart';
import 'package:school_wallet/data/services/wallet_service.dart';

void main() {
  final json = {
    'student_id': 7,
    'daily_limit': 8000,
    'spent_today': 1500,
    'remaining_today': 6500,
    'limit_min': 500,
    'limit_max': 5000000,
    'card': {'state': 'blocked', 'last_digits': '1B55',
             'can_block': false, 'can_unblock': true},
    'history': [
      {'by': 'you', 'control': 'daily_limit', 'from': '20000', 'to': '8000',
       'at': '2026-10-03T09:15:00Z'},
      {'by': 'school', 'control': 'card', 'from': 'active', 'to': 'blocked',
       'at': '2026-10-02T06:00:00Z'},
    ],
  };

  test('reads limit, today\'s spend, card state and history', () {
    final c = SpendingControls.fromJson(json);
    expect(c.dailyLimit, 8000);
    expect(c.spentToday, 1500);
    expect(c.remainingToday, 6500);
    expect(c.limitMin, 500);
    expect(c.limitMax, 5000000);
    expect(c.card.state, 'blocked');
    expect(c.card.canUnblock, isTrue);
    expect(c.history, hasLength(2));
    expect(c.history.first.at.isUtc, isTrue);
  });

  test('spend against the limit, as a fraction for the bar', () {
    expect(SpendingControls.fromJson(json).spentFraction, closeTo(0.1875, 1e-9));
    final over = Map<String, dynamic>.from(json)..['spent_today'] = 9000;
    expect(SpendingControls.fromJson(over).spentFraction, 1.0);
  });

  test('history reads as a sentence', () {
    final c = SpendingControls.fromJson(json);
    expect(c.history[0].describe(),
        'You changed the daily limit from UGX 20,000 to UGX 8,000');
    expect(c.history[1].describe(), 'The school blocked the card');
  });

  test('a limit change carries the PIN', () {
    expect(WalletService.limitBody(dailyLimit: 8000, pin: '1234'),
        {'daily_limit': 8000, 'pin': '1234'});
  });

  // The child's wallet screen shows the card with the words the student
  // list uses ("assigned"), so the Controls state is translated to them.
  test('a blocked card reads as blocked on the wallet screen', () {
    final card = SpendingControls.fromJson(json).card;
    expect(card.studentStatus, 'blocked');
    expect(cardStatusLabel(card.studentStatus), 'Blocked');
    expect(cardStatusLabel('blocked'), isNot('Unknown'));
  });

  test('a working card and no card keep the student list\'s words', () {
    CardControl card(String state) => CardControl(
        state: state, lastDigits: null, canBlock: false, canUnblock: false);
    expect(card('active').studentStatus, 'assigned');
    expect(card('none').studentStatus, 'not assigned');
    expect(card('lost').studentStatus, 'lost');
    expect(cardStatusLabel('assigned'), 'Active');
  });

  test('a blocked card can still be reported lost or stolen', () {
    expect(cardCanBeReported('assigned'), isTrue);
    expect(cardCanBeReported('blocked'), isTrue);
    expect(cardCanBeReported('lost'), isFalse);
    expect(cardCanBeReported('not assigned'), isFalse);
    expect(cardCanBeReported(null), isFalse);
  });
}
