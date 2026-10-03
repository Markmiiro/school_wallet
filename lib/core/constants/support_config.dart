// Where support requests go, and which build this is. Both come from the
// build, not from a widget:
//
//   SUPPORT_WHATSAPP, SUPPORT_EMAIL   --dart-define, to point a build at
//                                     other contacts without a code change
//   APP_VERSION, APP_BUILD            stamped by tool/build_web.sh from
//                                     pubspec.yaml and the git history
//
// The values are compiled in, so the version shown is the version of the
// code that is running, even when an installed PWA is serving an older
// copy from its cache.

class SupportConfig {
  final String whatsapp;
  final String email;

  const SupportConfig({required this.whatsapp, required this.email});

  /// The contacts printed on Nuvora's material; confirmed as monitored
  /// on 3 Oct 2026.
  static const current = SupportConfig(
    whatsapp: String.fromEnvironment('SUPPORT_WHATSAPP', defaultValue: '+256 760 945 424'),
    email: String.fromEnvironment('SUPPORT_EMAIL', defaultValue: 'support@nuvora.ug'),
  );

  /// The number as wa.me wants it: country code and digits, nothing else.
  String get whatsappDigits => whatsapp.replaceAll(RegExp(r'\D'), '');

  bool get hasWhatsapp => whatsappDigits.isNotEmpty;
  bool get hasEmail => email.trim().isNotEmpty;
}

class AppVersion {
  final String version;
  final String build;

  const AppVersion({required this.version, required this.build});

  static const current = AppVersion(
    version: String.fromEnvironment('APP_VERSION'),
    build: String.fromEnvironment('APP_BUILD'),
  );

  /// "1.4.0 (build 212)". A build made without the script says so.
  String get label {
    if (version.isEmpty) return 'development build';
    return build.isEmpty ? version : '$version (build $build)';
  }
}
