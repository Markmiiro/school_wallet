// Nuvora colour tokens — the ONE place colour values are defined.
//
// NuvoraPalette holds the raw brand values. AppColors maps them onto the
// roles the screens and AppTheme use. Screens reference AppColors only;
// nothing outside this file should write a Color(0x...) literal.
//
// The same navy-900 value is repeated as a literal in web/index.html
// (theme-color) and web/manifest.json (theme_color, background_color),
// because those files cannot reference Dart. Change it there too.
//
// Contrast rules (WCAG ratios, measured):
//   teal400 on white    2.12  FAILS as text — use it only as a fill
//   teal400 on navy700  6.38  fine for text and icons on navy
//   navy900 on teal400  7.08  the pairing for a teal button
//   teal700 on white    5.23  teal-coloured text on light backgrounds
//   white   on navy700 13.52

import 'package:flutter/material.dart';


class NuvoraPalette {
  NuvoraPalette._();

  // Brand
  static const Color navy900 = Color(0xFF0D2551); // deepest ground, headers, status bar
  static const Color navy700 = Color(0xFF142D5A); // primary surface, balance card
  static const Color navy500 = Color(0xFF1D3A6B); // raised surface, borders on navy
  static const Color teal400 = Color(0xFF10C8B0); // accent: CTAs, active nav, highlights
  static const Color teal700 = Color(0xFF0B7A6D); // accent as TEXT on light backgrounds
  static const Color ink = Color(0xFF0F1B2E); // body text on light
  static const Color slate = Color(0xFF5A6B85); // secondary text
  static const Color mist = Color(0xFFEEF2F6); // light page ground
  static const Color white = Color(0xFFFFFFFF);

  // Derived from the brand values above, not separate brand colours.
  static const Color white70 = Color(0xB3FFFFFF); // muted text on navy
  static const Color line = Color(0xFFDEE1E7); // slate at 20% over white: hairlines on light

  // Destructive only (Log Out, errors). Not part of the brand.
  static const Color red = Color(0xFFBA1A1A);
  static const Color redTint = Color(0xFFFFDAD6);
  static const Color redDeep = Color(0xFF93000A);

  // Physical card colours offered on Buy a Card. These are product
  // colours fixed by the approved USSD spec (Blue, Green, Yellow, Red),
  // not UI theme colours, so they are deliberately outside the brand.
  static const Color cardBlue = Color(0xFF185FA5);
  static const Color cardGreen = Color(0xFF0F6E56);
  static const Color cardYellow = Color(0xFFBA7517);
  static const Color cardRed = Color(0xFFA32D2D);
}

class AppColors {
  AppColors._(); // prevent instantiation

  // Surfaces
  static const Color background = NuvoraPalette.mist;
  static const Color surface = NuvoraPalette.mist;
  static const Color surfaceContainerLowest = NuvoraPalette.white; // cards, inputs
  static const Color surfaceContainer = NuvoraPalette.white;
  static const Color surfaceContainerHighest = NuvoraPalette.line;

  static const Color onSurface = NuvoraPalette.ink;
  static const Color onSurfaceVariant = NuvoraPalette.slate;
  static const Color inverseSurface = NuvoraPalette.navy900;
  static const Color inverseOnSurface = NuvoraPalette.white;

  static const Color outline = NuvoraPalette.slate;
  static const Color outlineVariant = NuvoraPalette.line;

  // Primary — navy. Headers, icons and text on light, outlined buttons.
  static const Color primary = NuvoraPalette.navy900;
  static const Color onPrimary = NuvoraPalette.white;
  // The navy surface: balance card, hero cards.
  static const Color primaryContainer = NuvoraPalette.navy700;
  static const Color onPrimaryContainer = NuvoraPalette.white;
  static const Color onPrimaryContainerMuted = NuvoraPalette.white70;
  static const Color inversePrimary = NuvoraPalette.teal400;

  // Secondary — teal. `secondary` is the text-safe teal for light
  // backgrounds; `secondaryContainer` is the teal FILL and must only ever
  // carry `onSecondaryContainer` (navy) on top, never white.
  static const Color secondary = NuvoraPalette.teal700;
  static const Color onSecondary = NuvoraPalette.white;
  static const Color secondaryContainer = NuvoraPalette.teal400;
  static const Color onSecondaryContainer = NuvoraPalette.navy900;

  // Tertiary — raised navy.
  static const Color tertiary = NuvoraPalette.navy500;
  static const Color onTertiary = NuvoraPalette.white;
  static const Color tertiaryContainer = NuvoraPalette.navy500;
  static const Color onTertiaryContainer = NuvoraPalette.white;

  // Functional — red is reserved for destructive actions and errors.
  static const Color error = NuvoraPalette.red;
  static const Color onError = NuvoraPalette.white;
  static const Color errorContainer = NuvoraPalette.redTint;
  static const Color onErrorContainer = NuvoraPalette.redDeep;

  static const Color success = NuvoraPalette.teal700;

  // Money direction in transaction lists and totals.
  static const Color moneyIn = NuvoraPalette.teal700;
  static const Color moneyOut = NuvoraPalette.ink;

  // Bottom navigation (sits on navy).
  static const Color navBar = NuvoraPalette.navy900;
  static const Color navBarIndicator = NuvoraPalette.navy500;
  static const Color navBarActive = NuvoraPalette.teal400;
  static const Color navBarInactive = NuvoraPalette.white70;

  // Buy a Card preview.
  static const Color cardBlue = NuvoraPalette.cardBlue;
  static const Color cardGreen = NuvoraPalette.cardGreen;
  static const Color cardYellow = NuvoraPalette.cardYellow;
  static const Color cardRed = NuvoraPalette.cardRed;
  static const Color onCardFace = NuvoraPalette.white;
  static const Color cardChip = NuvoraPalette.mist;

  // Elevation helpers
  static const Color level1CardBorder = NuvoraPalette.line;
  static BoxShadow level2Shadow = BoxShadow(
    color: NuvoraPalette.navy900.withOpacity(0.08),
    offset: const Offset(0, 4),
    blurRadius: 12,
  );
}
