// The spending views: a purchase row, activity grouped by day, a filter
// per child, and the "has not spent anything yet" state.
//
// The purchase payload mirrors what a real till sale produces: the till
// page (app/routes/tuckshop.py) sends every sale with the description
// "Tuck shop purchase", so the tuck shop's name comes from `merchant`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:school_wallet/core/device_prefs.dart';
import 'package:school_wallet/core/widgets/activity_feed.dart';
import 'package:school_wallet/data/models/wallet_history.dart';
import 'package:school_wallet/providers/balance_privacy.dart';
import 'package:school_wallet/providers/wallet_provider.dart';

Map<String, dynamic> _purchase({
  int id = 1,
  int amount = 1500,
  String? merchant = 'Click Tuck Shop',
  String? description = 'Tuck shop purchase',
  String date = '2026-10-03T13:05:00',
}) =>
    {
      'id': id,
      'type': 'payment',
      'direction': 'OUT',
      'amount': amount,
      'status': 'completed',
      'reference': 'req-$id',
      'description': description,
      'merchant': merchant,
      'date': date,
    };

Map<String, dynamic> _topUp({
  int id = 50,
  String status = 'completed',
  String? description = 'Top-up for Amina Test',
  String date = '2026-10-02T08:00:00',
}) =>
    {
      'id': id,
      'type': 'topup',
      'direction': 'IN',
      'amount': 10000,
      'status': status,
      'reference': 'top-$id',
      'description': description,
      'merchant': null,
      'date': date,
    };

FamilyTransaction _item(Map<String, dynamic> json,
        {int studentId = 1, String name = 'Amina Test'}) =>
    FamilyTransaction(
        studentName: name, studentId: studentId, tx: Transaction.fromJson(json));

const _longName =
    'St. Mary\'s College Kisubi Senior Students\' Cooperative Canteen and Stationery Shop';

