// The Nuvora mark, bundled as SVG and drawn with flutter_svg:
//   SvgPicture.asset(BrandAssets.mark, height: 32)
// Declared under flutter: assets: in pubspec.yaml.

class BrandAssets {
  BrandAssets._();

  /// For light grounds: the stem is navy.
  static const String mark = 'assets/brand/nuvora-mark.svg';

  /// For navy grounds: the stem is white.
  static const String markReversed = 'assets/brand/nuvora-mark-reversed.svg';

  static const List<String> all = [mark, markReversed];
}
