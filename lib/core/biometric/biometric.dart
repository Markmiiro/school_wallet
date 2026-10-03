// Optional fingerprint / face unlock for the app lock. On the web it uses
// WebAuthn through window.nuvoraBiometric (web/index.html); elsewhere it
// reports "not available" and the lock screen offers only the PIN.

export 'biometric_stub.dart' if (dart.library.js_interop) 'biometric_web.dart';
