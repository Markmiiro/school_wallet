// Whether balances are shown. Hidden by default, because the phone may be
// passed around; the viewer taps a balance to show or hide them all, and
// that choice is remembered on this device only.

import 'package:flutter/foundation.dart';
import '../core/device_prefs.dart';

class BalancePrivacy extends ChangeNotifier {
  static const key = 'balances_visible';
  static const masked = 'UGX ••••••';

  final DevicePrefs _prefs;
  bool visible = false;

  BalancePrivacy(this._prefs);

  Future<void> load() async {
    visible = await _prefs.read(key) == 'true';
    notifyListeners();
  }

  Future<void> toggle() async {
    visible = !visible;
    notifyListeners();
    await _prefs.write(key, visible ? 'true' : null);
  }
}
