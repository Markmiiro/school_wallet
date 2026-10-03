// Support: a WhatsApp conversation (email as the fallback) that opens
// with the app version, the screen the parent came from and their
// account, and never anything secret.

import 'package:flutter_test/flutter_test.dart';
import 'package:school_wallet/core/constants/support_config.dart';
import 'package:school_wallet/core/support/support_request.dart';

void main() {
  const version = AppVersion(version: '1.4.0', build: '212');

  group('the app version', () {
    test('reads as version and build', () {
      expect(version.label, '1.4.0 (build 212)');
    });

    test('says so when the build did not stamp one', () {
      expect(const AppVersion(version: '', build: '').label, 'development build');
      expect(const AppVersion(version: '1.4.0', build: '').label, '1.4.0');
    });
  });

  group('the support contacts', () {
    test('come from configuration, with WhatsApp digits only', () {
      const c = SupportConfig(whatsapp: '+256 760 945 424', email: 'support@nuvora.ug');
      expect(c.whatsappDigits, '256760945424');
      expect(c.hasWhatsapp, isTrue);
      expect(c.hasEmail, isTrue);
    });

    test('an unset contact is not offered', () {
      const c = SupportConfig(whatsapp: '', email: '');
      expect(c.hasWhatsapp, isFalse);
      expect(c.hasEmail, isFalse);
    });
  });

  group('the support message', () {
    final request = SupportRequest(
      screen: 'Lock screen',
      account: '256700111222',
      version: version,
    );

    test('carries the version, the screen and the account', () {
      expect(request.message, contains('App version: 1.4.0 (build 212)'));
      expect(request.message, contains('Screen: Lock screen'));
      expect(request.message, contains('Account: 256700111222'));
    });

    test('carries nothing else: no PIN, balance or token', () {
      final lines =
          request.message.split('\n').where((l) => l.contains(':')).toList();
      expect(lines.map((l) => l.split(':').first),
          ['App version', 'Screen', 'Account']);
      expect(request.message.toLowerCase(), isNot(contains('pin')));
      expect(request.message.toLowerCase(), isNot(contains('balance')));
      expect(request.message.toLowerCase(), isNot(contains('token')));
      expect(request.message, isNot(contains('UGX')));
    });

    test('leaves the account out when nobody is signed in', () {
      final anonymous =
          SupportRequest(screen: 'Login', account: null, version: version);
      expect(anonymous.message, isNot(contains('Account')));
    });

    test('opens WhatsApp to our number with the message filled in', () {
      const c = SupportConfig(whatsapp: '+256 760 945 424', email: 'support@nuvora.ug');
      final uri = request.whatsappUri(c);
      expect(uri.scheme, 'https');
      expect(uri.host, 'wa.me');
      expect(uri.path, '/256760945424');
      expect(uri.queryParameters['text'], request.message);
    });

    test('falls back to an email with the same message', () {
      const c = SupportConfig(whatsapp: '+256 760 945 424', email: 'support@nuvora.ug');
      final uri = request.emailUri(c);
      expect(uri.scheme, 'mailto');
      expect(uri.path, 'support@nuvora.ug');
      expect(uri.queryParameters['subject'], 'Nuvora support');
      expect(uri.queryParameters['body'], request.message);
      // Mail apps read "+" as a plus sign, so spaces must be %20.
      expect(uri.toString(), isNot(contains('+')));
    });
  });
}
