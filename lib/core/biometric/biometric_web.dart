// Web: WebAuthn platform authenticator, via window.nuvoraBiometric in
// web/index.html. Every failure (no sensor, cancelled, old browser,
// helper missing) comes back as "not available" or "not verified", so
// the lock screen falls back to the PIN.

import 'dart:js_interop';

@JS('nuvoraBiometric')
external _Helper? get _helper;

extension type _Helper._(JSObject _) implements JSObject {
  external JSPromise<JSBoolean> available();
  external JSPromise<JSString> enroll(JSString name, JSString displayName);
  external JSPromise<JSBoolean> verify(JSString credentialId);
}

class Biometric {
  static Future<bool> available() async {
    try {
      final h = _helper;
      if (h == null) return false;
      return (await h.available().toDart).toDart;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> enroll(String name, String displayName) async {
    try {
      final h = _helper;
      if (h == null) return null;
      final id = (await h.enroll(name.toJS, displayName.toJS).toDart).toDart;
      return id.isEmpty ? null : id;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> verify(String credentialId) async {
    try {
      final h = _helper;
      if (h == null) return false;
      return (await h.verify(credentialId.toJS).toDart).toDart;
    } catch (_) {
      return false;
    }
  }
}
