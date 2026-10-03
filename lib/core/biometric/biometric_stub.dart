// Platforms without the web helper: no biometric unlock, PIN only.

class Biometric {
  static Future<bool> available() async => false;

  /// The new credential's id, or null if it could not be created.
  static Future<String?> enroll(String name, String displayName) async => null;

  static Future<bool> verify(String credentialId) async => false;
}
