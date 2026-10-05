// The app icon and the launch splash, against the launch spec
// (docs/design/nuvora-app-launch.html, local only).
//
// Icon: navy ground with the reversed mark, never the full-colour file.
// The PNGs are made from assets/brand/nuvora-mark-reversed.svg by
// tool/make_icons.py; these tests read the files back pixel by pixel.
//
// Splash: the mark alone on navy, inline in web/index.html so it shows
// before Flutter loads. It fades in and settles from 1.18 to 1, holds to
// 1000 ms, then fades out over 240 ms once Flutter has drawn its first
// frame. Under reduced motion it holds still for 400 ms.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

/// A decoded 8-bit RGBA or RGB, non-interlaced PNG.
class _Png {
  _Png(this.width, this.height, this.channels, this.pixels);
  final int width, height, channels;
  final Uint8List pixels;

  List<int> at(int x, int y) {
    final i = (y * width + x) * channels;
    return [
      pixels[i], pixels[i + 1], pixels[i + 2],
      channels == 4 ? pixels[i + 3] : 255,
    ];
  }

  static _Png read(String path) {
    final b = File(path).readAsBytesSync();
    final d = ByteData.sublistView(b);
    expect(b.sublist(1, 4), utf8.encode('PNG'), reason: '$path is not a PNG');
    var pos = 8, width = 0, height = 0, channels = 0;
    final idat = BytesBuilder();
    while (pos < b.length) {
      final len = d.getUint32(pos);
      final type = ascii.decode(b.sublist(pos + 4, pos + 8));
      final data = b.sublist(pos + 8, pos + 8 + len);
      if (type == 'IHDR') {
        final h = ByteData.sublistView(data);
        width = h.getUint32(0);
        height = h.getUint32(4);
        expect(data[8], 8, reason: '$path: 8-bit only');
        expect(data[12], 0, reason: '$path: interlaced');
        channels = {6: 4, 2: 3}[data[9]] ??
            (throw StateError('$path: colour type ${data[9]}'));
      } else if (type == 'IDAT') {
        idat.add(data);
      }
      pos += 12 + len;
    }
    final raw = ZLibCodec().decode(idat.toBytes());
    final stride = width * channels;
    final out = Uint8List(height * stride);
    for (var y = 0; y < height; y++) {
      final f = raw[y * (stride + 1)];
      for (var x = 0; x < stride; x++) {
        final v = raw[y * (stride + 1) + 1 + x];
        final a = x >= channels ? out[y * stride + x - channels] : 0;
        final up = y > 0 ? out[(y - 1) * stride + x] : 0;
        final c = x >= channels && y > 0 ? out[(y - 1) * stride + x - channels] : 0;
        int pred;
        switch (f) {
          case 0: pred = 0;
          case 1: pred = a;
          case 2: pred = up;
          case 3: pred = (a + up) >> 1;
          case 4:
            final p = a + up - c;
            final pa = (p - a).abs(), pb = (p - up).abs(), pc = (p - c).abs();
            pred = pa <= pb && pa <= pc ? a : (pb <= pc ? up : c);
          default: throw StateError('$path: filter $f');
        }
        out[y * stride + x] = (v + pred) & 0xFF;
      }
    }
    return _Png(width, height, channels, out);
  }
}

bool _navy(List<int> p) =>
    (p[0] - 0x10).abs() <= 3 && (p[1] - 0x2B).abs() <= 3 &&
    (p[2] - 0x5C).abs() <= 3 && p[3] == 255;
bool _white(List<int> p) => p[0] > 245 && p[1] > 245 && p[2] > 245;
bool _teal(List<int> p) => p[0] < 40 && p[1] > 170 && p[2] > 140 && p[2] < 200;
bool _blue(List<int> p) => p[0] < 40 && p[1] > 110 && p[1] < 160 && p[2] > 200;

/// Every icon the web shell points at, with its size and whether it is
/// full-bleed (maskable, or Apple's, which iOS rounds itself).
const _icons = {
  'web/favicon.png': (32, false),
  'web/icons/Icon-192.png': (192, false),
  'web/icons/Icon-512.png': (512, false),
  'web/icons/Icon-maskable-192.png': (192, true),
  'web/icons/Icon-maskable-512.png': (512, true),
  'web/icons/apple-touch-icon.png': (180, true),
};

