// The brand marks are bundled with the app and can be drawn. The design
// reference in docs/ is not an asset and must never be bundled.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_wallet/core/constants/brand_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('both marks are in the bundle and are SVG', () async {
    for (final path in BrandAssets.all) {
      final svg = await rootBundle.loadString(path);
      expect(svg, startsWith('<svg'), reason: path);
    }
  });

  test('nothing from docs/ is bundled, and no HTML', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets();
    expect(assets, containsAll(BrandAssets.all));
    expect(assets.where((a) => a.startsWith('docs/') || a.endsWith('.html')), isEmpty);
    expect(File('pubspec.yaml').readAsStringSync(), isNot(contains('docs/')));
  });

  testWidgets('both marks draw without error', (tester) async {
    for (final path in BrandAssets.all) {
      // Parsed here rather than through the asset loader, whose isolate
      // work does not finish inside a widget test.
      final svg = utf8.decode(File(path).readAsBytesSync());
      await tester.pumpWidget(MaterialApp(
        home: Center(child: SvgPicture.string(svg, height: 48)),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: path);
      expect(find.byType(SvgPicture), findsOneWidget);
    }
  });

  test('the brand row shows the mark, not a stand-in icon', () {
    // The Login and Home headers once used a wallet icon as the logo.
    for (final path in [
      'lib/features/auth/screens/login_screen.dart',
      'lib/features/dashboard/screens/dashboard_screen.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(src, contains('SvgPicture.asset(BrandAssets.mark'), reason: path);
    }
    final standIns = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains('Icons.account_balance_wallet'))
        .map((f) => f.path);
    expect(standIns, isEmpty);
  });
}
