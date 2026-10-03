// Children reach a parent through the school's roster: a child whose
// guardian phone matches the parent's number waits until the parent
// proves the number once with an SMS code (GET /family/claimable,
// POST /family/send-code, POST /family/claim). Parents no longer link
// cards by number; the school does that at handout.

import 'package:flutter_test/flutter_test.dart';
import 'package:school_wallet/data/services/family_service.dart';
import 'package:school_wallet/features/family/screens/claim_children_screen.dart';

void main() {
  test('reads how many children wait and whether the phone is proved', () {
    final c = FamilyClaimable.fromJson({'count': 2, 'verified': false});
    expect(c.count, 2);
    expect(c.verified, isFalse);
  });

  test('a claim sends the code only when there is one', () {
    expect(FamilyService.claimBody('123456'), {'code': '123456'});
    expect(FamilyService.claimBody(null), <String, String>{});
  });

  test('the code must be six digits', () {
    expect(ClaimChildrenScreen.isCodeComplete('123456'), isTrue);
    expect(ClaimChildrenScreen.isCodeComplete('12345'), isFalse);
    expect(ClaimChildrenScreen.isCodeComplete('12345a'), isFalse);
  });
}
