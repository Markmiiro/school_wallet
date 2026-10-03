// Masked balances and the app lock.
//
// Balances are hidden until the viewer taps them; the choice is kept on
// this device only. The app locks after more than 5 minutes in the
// background, or when the parent taps Lock, and unlocks with the PIN
// (checked by the server) without signing out.

import 'package:flutter_test/flutter_test.dart';
import 'package:school_wallet/core/device_prefs.dart';
import 'package:school_wallet/providers/app_lock.dart';
import 'package:school_wallet/providers/balance_privacy.dart';

class FakeClock {
  DateTime now = DateTime(2026, 10, 3, 12);
  DateTime call() => now;
}

void main() {
  group('BalancePrivacy', () {
    test('hidden by default', () async {
      final p = BalancePrivacy(MemoryDevicePrefs());
      await p.load();
      expect(p.visible, isFalse);
    });

    test('the choice is remembered on the device', () async {
      final prefs = MemoryDevicePrefs();
      final p = BalancePrivacy(prefs);
      await p.load();
      await p.toggle();
      expect(p.visible, isTrue);

      final again = BalancePrivacy(prefs);
      await again.load();
      expect(again.visible, isTrue);
    });

    test('masked text gives nothing away', () {
      expect(BalancePrivacy.masked, 'UGX ••••••');
    });
  });

  group('AppLock', () {
    late MemoryDevicePrefs prefs;
    late FakeClock clock;
    late List<String> pinsTried;
    String? serverAnswer; // null = right PIN, else the error shown

    AppLock make() => AppLock(
          prefs,
          verifyPin: (pin) async {
            pinsTried.add(pin);
            return serverAnswer;
          },
          clock: clock.call,
        );

    setUp(() {
      prefs = MemoryDevicePrefs();
      clock = FakeClock();
      pinsTried = [];
      serverAnswer = null;
    });

    test('more than 5 minutes away locks; less does not', () {
      final t = DateTime(2026, 10, 3, 12);
      expect(AppLock.isStale(null, t), isTrue);
      expect(AppLock.isStale(t.subtract(const Duration(minutes: 4)), t), isFalse);
      expect(AppLock.isStale(t.subtract(const Duration(minutes: 6)), t), isTrue);
    });

    test('a restored session locks if the app was away too long', () async {
      await prefs.write(AppLock.lastActiveKey,
          clock.now.subtract(const Duration(minutes: 30)).toIso8601String());
      final lock = make();
      await lock.start(loggedIn: true);
      expect(lock.locked, isTrue);
    });

    test('a restored session opened again within 5 minutes stays open', () async {
      await prefs.write(AppLock.lastActiveKey,
          clock.now.subtract(const Duration(minutes: 2)).toIso8601String());
      final lock = make();
      await lock.start(loggedIn: true);
      expect(lock.locked, isFalse);
    });

    test('reloading the app does not get round a lock', () async {
      final lock = make();
      await lock.start(loggedIn: true);
      await lock.unlockedBySignIn();
      await lock.lock();
      final reloaded = make();
      await reloaded.start(loggedIn: true);
      expect(reloaded.locked, isTrue);
    });

    test('background for more than 5 minutes locks on return', () async {
      final lock = make();
      await lock.start(loggedIn: true);
      await lock.unlockedBySignIn();
      await lock.onHidden();
      clock.now = clock.now.add(const Duration(minutes: 5, seconds: 1));
      await lock.onShown();
      expect(lock.locked, isTrue);
    });

    test('a short trip to the background does not lock', () async {
      final lock = make();
      await lock.start(loggedIn: true);
      await lock.unlockedBySignIn();
      await lock.onHidden();
      clock.now = clock.now.add(const Duration(minutes: 3));
      await lock.onShown();
      expect(lock.locked, isFalse);
    });

    test('the right PIN unlocks; a wrong one shows the server message', () async {
      final lock = make();
      await lock.start(loggedIn: true);
      await lock.lock();

      serverAnswer = 'Incorrect PIN. 4 attempt(s) remaining before lockout.';
      expect(await lock.unlockWithPin('9999'), serverAnswer);
      expect(lock.locked, isTrue);

      serverAnswer = null;
      expect(await lock.unlockWithPin('1234'), isNull);
      expect(lock.locked, isFalse);
      expect(pinsTried, ['9999', '1234']);
    });

    test('signing out clears the lock', () async {
      final lock = make();
      await lock.start(loggedIn: true);
      await lock.lock();
      await lock.signedOut();
      expect(lock.locked, isFalse);
      final reloaded = make();
      await reloaded.start(loggedIn: false);
      expect(reloaded.locked, isFalse);
    });
  });
}
