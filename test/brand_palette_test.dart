// The palette against the brand book. These fail the build; they do not
// warn. A changed value, a text colour that drops under its limit, a
// forbidden pairing or a colour written outside the token file all stop
// here.
//
// Ratios are WCAG 2 contrast ratios. 4.5 is the floor for normal text,
// 3.0 for large text and for fills that only carry large text.

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_wallet/core/constants/app_colors.dart';
import 'package:school_wallet/core/theme/app_theme.dart';

double _channel(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

const _white = NuvoraPalette.white;

void main() {
  group('the values are the brand book\'s', () {
    test('three brand colours', () {
      expect(_hex(NuvoraPalette.navy), '#102B5C');
      expect(_hex(NuvoraPalette.blue), '#168FF5');
      expect(_hex(NuvoraPalette.teal), '#12C8B0');
    });

    test('the text shades of blue and teal', () {
      expect(_hex(NuvoraPalette.blueText), '#1061AB');
      expect(_hex(NuvoraPalette.tealText), '#0D857C');
    });

    test('neutrals', () {
      expect(_hex(NuvoraPalette.surfaceSunken), '#F4F7FA');
      expect(_hex(NuvoraPalette.border), '#E6ECF3');
      expect(_hex(NuvoraPalette.ink), '#172033');
      expect(_hex(NuvoraPalette.inkMuted), '#64748B');
    });

    test('the web shell uses the same navy', () {
      expect(File('web/index.html').readAsStringSync(), contains('#102B5C'));
      expect(File('web/manifest.json').readAsStringSync(), contains('#102B5C'));
      for (final f in ['web/index.html', 'web/manifest.json']) {
        expect(File(f).readAsStringSync().toUpperCase(), isNot(contains('#0D2551')),
            reason: '$f still has the old navy');
      }
    });
  });

  group('the measurements in the book hold', () {
    void close(Color fg, Color bg, double expected) =>
        expect(contrast(fg, bg), closeTo(expected, 0.01));

    test('blue on white is 3.34, teal on white 2.12', () {
      close(NuvoraPalette.blue, _white, 3.34);
      close(NuvoraPalette.teal, _white, 2.12);
    });

    test('navy on blue is 4.13: large text only', () {
      close(NuvoraPalette.navy, NuvoraPalette.blue, 4.13);
    });
  });

  group('roles', () {
    testWidgets('blue is the accent: primary button, active tab, balance card', (tester) async {
      expect(AppColors.accent, NuvoraPalette.blue);
      expect(AppColors.navBarIndicator, NuvoraPalette.blue);
      expect(AppColors.balanceCard, NuvoraPalette.blue);
      final button = AppTheme.lightTheme.elevatedButtonTheme.style!;
      expect(button.backgroundColor!.resolve({}), NuvoraPalette.blue);
    });

    testWidgets('teal is the signal, and only the Top up button style fills with it', (tester) async {
      expect(AppColors.signal, NuvoraPalette.teal);
      expect(AppTheme.signalButton.backgroundColor!.resolve({}), NuvoraPalette.teal);
      final scheme = AppTheme.lightTheme.colorScheme;
      expect(scheme.primary, isNot(NuvoraPalette.teal));
      expect(scheme.secondary, isNot(NuvoraPalette.teal));
      expect(scheme.secondaryContainer, isNot(NuvoraPalette.teal));
    });

    testWidgets('navy is the ground: nav bar and headers', (tester) async {
      expect(AppColors.navBar, NuvoraPalette.navy);
      expect(AppTheme.lightTheme.appBarTheme.backgroundColor, NuvoraPalette.navy);
    });
  });

  group('text is readable', () {
    // Everything here is used at body size somewhere: 4.5 or better.
    final body = <String, (Color, Color)>{
      'ink on white': (AppColors.onSurface, _white),
      'ink on the page ground': (AppColors.onSurface, AppColors.surface),
      'muted ink on white': (AppColors.onSurfaceVariant, _white),
      'navy on white': (AppColors.primary, _white),
      'navy on the page ground': (AppColors.primary, AppColors.surface),
      'white on navy': (AppColors.onPrimary, AppColors.primary),
      'muted white on navy': (
        Color.alphaBlend(AppColors.onPrimaryContainerMuted, AppColors.primaryContainer),
        AppColors.primaryContainer
      ),
      'blue text on white': (AppColors.accentText, _white),
      'blue text on the page ground': (AppColors.accentText, AppColors.surface),
      'teal text on white': (AppColors.signalText, _white),
      'the tick colour on white': (AppColors.success, _white),
      'navy on teal (the Top up label)': (AppColors.onSignal, AppColors.signal),
      'error red on white': (AppColors.error, _white),
      'error red on the page ground': (AppColors.error, AppColors.surface),
      'white on error red': (AppColors.onError, AppColors.error),
      'nav bar active label': (AppColors.navBarActiveLabel, AppColors.navBar),
      'nav bar inactive label': (
        Color.alphaBlend(AppColors.navBarInactive, AppColors.navBar),
        AppColors.navBar
      ),
    };

    body.forEach((name, pair) {
      test('$name is 4.5:1 or better', () {
        final ratio = contrast(pair.$1, pair.$2);
        expect(ratio, greaterThanOrEqualTo(4.5),
            reason: '$name is ${ratio.toStringAsFixed(2)}:1 '
                '(${_hex(pair.$1)} on ${_hex(pair.$2)})');
      });
    });

    // The book's own "large only" pairs: allowed, but never under 3.0,
    // and only where the type is made large and heavy enough.
    testWidgets('navy on blue clears large text and the label is 17px/700 or more', (tester) async {
      expect(contrast(AppColors.onAccent, AppColors.accent), greaterThanOrEqualTo(3.0));
      expect(AppColors.onAccent, NuvoraPalette.navy, reason: 'prefer navy on blue');
      expect(AppColors.onBalanceCard, NuvoraPalette.navy);
      expect(AppColors.navBarActiveIcon, NuvoraPalette.navy);

      final style = AppTheme.lightTheme.elevatedButtonTheme.style!;
      final label = style.textStyle!.resolve({})!;
      expect(style.foregroundColor!.resolve({}), NuvoraPalette.navy);
      expect(label.fontSize, greaterThanOrEqualTo(17));
      expect(label.fontWeight!.value, greaterThanOrEqualTo(700));
    });

    // Under 4.5 with the book's own values. Held at what they measure
    // today so they cannot get worse unnoticed; the fix is the designer's
    // (docs/design/designer-questions.md).
    test('known shortfalls have not got worse', () {
      expect(contrast(AppColors.onSurfaceVariant, AppColors.surface),
          greaterThanOrEqualTo(4.4),
          reason: 'muted ink on the page ground');
      expect(contrast(AppColors.signalText, AppColors.surface),
          greaterThanOrEqualTo(4.15),
          reason: 'teal text on the page ground');
    });
  });

  group('never', () {
    testWidgets('white on teal, at any size', (tester) async {
      expect(AppColors.onSignal, isNot(_white));
      expect(AppTheme.signalButton.foregroundColor!.resolve({}), NuvoraPalette.navy);
      expect(AppTheme.lightTheme.colorScheme.onTertiaryContainer, NuvoraPalette.navy);
    });

    test('teal or blue fills used as text colours', () {
      expect(AppColors.signalText, isNot(NuvoraPalette.teal));
      expect(AppColors.accentText, isNot(NuvoraPalette.blue));
      expect(AppColors.success, isNot(NuvoraPalette.teal));
      expect(AppColors.moneyIn, isNot(NuvoraPalette.teal));
      expect(AppColors.cleared, isNot(NuvoraPalette.teal));
    });

    testWidgets('white as a label on blue', (tester) async {
      expect(AppColors.onAccent, isNot(_white));
      expect(AppColors.onBalanceCard, isNot(_white));
      expect(AppTheme.lightTheme.colorScheme.onSecondaryContainer, isNot(_white));
    });
  });

  group('the source', () {
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    test('writes colour values only in the token file', () {
      final literal = RegExp(r'Color\(0x|Color\.fromARGB|Color\.fromRGBO');
      for (final f in dartFiles) {
        if (f.path.endsWith('app_colors.dart')) continue;
        expect(literal.hasMatch(f.readAsStringSync()), isFalse,
            reason: '${f.path} writes a colour literal');
      }
    });

    test('reaches the raw palette only from the token file', () {
      for (final f in dartFiles) {
        if (f.path.endsWith('app_colors.dart')) continue;
        expect(f.readAsStringSync(), isNot(contains('NuvoraPalette.')),
            reason: '${f.path} bypasses AppColors');
      }
    });

    test('never samples the gradients inside the mark', () {
      final svg = File('assets/brand/nuvora-mark.svg').readAsStringSync();
      final inMark = RegExp(r'stop-color="#([0-9a-fA-F]{6})"')
          .allMatches(svg)
          .map((m) => m.group(1)!.toUpperCase())
          .toSet();
      expect(inMark, isNotEmpty);
      for (final f in dartFiles) {
        final text = f.readAsStringSync().toUpperCase();
        for (final value in inMark) {
          expect(text, isNot(contains(value)),
              reason: '${f.path} uses #$value from the mark\'s gradient');
        }
      }
    });

    test('fills with teal only for Top up', () {
      // AppColors.signal (the fill) may appear in the theme's Top up
      // style and nowhere in a screen.
      for (final f in dartFiles) {
        if (f.path.endsWith('app_colors.dart') || f.path.endsWith('app_theme.dart')) {
          continue;
        }
        expect(RegExp(r'AppColors\.signal\b').hasMatch(f.readAsStringSync()), isFalse,
            reason: '${f.path} fills with teal directly; use AppTheme.signalButton');
      }
      final users = [
        for (final f in dartFiles)
          if (f.readAsStringSync().contains('AppTheme.signalButton') &&
              !f.path.endsWith('app_theme.dart'))
            f.path.split('/').last,
      ]..sort();
      expect(users, ['child_wallet_detail_screen.dart', 'dashboard_screen.dart']);
    });
  });
}
