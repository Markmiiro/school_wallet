// The states where there is nothing yet: a parent with no child, no
// card and no money, and every screen before its data has arrived or
// when it could not be fetched.
//
// "Get started" lists what is still to do (child on the account, a
// card, a first top-up) and each step goes once done. Loading and
// failing are never shown as "empty": an account that has not loaded is
// not an account with no children.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:school_wallet/core/device_prefs.dart';
import 'package:school_wallet/core/load_error.dart';
import 'package:school_wallet/core/widgets/activity_feed.dart';
import 'package:school_wallet/core/widgets/state_views.dart';
import 'package:school_wallet/data/models/auth_user.dart';
import 'package:school_wallet/data/models/student.dart';
import 'package:school_wallet/data/models/wallet_balance.dart';
import 'package:school_wallet/data/models/wallet_history.dart';
import 'package:school_wallet/data/services/card_service.dart';
import 'package:school_wallet/data/services/family_service.dart';
import 'package:school_wallet/data/services/wallet_service.dart';
import 'package:school_wallet/features/dashboard/get_started.dart';
import 'package:school_wallet/features/dashboard/screens/dashboard_screen.dart';
import 'package:school_wallet/providers/auth_provider.dart';
import 'package:school_wallet/providers/balance_privacy.dart';
import 'package:school_wallet/providers/wallet_provider.dart';

Student _child(int id, String name, {String? card = 'assigned'}) =>
    Student(id: id, name: name, schoolId: 1, cardStatus: card);

final _amina = _child(1, 'Amina Test');
final _brian = _child(2, 'Brian Test', card: 'not assigned');

class FakeWalletService extends WalletService {
  List<Student> students = [];
  Map<int, double> balance = {};
  Map<int, double> toppedUp = {};
  Object? studentsError;
  Set<int> historyFails = {};
  int studentCalls = 0;
  int historyCalls = 0;
  Completer<void>? gate;

  @override
  Future<List<Student>> getStudentsForParent(int parentId) async {
    studentCalls++;
    if (gate != null) await gate!.future;
    if (studentsError != null) throw studentsError!;
    return students;
  }

  @override
  Future<WalletBalance> getWalletBalance(int studentId) async => WalletBalance(
      studentId: studentId,
      walletId: studentId * 10,
      balance: balance[studentId] ?? 0,
      isActive: true);

  @override
  Future<WalletHistory> getWalletHistory(int studentId, {int limit = 20}) async {
    historyCalls++;
    if (historyFails.contains(studentId)) throw Exception('nope');
    return WalletHistory(
      studentId: studentId,
      walletId: studentId * 10,
      currentBalance: balance[studentId] ?? 0,
      currency: 'UGX',
      totalToppedUp: toppedUp[studentId] ?? 0,
      totalSpent: 0,
      numberOfTransactions: 0,
      transactions: [],
    );
  }
}

class FakeFamilyService extends FamilyService {
  int waiting;
  FakeFamilyService([this.waiting = 0]);

  @override
  Future<FamilyClaimable> claimable() async =>
      FamilyClaimable(count: waiting, verified: false);
}

class FakeCardService extends CardService {
  Set<int> paid;
  FakeCardService([this.paid = const {}]);

  @override
  Future<Set<int>> paidFor(Iterable<int> studentIds) async =>
      paid.intersection(studentIds.toSet());
}

