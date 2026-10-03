// The app lock. Locks after more than [timeout] in the background, when
// the app is reopened after that long, or when the parent taps Lock.
// Locking does not sign out: the session and the screen underneath stay
// as they were, and the right PIN (checked by the server, see
// POST /auth/unlock) or a biometric check on this device lifts the lock.
//
// "Last active" is written on every heartbeat while the app is in use,
// so a tab closed or killed without warning still counts as away. The
// locked flag is stored too, so reloading the page does not undo a lock.

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/device_prefs.dart';

/// Returns null when the PIN is right, or the message to show.
typedef PinVerifier = Future<String?> Function(String pin);

class AppLock extends ChangeNotifier {
  static const timeout = Duration(minutes: 5);
  static const heartbeat = Duration(seconds: 30);
  static const lastActiveKey = 'last_active_at';
  static const lockedKey = 'app_locked';

  final DevicePrefs _prefs;
  final PinVerifier verifyPin;
  final DateTime Function() _now;

  bool locked = false;
  bool _signedIn = false;
  DateTime? _hiddenAt;
  DateTime? _lastBeat;
  Timer? _timer;

  AppLock(this._prefs, {required this.verifyPin, DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  static bool isStale(DateTime? lastActive, DateTime now) =>
      lastActive == null || now.difference(lastActive) > timeout;

  /// Called once at startup, after the stored session has been read.
  Future<void> start({required bool loggedIn}) async {
    _signedIn = loggedIn;
    if (!loggedIn) {
      locked = false;
    } else {
      final raw = await _prefs.read(lastActiveKey);
      final last = raw == null ? null : DateTime.tryParse(raw);
      locked = await _prefs.read(lockedKey) == 'true' || isStale(last, _now());
    }
    if (locked) await _prefs.write(lockedKey, 'true');
    await _touch();
    notifyListeners();
  }

  /// Starts the heartbeat. Kept out of start() so tests run without timers.
  void startHeartbeat() {
    _timer?.cancel();
    _timer = Timer.periodic(heartbeat, (_) => _beat());
  }

  Future<void> _beat() async {
    final now = _now();
    // Timers stop while a phone sleeps. A long gap between beats means
    // the app was away even if no hide event arrived.
    if (_signedIn && !locked && _lastBeat != null && isStale(_lastBeat, now)) {
      await lock();
    }
    _lastBeat = now;
    await _touch();
  }

  Future<void> _touch() async {
    if (!_signedIn || locked) return;
    _lastBeat = _now();
    await _prefs.write(lastActiveKey, _lastBeat!.toIso8601String());
  }

  Future<void> onHidden() async {
    _hiddenAt = _now();
    await _touch();
  }

  Future<void> onShown() async {
    final hiddenAt = _hiddenAt;
    _hiddenAt = null;
    if (_signedIn && !locked && hiddenAt != null && isStale(hiddenAt, _now())) {
      await lock();
      return;
    }
    await _touch();
  }

  Future<void> lock() async {
    if (!_signedIn) return;
    locked = true;
    notifyListeners();
    await _prefs.write(lockedKey, 'true');
  }

  Future<void> _unlock() async {
    locked = false;
    await _prefs.write(lockedKey, null);
    await _touch();
    notifyListeners();
  }

  /// Returns null on success, or the message to show under the PIN.
  Future<String?> unlockWithPin(String pin) async {
    final problem = await verifyPin(pin);
    if (problem == null) await _unlock();
    return problem;
  }

  /// A biometric check passed on this device.
  Future<void> unlockedByBiometric() => _unlock();

  /// A full sign-in (login or signup) needs no further unlock.
  Future<void> unlockedBySignIn() async {
    _signedIn = true;
    await _unlock();
  }

  Future<void> signedOut() async {
    _signedIn = false;
    locked = false;
    await _prefs.write(lockedKey, null);
    await _prefs.write(lastActiveKey, null);
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
