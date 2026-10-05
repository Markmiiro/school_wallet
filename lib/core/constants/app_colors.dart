// Nuvora colour tokens — the ONE place colour values are defined.
//
// NuvoraPalette holds the raw values from the brand book. AppColors maps
// them onto the roles the screens and AppTheme use. Screens reference
// AppColors only; nothing outside this file should write a Color(0x...)
// literal. test/brand_palette_test.dart fails if any of this drifts.
//
// The navy value is repeated as a literal in web/index.html (theme-color)
// and web/manifest.json (theme_color, background_color), because those
// files cannot reference Dart. Change it there too.
//
// ROLES (brand book)
//   navy   trust, ground: the nav bar, headers, icons and text on light.
//   blue   the accent: fills the primary button, the active tab and the
//          balance card.
//   teal   a signal, not an accent: "marks the thing that worked, nothing
//          else". Once on a typical screen: the Top up button, or the
//          mark on a cleared transaction. Two teal fills on one screen
//          means one is wrong.
//   Rough share of a screen: 60 neutral / 25 navy / 10 blue / 5 teal.
//
// CONTRAST (WCAG ratios, measured; the test holds these)
//   blue  on white   3.34  not body text. A fill, or a 24px+ heading.
//                          Blue as sentence text is blueText (6.33).
//   teal  on white   2.12  never text on light. Teal type is tealText (4.50).
//   white on teal    2.12  never, at any size.
//   white on blue    3.34  large text only; navy on blue (4.13) is preferred
//                          and is what every label on blue uses. It is
//                          still "large only": primary button labels are
//                          navy, weight 700, 17px or more.
//   navy  on teal    6.51  the label on a teal button.
//   white on navy   13.80
//
// The gradients inside assets/brand/*.svg belong to the mark. The book
// says not to sample them for UI; none of their values appear here.

import 'package:flutter/material.dart';


class NuvoraPalette {
  NuvoraPalette._();

  // The three brand colours.
  static const Color navy = Color(0xFF102B5C); // trust, ground
  static const Color blue = Color(0xFF168FF5); // accent
  static const Color teal = Color(0xFF12C8B0); // signal

  // The same blue and teal, darkened by the book for use as TEXT on light.
  static const Color blueText = Color(0xFF1061AB);
  static const Color tealText = Color(0xFF0D857C);

  // Neutrals.
  static const Color surfaceSunken = Color(0xFFF4F7FA); // page ground
  static const Color border = Color(0xFFE6ECF3); // hairlines, quiet fills
  static const Color ink = Color(0xFF172033); // body text on light
  static const Color inkMuted = Color(0xFF64748B); // secondary text
  static const Color white = Color(0xFFFFFFFF);

  // Derived, not a separate brand colour.
  static const Color white70 = Color(0xB3FFFFFF); // muted text on navy

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
  static const Color background = NuvoraPalette.surfaceSunken;
  static const Color surface = NuvoraPalette.surfaceSunken;
  static const Color surfaceContainerLowest = NuvoraPalette.white; // cards, inputs
  static const Color surfaceContainer = NuvoraPalette.white;
  static const Color surfaceContainerHighest = NuvoraPalette.border;

  static const Color onSurface = NuvoraPalette.ink;
  static const Color onSurfaceVariant = NuvoraPalette.inkMuted;
  static const Color inverseSurface = NuvoraPalette.navy;
  static const Color inverseOnSurface = NuvoraPalette.white;

  static const Color outline = NuvoraPalette.inkMuted;
  static const Color outlineVariant = NuvoraPalette.border;

  // Navy — the ground. Headers, the nav bar, the lock screen, icons and
  // text on light, outlined buttons. One navy: the book has no second.
  static const Color primary = NuvoraPalette.navy;
  static const Color onPrimary = NuvoraPalette.white;
  static const Color primaryContainer = NuvoraPalette.navy;
  static const Color onPrimaryContainer = NuvoraPalette.white;
  static const Color onPrimaryContainerMuted = NuvoraPalette.white70;

  // Blue — the accent. `accent` is a FILL (primary button, active tab,
  // selected chip, the focus ring on navy) and carries `onAccent` (navy),
  // never white at label size. `accentText` is blue for sentence text.
  static const Color accent = NuvoraPalette.blue;
  static const Color onAccent = NuvoraPalette.navy;
  static const Color accentText = NuvoraPalette.blueText;

  // The balance card is blue; everything written on it is navy.
  static const Color balanceCard = NuvoraPalette.blue;
  static const Color onBalanceCard = NuvoraPalette.navy;

  // Teal — the signal. `signal` is a FILL and carries `onSignal` (navy),
  // never white. `signalText` is teal for type and for marks on white.
  // Use it for the thing that worked and for the Top up button only.
  static const Color signal = NuvoraPalette.teal;
  static const Color onSignal = NuvoraPalette.navy;
  static const Color signalText = NuvoraPalette.tealText;

  // Functional — red is reserved for destructive actions and errors.
  static const Color error = NuvoraPalette.red;
  static const Color onError = NuvoraPalette.white;
  static const Color errorContainer = NuvoraPalette.redTint;
  static const Color onErrorContainer = NuvoraPalette.redDeep;

  // "It worked": the tick after a payment, an active card.
  static const Color success = NuvoraPalette.tealText;

  // Amounts in transaction lists and totals are ink either way; the sign
  // says the direction. A top-up that went through carries the one teal
  // mark on its row (`cleared`), not a teal amount as well.
  static const Color moneyIn = NuvoraPalette.ink;
  static const Color moneyOut = NuvoraPalette.ink;
  static const Color cleared = NuvoraPalette.tealText;

  // Bottom navigation (sits on navy). The active tab is a blue pill with
  // a navy icon; its label, below the pill on the bar, is white.
  static const Color navBar = NuvoraPalette.navy;
  static const Color navBarIndicator = NuvoraPalette.blue;
  static const Color navBarActiveIcon = NuvoraPalette.navy;
  static const Color navBarActiveLabel = NuvoraPalette.white;
  static const Color navBarInactive = NuvoraPalette.white70;

  // Buy a Card preview.
  static const Color cardBlue = NuvoraPalette.cardBlue;
  static const Color cardGreen = NuvoraPalette.cardGreen;
  static const Color cardYellow = NuvoraPalette.cardYellow;
  static const Color cardRed = NuvoraPalette.cardRed;
  static const Color onCardFace = NuvoraPalette.white;
  static const Color cardChip = NuvoraPalette.surfaceSunken;

  // Elevation helpers
  static const Color level1CardBorder = NuvoraPalette.border;
  static BoxShadow level2Shadow = BoxShadow(
    color: NuvoraPalette.navy.withOpacity(0.08),
    offset: const Offset(0, 4),
    blurRadius: 12,
  );
}
