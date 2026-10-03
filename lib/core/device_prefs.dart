// Small settings kept on this device only: whether balances are shown,
// when the app was last in use, and the biometric credential for unlock.
// Never sent to the server, and not shared with other devices.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class DevicePrefs {
  Future<String?> read(String key);

  /// Writes [value], or deletes the key when it is null.
  Future<void> write(String key, String? value);
}

class SecureDevicePrefs implements DevicePrefs {
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null; // unreadable storage behaves like a fresh device
    }
  }

  @override
  Future<void> write(String key, String? value) async {
    try {
      if (value == null) {
        await _storage.delete(key: key);
      } else {
        await _storage.write(key: key, value: value);
      }
    } catch (_) {
      // A preference that cannot be saved is not worth crashing over.
    }
  }
}

/// For tests.
class MemoryDevicePrefs implements DevicePrefs {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}
