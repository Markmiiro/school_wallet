// The card number a parent types is checked before it is sent. The rule
// mirrors normalize_uid() in the backend: 4 to 10 bytes of hex.

import 'package:flutter_test/flutter_test.dart';
import 'package:school_wallet/features/wallet/screens/link_card_screen.dart';

void main() {
  test('normalises separators and case', () {
    expect(LinkCardScreen.normalize('04:a2:1b:55'), '04A21B55');
    expect(LinkCardScreen.normalize(' 04a2 1b55 '), '04A21B55');
    expect(LinkCardScreen.normalize('04-A2-1B-55-07-74-80'), '04A21B55077480');
  });

  test('accepts 4, 7 and 10 byte card numbers', () {
    expect(LinkCardScreen.validate('04A21B55'), isNull);
    expect(LinkCardScreen.validate('04:d1:12:ba:07:74:80'), isNull);
    expect(LinkCardScreen.validate('0102030405060708090A'), isNull);
  });

  test('rejects empty, short, odd-length and over-long numbers', () {
    expect(LinkCardScreen.validate(''), isNotNull);
    expect(LinkCardScreen.validate('   '), isNotNull);
    expect(LinkCardScreen.validate('04A21B'), isNotNull);
    expect(LinkCardScreen.validate('04A21B5'), isNotNull);
    expect(LinkCardScreen.validate('0102030405060708090A0B'), isNotNull);
  });

  test('rejects letters outside A to F', () {
    expect(LinkCardScreen.validate('04A21BZZ'), isNotNull);
    expect(LinkCardScreen.validate('CARD1234'), isNotNull);
  });
}