void main() {
  group('the app icon', () {
    test('the manifest and index.html point at files of the stated size', () {
      final manifest = jsonDecode(File('web/manifest.json').readAsStringSync());
      for (final icon in manifest['icons'] as List) {
        final png = _Png.read('web/${icon['src']}');
        expect('${png.width}x${png.height}', icon['sizes'], reason: icon['src']);
      }
      final html = File('web/index.html').readAsStringSync();
      expect(html, contains('href="icons/apple-touch-icon.png"'));
      expect(html, contains('href="favicon.png"'));
    });

    for (final MapEntry(key: path, value: (size, fullBleed)) in _icons.entries) {
      test('$path: navy ground with the reversed mark', () {
        final png = _Png.read(path);
        expect(png.width, size);
        expect(png.height, size);

        final corner = png.at(0, 0);
        if (fullBleed) {
          expect(_navy(corner), isTrue, reason: 'corner $corner should be navy');
        } else {
          expect(corner[3], 0, reason: 'rounded tile: the corner is clear');
          expect(_navy(png.at(size ~/ 2, size ~/ 12)), isTrue,
              reason: 'the tile is navy inside the corner radius');
        }

        // The reversed file: a white stem, the blue diagonal and the teal
        // leaf, and never the navy stem of the full-colour file.
        var white = 0, blue = 0, teal = 0;
        for (var y = 0; y < size; y++) {
          for (var x = 0; x < size; x++) {
            final p = png.at(x, y);
            if (_white(p)) white++;
            if (_blue(p)) blue++;
            if (_teal(p)) teal++;
          }
        }
        expect(white, greaterThan(0), reason: 'no white stem');
        expect(blue, greaterThan(0), reason: 'no blue diagonal');
        expect(teal, greaterThan(0), reason: 'no teal leaf');
      });
    }

    test('maskable icons keep the mark inside the 80% safe circle', () {
      for (final path in ['web/icons/Icon-maskable-192.png', 'web/icons/Icon-maskable-512.png']) {
        final png = _Png.read(path);
        final r = png.width * 0.4, cx = png.width / 2, cy = png.height / 2;
        for (var y = 0; y < png.height; y++) {
          for (var x = 0; x < png.width; x++) {
            final dx = x + 0.5 - cx, dy = y + 0.5 - cy;
            if (dx * dx + dy * dy > r * r) {
              expect(_navy(png.at(x, y)), isTrue,
                  reason: '$path: mark reaches ($x, $y), outside the safe circle');
            }
          }
        }
      }
    });
  });

  group('the launch splash', () {
    final html = File('web/index.html').readAsStringSync();
    final splash = RegExp(r'<div id="nv-splash"[\s\S]*?</div>').firstMatch(html)?[0] ?? '';

    test('is in index.html, ahead of Flutter, on navy', () {
      expect(splash, isNotEmpty);
      expect(html.indexOf('id="nv-splash"'), lessThan(html.indexOf('flutter_bootstrap.js')));
      expect(html, contains('#nv-splash'));
      expect(RegExp(r'#nv-splash\s*\{[^}]*background:\s*#102B5C').hasMatch(html), isTrue);
    });

    test('draws the reversed mark, path for path', () {
      final svg = File('assets/brand/nuvora-mark-reversed.svg').readAsStringSync();
      final paths = RegExp(r' d="([^"]+)"').allMatches(svg).map((m) => m[1]!).toList();
      expect(paths, hasLength(3));
      for (final d in paths) {
        expect(splash, contains(d));
      }
      expect(splash, contains('fill="#ffffff"'));
      expect(splash.toLowerCase(), isNot(contains('#102b5c')),
          reason: 'navy stem is the full-colour file, misuse on navy');
    });

    test('the mark stands alone: no retyped wordmark, no tagline beside it', () {
      expect(splash, isNot(contains('<text')));
      expect(html, isNot(contains('Pocket money parents can see')));
    });

    test('the timings and easing of the spec', () {
      expect(html, contains('cubic-bezier(.22,1,.36,1)'));
      expect(RegExp(r'nv-mark-fade\s+180ms').hasMatch(html), isTrue);
      expect(RegExp(r'nv-mark-settle\s+340ms').hasMatch(html), isTrue);
      expect(html, contains('scale(1.18)'));
      expect(RegExp(r'opacity\s+240ms').hasMatch(html), isTrue);
      expect(html, contains('reduce ? 400 : 1000'));
    });

    test('waits for Flutter\'s first frame, and holds still under reduced motion', () {
      expect(html, contains("'flutter-first-frame'"));
      expect(RegExp(r'@media \(prefers-reduced-motion: ?reduce\)\s*\{[^@]*animation:\s*none')
          .hasMatch(html), isTrue);
    });
  });
}
