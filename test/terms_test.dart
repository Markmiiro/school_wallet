// Terms and privacy acceptance. The app shows the text the backend
// serves at GET /auth/terms, and sends back the version the parent
// accepted: with signup (before the account exists), and with login
// when the backend says the accepted version is out of date.

import 'package:flutter_test/flutter_test.dart';
import 'package:school_wallet/data/models/terms.dart';
import 'package:school_wallet/data/services/auth_service.dart';

void main() {
  group('Terms', () {
    final json = {
      'version': '2026-10-01',
      'summary': [
        {'title': 'What we collect', 'body': 'Your name and phone number.'},
        {'title': 'Your money', 'body': 'Top-ups and the card fee.'},
      ],
      'documents': [
        {
          'title': 'Terms of Use',
          'sections': [
            {'heading': '1. Your account', 'body': 'Keep your PIN secret.'},
          ],
        },
        {
          'title': 'Privacy Policy',
          'sections': [
            {'heading': '1. Who is responsible', 'body': 'The operator.'},
            {'heading': '2. Your rights', 'body': 'Access and correction.'},
          ],
        },
      ],
    };

    test('reads the version, the summary and the full documents', () {
      final terms = Terms.fromJson(json);
      expect(terms.version, '2026-10-01');
      expect(terms.summary.map((p) => p.title),
          ['What we collect', 'Your money']);
      expect(terms.summary.first.body, 'Your name and phone number.');
      expect(terms.documents.map((d) => d.title),
          ['Terms of Use', 'Privacy Policy']);
      expect(terms.documents.last.sections.last.heading, '2. Your rights');
    });

    test('a payload with no version is rejected, not shown as acceptable', () {
      expect(() => Terms.fromJson({'summary': [], 'documents': []}),
          throwsA(anything));
    });
  });

  group('signup', () {
    test('sends the accepted version with the new account details', () {
      final body = AuthService.registerBody(
        name: 'Sarah',
        phone: '256700111222',
        pin: '1234',
        termsVersion: '2026-10-01',
      );
      expect(body['terms_version'], '2026-10-01');
      expect(body['phone'], '256700111222');
    });
  });

  group('login', () {
    test('sends an acceptance only when the parent has just accepted', () {
      expect(AuthService.loginBody('256700111222', '1234'),
          {'phone': '256700111222', 'pin': '1234'});
      expect(
        AuthService.loginBody('256700111222', '1234',
            acceptTermsVersion: '2026-10-01'),
        {
          'phone': '256700111222',
          'pin': '1234',
          'accept_terms_version': '2026-10-01',
        },
      );
    });

    test('recognises "accept the terms first" from the backend', () {
      expect(
        AuthService.termsRequiredVersion(403, {
          'detail': 'Please read and accept the Nuvora terms.',
          'code': 'terms_required',
          'terms_version': '2026-11-15',
        }),
        '2026-11-15',
      );
    });

    test('a wrong PIN or a lockout is not a terms prompt', () {
      expect(
          AuthService.termsRequiredVersion(
              401, {'detail': 'Incorrect PIN. 4 attempt(s) remaining.'}),
          isNull);
      expect(
          AuthService.termsRequiredVersion(
              429, {'detail': 'Too many failed attempts.'}),
          isNull);
      expect(AuthService.termsRequiredVersion(403, {'detail': 'Nope'}), isNull);
      expect(AuthService.termsRequiredVersion(200, {'token': 'x'}), isNull);
    });
  });
}
