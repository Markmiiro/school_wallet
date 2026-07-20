// Color palette from the Stitch design system.
// Warm Professional palette — deep indigo + heritage gold.
// Deliberately avoids green/blue to differentiate from typical fintech apps.
// Source: school_wallet_uganda_design_system/DESIGN.md

import 'package:flutter/material.dart';

class AppColors {
  AppColors._(); // prevent instantiation

  // Surfaces
  static const Color surface = Color(0xFFF8F9FF);
  static const Color surfaceDim = Color(0xFFD0DBED);
  static const Color surfaceBright = Color(0xFFF8F9FF);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFEFF4FF);
  static const Color surfaceContainer = Color(0xFFE6EEFF);
  static const Color surfaceContainerHigh = Color(0xFFDEE9FC);
  static const Color surfaceContainerHighest = Color(0xFFD9E3F6);

  static const Color onSurface = Color(0xFF121C2A);
  static const Color onSurfaceVariant = Color(0xFF474651);
  static const Color inverseSurface = Color(0xFF27313F);
  static const Color inverseOnSurface = Color(0xFFEAF1FF);

  static const Color outline = Color(0xFF777682);
  static const Color outlineVariant = Color(0xFFC8C5D3);
  static const Color surfaceTint = Color(0xFF5654A8);

  // Primary — Deep Indigo (headers, primary actions, brand)
  static const Color primary = Color(0xFF1A146B);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF312E81);
  static const Color onPrimaryContainer = Color(0xFF9C9AF4);
  static const Color inversePrimary = Color(0xFFC3C0FF);

  // Secondary — Heritage Gold (accents, secondary CTAs)
  static const Color secondary = Color(0xFF904D00);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFFE932C);
  static const Color onSecondaryContainer = Color(0xFF663500);

  // Tertiary
  static const Color tertiary = Color(0xFF150082);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFF2400C0);
  static const Color onTertiaryContainer = Color(0xFF9B99FF);

  // Functional — error uses high-contrast crimson (no green anywhere)
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  // Fixed variants (for elements that must stay consistent across light/dark)
  static const Color primaryFixed = Color(0xFFE2DFFF);
  static const Color primaryFixedDim = Color(0xFFC3C0FF);
  static const Color onPrimaryFixed = Color(0xFF100563);
  static const Color onPrimaryFixedVariant = Color(0xFF3E3C8F);

  static const Color secondaryFixed = Color(0xFFFFDCC3);
  static const Color secondaryFixedDim = Color(0xFFFFB77D);
  static const Color onSecondaryFixed = Color(0xFF2F1500);
  static const Color onSecondaryFixedVariant = Color(0xFF6E3900);

  static const Color tertiaryFixed = Color(0xFFE2DFFF);
  static const Color tertiaryFixedDim = Color(0xFFC3C0FF);
  static const Color onTertiaryFixed = Color(0xFF0F0069);
  static const Color onTertiaryFixedVariant = Color(0xFF3323CC);

  static const Color background = Color(0xFFF8F9FF);
  static const Color onBackground = Color(0xFF121C2A);
  static const Color surfaceVariant = Color(0xFFD9E3F6);

  // Elevation helpers (from DESIGN.md "Elevation & Depth" section)
  static const Color level1CardBorder = Color(0xFFE5E7EB);
  static BoxShadow level2Shadow = BoxShadow(
    color: const Color(0xFF1F1D51).withOpacity(0.08),
    offset: const Offset(0, 4),
    blurRadius: 12,
  );
}