void main() {
  group('a purchase', () {
    test('is named after the tuck shop, not the till\'s fixed description', () {
      final tx = Transaction.fromJson(_purchase());
      expect(tx.isPurchase, isTrue);
      expect(tx.isIn, isFalse);
      expect(tx.merchant, 'Click Tuck Shop');
      expect(tx.title, 'Click Tuck Shop');
    });

    test('from an older backend reads the shop out of the description', () {
      final tx = Transaction.fromJson(
          _purchase(merchant: null, description: 'NFC payment at Click Tuck Shop'));
      expect(tx.title, 'Click Tuck Shop');
    });

    test('with no shop known still says what it was', () {
      final tx = Transaction.fromJson(_purchase(merchant: null));
      expect(tx.title, 'Tuck shop purchase');
    });

    test('made while the till was offline is marked', () {
      final tx = Transaction.fromJson(
          _purchase(description: '[OFFLINE] Tuck shop purchase (offline)'));
      expect(tx.isOffline, isTrue);
      expect(tx.title, 'Click Tuck Shop');
      expect(Transaction.fromJson(_purchase()).isOffline, isFalse);
    });
  });

  group('a top-up', () {
    test('is titled Top-up; the child is shown separately', () {
      final tx = Transaction.fromJson(_topUp());
      expect(tx.isPurchase, isFalse);
      expect(tx.title, 'Top-up');
      expect(tx.note, isNull);
    });

    test('keeps the parent\'s own note', () {
      final tx = Transaction.fromJson(_topUp(description: 'Lunch money'));
      expect(tx.title, 'Top-up');
      expect(tx.note, 'Lunch money');
    });

    test('by USSD says so', () {
      final tx = Transaction.fromJson(
          _topUp(description: 'USSD top-up via School Wallet'));
      expect(tx.note, 'By USSD');
    });
  });

  group('grouping by day', () {
    final now = DateTime(2026, 10, 3, 18);

    test('day headers read Today, Yesterday, then the date', () {
      expect(dayLabel(DateTime(2026, 10, 3), now: now), 'Today');
      expect(dayLabel(DateTime(2026, 10, 2), now: now), 'Yesterday');
      expect(dayLabel(DateTime(2026, 9, 26), now: now), 'Sat, 26 Sep');
      expect(dayLabel(DateTime(2025, 12, 31), now: now), 'Wed, 31 Dec 2025');
    });

    test('one group per calendar day, newest first, order kept inside', () {
      final items = [
        _item(_purchase(id: 3, date: '2026-10-03T13:05:00')),
        _item(_purchase(id: 2, amount: 500, date: '2026-10-03T07:10:00')),
        _item(_topUp(id: 50, date: '2026-10-02T08:00:00')),
      ];
      final days = groupByDay(items);
      expect(days, hasLength(2));
      expect(days[0].items.map((i) => i.tx.id), [3, 2]);
      expect(days[1].items.map((i) => i.tx.id), [50]);
      final first = days[0].day;
      expect([first.hour, first.minute], [0, 0]);
    });

    test('a day\'s spend counts completed purchases only', () {
      final days = groupByDay([
        _item(_purchase(id: 3, amount: 1500)),
        _item(_purchase(id: 2, amount: 500)),
        _item(_topUp(id: 51, date: '2026-10-03T06:00:00')),
      ]);
      expect(days.single.spent, 2000);
    });
  });

  group('one child at a time', () {
    final items = [
      _item(_purchase(id: 3), studentId: 1, name: 'Amina Test'),
      _item(_topUp(id: 50), studentId: 2, name: 'Brian Test'),
      _item(_topUp(id: 51), studentId: 1, name: 'Amina Test'),
    ];

    test('filters the family feed to that child', () {
      expect(activityFor(items, null), hasLength(3));
      expect(activityFor(items, 1).map((i) => i.tx.id), [3, 51]);
      expect(activityFor(items, 2).map((i) => i.tx.id), [50]);
    });

    test('knows a child who has not spent anything yet', () {
      expect(hasSpent(activityFor(items, 1)), isTrue);
      expect(hasSpent(activityFor(items, 2)), isFalse);
      expect(hasSpent([]), isFalse);
    });
  });

  group('the row at 360px', () {
    Future<void> pumpFeed(WidgetTester tester, List<FamilyTransaction> items,
        {bool showChild = true}) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ChangeNotifierProvider(
        create: (_) => BalancePrivacy(MemoryDevicePrefs()),
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(20),
              children: [ActivityFeed(items: items, showChild: showChild)],
            ),
          ),
        ),
      ));
      await tester.pump();
    }

    testWidgets('survives a very long tuck shop name and a long child name',
        (tester) async {
      await pumpFeed(tester, [
        _item(_purchase(merchant: _longName, amount: 5000000),
            name: 'Nakimuli Namutebi Josephine Mary Immaculate'),
      ]);
      expect(tester.takeException(), isNull);
      // The amount and the time are never cut.
      expect(find.text('-UGX 5,000,000'), findsOneWidget);
      final time = tester.widget<Text>(find.byKey(const ValueKey('activity-time-1')));
      expect(time.softWrap, isFalse);
      expect(time.overflow, isNot(TextOverflow.ellipsis));
      final row = tester.getSize(find.byType(ActivityRow));
      expect(row.width, lessThanOrEqualTo(320));
    });

    testWidgets('a purchase and a top-up look different', (tester) async {
      await pumpFeed(tester, [
        _item(_purchase(id: 3)),
        _item(_topUp(id: 50, date: '2026-10-03T08:00:00')),
      ]);
      expect(tester.takeException(), isNull);
      expect(find.text('-UGX 1,500'), findsOneWidget);
      expect(find.text('+UGX 10,000'), findsOneWidget);
      expect(find.byIcon(Icons.storefront_rounded), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.text('Click Tuck Shop'), findsOneWidget);
      expect(find.text('Amina Test'), findsNWidgets(2));
    });

    testWidgets('one date header per day, no date on the rows', (tester) async {
      await pumpFeed(tester, [
        _item(_purchase(id: 3, date: '2026-10-03T13:05:00')),
        _item(_purchase(id: 2, date: '2026-10-03T07:10:00')),
      ]);
      expect(find.byType(ActivityDayHeader), findsOneWidget);
      expect(find.byType(ActivityRow), findsNWidgets(2));
    });

    testWidgets('a child\'s own view leaves the child\'s name off the rows',
        (tester) async {
      await pumpFeed(tester, [_item(_purchase())], showChild: false);
      expect(find.text('Amina Test'), findsNothing);
    });
  });
}
