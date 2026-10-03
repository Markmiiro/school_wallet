// Deleting an account from the app. The screen shows what the backend
// says will happen (GET /account/closure/preview), then needs the PIN and
// the word DELETE before the request is sent (POST /account/closure).

import 'package:flutter_test/flutter_test.dart';
import 'package:school_wallet/data/models/account_closure.dart';
import 'package:school_wallet/data/services/account_service.dart';
import 'package:school_wallet/features/profile/screens/delete_account_screen.dart';

void main() {
  group('ClosurePreview', () {
    final json = {
      'children': [
        {'name': 'Amina', 'account_number': '003000000001', 'balance': 7000,
         'has_working_card': true},
        {'name': 'Brian', 'account_number': null, 'balance': 0,
         'has_working_card': false},
      ],
      'unissued_card_fees': 25000,
      'refund_total': 32000,
      'refund_phone': '•••• 222',
      'hold_hours': 72,
      'refund_days': 14,
      'consequences': ['Cards stop working at once.', 'You are signed out.'],
    };

    test('reads children, money owed and consequences', () {
      final p = ClosurePreview.fromJson(json);
      expect(p.children.map((c) => c.name), ['Amina', 'Brian']);
      expect(p.children.first.balance, 7000);
      expect(p.children.first.hasWorkingCard, isTrue);
      expect(p.unissuedCardFees, 25000);
      expect(p.refundTotal, 32000);
      expect(p.refundPhone, '•••• 222');
      expect(p.holdHours, 72);
      expect(p.consequences, hasLength(2));
    });
  });

  group('confirming', () {
    test('needs a 4-digit PIN and DELETE typed exactly', () {
      expect(DeleteAccountScreen.canSubmit(pin: '1234', word: 'DELETE'), isTrue);
      expect(DeleteAccountScreen.canSubmit(pin: '123', word: 'DELETE'), isFalse);
      expect(DeleteAccountScreen.canSubmit(pin: '1234', word: 'delete'), isFalse);
      expect(DeleteAccountScreen.canSubmit(pin: '1234', word: 'DELETE '), isFalse);
      expect(DeleteAccountScreen.canSubmit(pin: '1234', word: ''), isFalse);
    });

    test('sends the PIN and the confirmation word', () {
      expect(AccountService.closureBody(pin: '1234', confirm: 'DELETE'),
          {'pin': '1234', 'confirm': 'DELETE'});
    });
  });
}
