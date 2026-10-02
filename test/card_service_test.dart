// The payer's phone number is normalised before a card payment is sent.
// The backend accepts only 256XXXXXXXXX (12 digits).

import 'package:flutter_test/flutter_test.dart';
import 'package:school_wallet/data/services/card_service.dart';

void main() {
  test('accepts the ways a parent types a Ugandan number', () {
    expect(CardService.normalizePhone('0771234567'), '256771234567');
    expect(CardService.normalizePhone('771234567'), '256771234567');
    expect(CardService.normalizePhone('256771234567'), '256771234567');
    expect(CardService.normalizePhone('+256 771 234 567'), '256771234567');
  });

  test('rejects empty, short and over-long numbers', () {
    expect(CardService.normalizePhone(''), isNull);
    expect(CardService.normalizePhone('07712345'), isNull);
    expect(CardService.normalizePhone('07712345678'), isNull);
  });
}
