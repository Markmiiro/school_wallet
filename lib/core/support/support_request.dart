// What a parent sends when they ask for help: the app version, the
// screen they came from and their account, so support does not have to
// ask. Nothing secret is ever put in: not the PIN, a balance or a token.

import '../constants/support_config.dart';

class SupportRequest {
  /// The screen the parent asked from, e.g. "Profile", "Lock screen".
  final String screen;

  /// The phone number the account is registered under; null if nobody
  /// is signed in.
  final String? account;
  final AppVersion version;

  const SupportRequest({
    required this.screen,
    required this.account,
    this.version = AppVersion.current,
  });

  String get message => [
        'Hello Nuvora support, I need help.',
        '',
        'App version: ${version.label}',
        'Screen: $screen',
        if (account != null && account!.isNotEmpty) 'Account: $account',
      ].join('\n');

  // Built by hand: Uri(queryParameters:) writes spaces as "+", which mail
  // apps show as plus signs.
  static String _query(Map<String, String> values) => values.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');

  Uri whatsappUri(SupportConfig config) => Uri.parse(
      'https://wa.me/${config.whatsappDigits}?${_query({'text': message})}');

  Uri emailUri(SupportConfig config) => Uri.parse(
      'mailto:${config.email.trim()}?${_query({'subject': 'Nuvora support', 'body': message})}');
}