void main() {
  group('the steps still to do', () {
    test('a new account has all three, in order', () {
      expect(setupStepsLeft(students: [], toppedUp: false),
          [SetupStep.child, SetupStep.card, SetupStep.topUp]);
    });

    test('the child step goes once a child is on the account', () {
      expect(setupStepsLeft(students: [_brian], toppedUp: false),
          [SetupStep.card, SetupStep.topUp]);
    });

    test('the card step goes once every child has had a card', () {
      expect(setupStepsLeft(students: [_amina], toppedUp: false), [SetupStep.topUp]);
      expect(setupStepsLeft(students: [_amina, _brian], toppedUp: true),
          [SetupStep.card]);
    });

    test('a lost or blocked card is not a getting-started matter', () {
      for (final status in ['lost', 'stolen', 'blocked', 'replaced', null]) {
        expect(
            setupStepsLeft(students: [_child(1, 'Amina', card: status)], toppedUp: true),
            isEmpty,
            reason: '$status');
      }
    });

    test('nothing is left once there is a child, a card and a top-up', () {
      expect(setupStepsLeft(students: [_amina], toppedUp: true), isEmpty);
    });

    test('the top-up step is not shown while it is not known', () {
      expect(setupStepsLeft(students: [_amina], toppedUp: null), isEmpty);
    });
  });

  group('what each step says', () {
    test('no child waiting: ask the school, naming the number', () {
      final copy = childStepCopy(waiting: 0, phone: '256771234567');
      expect(copy.title, 'Ask the school to add your number');
      expect(copy.body, contains('256771234567'));
      expect(copy.action, 'Check again');
    });

    test('children waiting: add them', () {
      expect(childStepCopy(waiting: 1).title, '1 child is waiting for you');
      final two = childStepCopy(waiting: 2);
      expect(two.title, '2 children are waiting for you');
      expect(two.action, 'Add them');
    });

    test('before there is a child, the later steps offer nothing to tap', () {
      expect(cardStepCopy(students: []).action, isNull);
      expect(topUpStepCopy(students: []).action, isNull);
    });

    test('the card step names the children without one', () {
      final copy = cardStepCopy(students: [_amina, _brian]);
      expect(copy.title, 'Get Brian a card');
      expect(copy.body, contains('UGX 25,000'));
      expect(copy.body, contains('school links it'));
      expect(copy.action, 'Buy a card');
    });

    test('a card already paid for is collected, never bought again', () {
      final copy = cardStepCopy(students: [_brian], paidFor: {2});
      expect(copy.title, 'Collect the card for Brian');
      expect(copy.action, isNull);
    });

    test('several names read as a sentence', () {
      expect(firstNames([_amina]), 'Amina');
      expect(firstNames([_amina, _brian]), 'Amina and Brian');
      expect(firstNames([_amina, _brian, _child(3, 'Chris K')]),
          'Amina, Brian and Chris');
    });

    test('nowhere does a step tell the parent to create a child or link a card',
        () {
      final all = [
        childStepCopy(waiting: 0, phone: '256771234567'),
        childStepCopy(waiting: 2),
        cardStepCopy(students: []),
        cardStepCopy(students: [_brian]),
        cardStepCopy(students: [_brian], paidFor: {2}),
        topUpStepCopy(students: [_brian]),
      ];
      for (final copy in all) {
        final words = '${copy.title} ${copy.body} ${copy.action ?? ''}'.toLowerCase();
        expect(words, isNot(contains('add a child')));
        expect(words, isNot(contains('link a card')));
        expect(words, isNot(contains('card number')));
      }
    });
  });

  group('a paid card order', () {
    test('is read from the child\'s orders', () {
      expect(
          CardService.hasPaidOrder({
            'orders': [
              {'status': 'failed'},
              {'status': 'paid'},
            ]
          }),
          isTrue);
      expect(
          CardService.hasPaidOrder({
            'orders': [
              {'status': 'pending'},
              {'status': 'fulfilled'},
            ]
          }),
          isFalse);
      expect(CardService.hasPaidOrder({'orders': []}), isFalse);
      expect(CardService.hasPaidOrder({}), isFalse);
    });
  });

  group('loading, failing and empty are three different things', () {
    test('before the first load nothing is known', () {
      final wallet = WalletProvider(service: FakeWalletService());
      expect(wallet.hasLoaded, isFalse);
      expect(wallet.errorMessage, isNull);
    });

    test('an empty account has loaded, with no error', () async {
      final wallet = WalletProvider(service: FakeWalletService());
      await wallet.loadForParent(7);
      expect(wallet.hasLoaded, isTrue);
      expect(wallet.students, isEmpty);
      expect(wallet.errorMessage, isNull);
    });

    test('a failed load is not an empty account', () async {
      final service = FakeWalletService()..studentsError = TimeoutException('slow');
      final wallet = WalletProvider(service: service);
      await wallet.loadForParent(7);
      expect(wallet.hasLoaded, isFalse);
      expect(wallet.errorMessage, couldNotReachServer);

      service.studentsError = null;
      await wallet.loadForParent(7);
      expect(wallet.hasLoaded, isTrue);
      expect(wallet.errorMessage, isNull);
    });

    test('a failed refresh keeps what loaded before', () async {
      final service = FakeWalletService()..students = [_amina];
      final wallet = WalletProvider(service: service);
      await wallet.loadForParent(7);
      service.studentsError = Exception('Failed to load students (500)');
      await wallet.loadForParent(7);
      expect(wallet.hasLoaded, isTrue);
      expect(wallet.students, hasLength(1));
      expect(wallet.errorMessage, 'Failed to load students (500)');
    });

    test('another parent on the same phone starts from nothing', () async {
      final service = FakeWalletService()..students = [_amina];
      final wallet = WalletProvider(service: service);
      await wallet.loadForParent(7);
      service.studentsError = Exception('down');
      await wallet.loadForParent(8);
      expect(wallet.hasLoaded, isFalse);
      expect(wallet.students, isEmpty);
    });

    test('Home and Transactions asking together make one request', () async {
      final service = FakeWalletService()..gate = Completer<void>();
      final wallet = WalletProvider(service: service);
      final a = wallet.loadForParent(7);
      final b = wallet.loadForParent(7);
      service.gate!.complete();
      await Future.wait([a, b]);
      expect(service.studentCalls, 1);
      await wallet.loadForParent(7);
      expect(service.studentCalls, 2);
    });

    test('the same goes for the history', () async {
      final service = FakeWalletService()..students = [_amina];
      final wallet = WalletProvider(service: service);
      await wallet.loadForParent(7);
      await Future.wait(
          [wallet.loadFamilyTransactions(), wallet.loadFamilyTransactions()]);
      expect(service.historyCalls, 1);
    });

    test('network errors are put in the parent\'s words', () {
      expect(loadErrorText(TimeoutException('x')), couldNotReachServer);
      expect(loadErrorText(Exception('ClientException: Failed to fetch')),
          couldNotReachServer);
      expect(loadErrorText(Exception('Parent not found.')), 'Parent not found.');
    });

    test('history that fails for every child is an error, not "no activity"',
        () async {
      final service = FakeWalletService()
        ..students = [_amina, _brian]
        ..historyFails = {1, 2};
      final wallet = WalletProvider(service: service);
      await wallet.loadForParent(7);
      await wallet.loadFamilyTransactions();
      expect(wallet.historyError, isNotNull);

      service.historyFails = {2};
      await wallet.loadFamilyTransactions();
      expect(wallet.historyError, isNull);
      expect(wallet.historyFailedFor, ['Brian Test']);
    });
  });

  group('whether money has ever gone in', () {
    test('a balance says yes at once', () async {
      final service = FakeWalletService()
        ..students = [_amina]
        ..balance = {1: 5000};
      final wallet = WalletProvider(service: service);
      await wallet.loadForParent(7);
      expect(wallet.hasToppedUp, isTrue);
    });

    test('a zero balance is not known until the history is read', () async {
      final service = FakeWalletService()..students = [_amina];
      final wallet = WalletProvider(service: service);
      await wallet.loadForParent(7);
      expect(wallet.hasToppedUp, isNull);
      await wallet.loadFamilyTransactions();
      expect(wallet.hasToppedUp, isFalse);
    });

    test('money topped up and all spent still counts', () async {
      final service = FakeWalletService()
        ..students = [_amina]
        ..toppedUp = {1: 10000};
      final wallet = WalletProvider(service: service);
      await wallet.loadForParent(7);
      await wallet.loadFamilyTransactions();
      expect(wallet.hasToppedUp, isTrue);
    });

    test('a history that could not be read leaves it unknown', () async {
      final service = FakeWalletService()
        ..students = [_amina]
        ..historyFails = {1};
      final wallet = WalletProvider(service: service);
      await wallet.loadForParent(7);
      await wallet.loadFamilyTransactions();
      expect(wallet.hasToppedUp, isNull);
    });
  });

  group('an empty activity list', () {
    test('says what will show and what makes it show', () {
      final family = emptyActivityCopy();
      expect(family.title, 'No activity yet');
      expect(family.body, contains('top-up'));
      expect(family.body, contains('tuck shop'));

      final child = emptyActivityCopy(firstName: 'Amina');
      expect(child.title, 'Amina has no activity yet');
      expect(child.body, contains('with the card'));
    });

    test('a child with no card is told the card comes first', () {
      final copy = emptyActivityCopy(firstName: 'Brian', hasCard: false);
      expect(copy.body, contains('once Brian has a card'));
    });
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('the Get started panel at 360px', () {
    Future<List<String>> pumpPanel(
      WidgetTester tester, {
      required List<Student> students,
      required bool? toppedUp,
      int waiting = 0,
      Set<int> paidFor = const {},
    }) async {
      phone(tester);
      final taps = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              GetStartedPanel(
                steps: setupStepsLeft(students: students, toppedUp: toppedUp),
                students: students,
                waiting: waiting,
                phone: '256771234567',
                paidFor: paidFor,
                onAddChildren: () => taps.add('add'),
                onCheckAgain: () => taps.add('check'),
                onBuyCard: () => taps.add('card'),
                onTopUp: () => taps.add('topup'),
              ),
            ],
          ),
        ),
      ));
      await tester.pump();
      return taps;
    }

    testWidgets('a new account: the first step is the one with a button',
        (tester) async {
      final taps = await pumpPanel(tester, students: [], toppedUp: false);
      expect(tester.takeException(), isNull);
      expect(find.text('3 steps left'), findsOneWidget);
      expect(find.text('Ask the school to add your number'), findsOneWidget);
      expect(find.text('Get a card'), findsOneWidget);
      expect(find.text('Make your first top-up'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);

      await tester.tap(find.text('Check again'));
      // The later steps cannot be done yet and do nothing.
      await tester.tap(find.text('Get a card'));
      await tester.tap(find.text('Make your first top-up'));
      expect(taps, ['check']);
    });

    testWidgets('children waiting: the button adds them', (tester) async {
      final taps =
          await pumpPanel(tester, students: [], toppedUp: false, waiting: 2);
      await tester.tap(find.text('Add them'));
      expect(taps, ['add']);
    });

    testWidgets('with a child: card next, top-up can be opened early',
        (tester) async {
      final taps = await pumpPanel(tester, students: [_brian], toppedUp: false);
      expect(tester.takeException(), isNull);
      expect(find.text('2 steps left'), findsOneWidget);
      expect(find.text('Ask the school to add your number'), findsNothing);
      await tester.tap(find.text('Buy a card'));
      await tester.tap(find.text('Make your first top-up'));
      expect(taps, ['card', 'topup']);
    });

    testWidgets('a paid card shows no Buy button', (tester) async {
      await pumpPanel(tester, students: [_brian], toppedUp: true, paidFor: {2});
      expect(find.text('Collect the card for Brian'), findsOneWidget);
      expect(find.text('Buy a card'), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('only the top-up left', (tester) async {
      final taps = await pumpPanel(tester, students: [_amina], toppedUp: false);
      expect(find.text('1 step left'), findsOneWidget);
      await tester.tap(find.text('Top up'));
      expect(taps, ['topup']);
    });

    testWidgets('nothing left: the panel is gone', (tester) async {
      await pumpPanel(tester, students: [_amina], toppedUp: true);
      expect(find.text('Get started'), findsNothing);
    });

    testWidgets('long names do not overflow', (tester) async {
      await pumpPanel(tester,
          students: [
            _child(1, 'Nakimuli Namutebi Josephine', card: 'no card slot'),
            _child(2, 'Ssekandi-Mukasa Emmanuel', card: 'not assigned'),
            _child(3, 'Byaruhanga Tumwesigye', card: 'not assigned'),
          ],
          toppedUp: false);
      expect(tester.takeException(), isNull);
    });
  });

  group('Home', () {
    Future<void> pumpHome(
      WidgetTester tester,
      FakeWalletService service, {
      int waiting = 0,
      Set<int> paid = const {},
    }) async {
      phone(tester);
      final auth = AuthProvider()
        ..isLoggedIn = true
        ..currentUser =
            AuthUser(id: 7, name: 'Grace Parent', phone: '256771234567', role: 'parent');
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider(create: (_) => WalletProvider(service: service)),
          ChangeNotifierProvider(create: (_) => BalancePrivacy(MemoryDevicePrefs())),
        ],
        child: MaterialApp(
          home: DashboardScreen(
            familyService: FakeFamilyService(waiting),
            cardService: FakeCardService(paid),
          ),
        ),
      ));
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    testWidgets('while loading shows neither content nor "nothing"',
        (tester) async {
      final service = FakeWalletService()..gate = Completer<void>();
      await pumpHome(tester, service);
      await tester.pump();
      expect(find.byType(LoadingBlocks), findsOneWidget);
      expect(find.text('Get started'), findsNothing);
      expect(find.text('Your Children'), findsNothing);

      service.gate!.complete();
      await settle(tester);
      expect(find.byType(LoadingBlocks), findsNothing);
      expect(find.text('Get started'), findsOneWidget);
    });

    testWidgets('an empty account shows the next step and no empty boxes',
        (tester) async {
      await pumpHome(tester, FakeWalletService());
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Welcome,'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
      expect(find.text('Ask the school to add your number'), findsOneWidget);
      expect(find.text('Total family balance'), findsNothing);
      expect(find.text('Your Children'), findsNothing);
      expect(find.text('History'), findsNothing);
      expect(find.text('Buy a Card'), findsNothing);
      expect(find.text('No children linked yet'), findsNothing);
    });

    testWidgets('an empty account with children waiting leads with adding them',
        (tester) async {
      await pumpHome(tester, FakeWalletService(), waiting: 2);
      await settle(tester);
      expect(find.text('2 children are waiting for you'), findsOneWidget);
      expect(find.text('Add them'), findsOneWidget);
    });

    testWidgets('a failed load says so and offers to try again', (tester) async {
      final service = FakeWalletService()..studentsError = TimeoutException('slow');
      await pumpHome(tester, service);
      await settle(tester);
      expect(find.text('Could not load your account'), findsOneWidget);
      expect(find.text(couldNotReachServer), findsOneWidget);
      expect(find.text('Get started'), findsNothing);

      service.studentsError = null;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.text('Could not load your account'), findsNothing);
      expect(find.text('Get started'), findsOneWidget);
    });

    testWidgets('a child with no card and no money: two steps left',
        (tester) async {
      final service = FakeWalletService()..students = [_brian];
      await pumpHome(tester, service);
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Welcome back,'), findsOneWidget);
      expect(find.text('Total family balance'), findsOneWidget);
      expect(find.text('Your Children'), findsOneWidget);
      expect(find.text('Brian Test'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Get Brian a card'), 200);
      expect(find.text('2 steps left'), findsOneWidget);
    });

    testWidgets('a full account has no Get started at all', (tester) async {
      final service = FakeWalletService()
        ..students = [_amina]
        ..balance = {1: 5000};
      await pumpHome(tester, service);
      await settle(tester);
      expect(find.text('Get started'), findsNothing);
      expect(find.text('Your Children'), findsOneWidget);
    });
  });
}
