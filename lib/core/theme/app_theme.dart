// ThemeData and text styles from the Stitch design system.
// Fonts: Manrope (headlines/currency), Inter (body), JetBrains Mono (PINs/account numbers).
// Uses google_fonts package.
//
// Source: school_wallet_uganda_design_system/DESIGN.md

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppTheme {
  AppTheme._();

  // ── Text Styles ──────────────────────────────────────────
  // display-currency: for wallet balances — biggest, boldest, tightest tracking
  static TextStyle get displayCurrency => GoogleFonts.manrope(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        height: 44 / 36,
        letterSpacing: -0.02 * 36, // -0.02em
        color: AppColors.onSurface,
      );

  static TextStyle get headlineLg => GoogleFonts.manrope(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 36 / 28,
        color: AppColors.onSurface,
      );

  static TextStyle get headlineLgMobile => GoogleFonts.manrope(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 32 / 24,
        color: AppColors.onSurface,
      );

  static TextStyle get headlineMd => GoogleFonts.manrope(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 28 / 20,
        color: AppColors.onSurface,
      );

  static TextStyle get bodyLg => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        height: 26 / 18,
        color: AppColors.onSurface,
      );

  static TextStyle get bodyMd => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        color: AppColors.onSurface,
      );

  static TextStyle get bodySm => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: AppColors.onSurfaceVariant,
      );

  // label-mono: account numbers, transaction IDs, PIN entries
  static TextStyle get labelMono => GoogleFonts.jetBrainsMono(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 20 / 14,
        letterSpacing: 0.05 * 14, // 0.05em
        color: AppColors.onSurface,
      );

  // ── Spacing (4px base unit) ──────────────────────────────
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;
  static const double gutter = 16;
  static const double marginMobile = 20;
  static const double marginTablet = 40;

  // ── Shape radii ───────────────────────────────────────────
  static const double radiusSm = 4;    // checkboxes
  static const double radiusDefault = 8;  // buttons, inputs
  static const double radiusMd = 12;
  static const double radiusLg = 16;   // cards, modals
  static const double radiusXl = 24;
  static const double radiusFull = 9999;

  // Minimum touch target — "Safety First" principle from DESIGN.md
  static const double minTouchTarget = 48;

  // ── ThemeData ─────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        tertiary: AppColors.tertiary,
        onTertiary: AppColors.onTertiary,
        tertiaryContainer: AppColors.tertiaryContainer,
        onTertiaryContainer: AppColors.onTertiaryContainer,
        error: AppColors.error,
        onError: AppColors.onError,
        errorContainer: AppColors.errorContainer,
        onErrorContainer: AppColors.onErrorContainer,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        surfaceContainerHighest: AppColors.surfaceContainerHighest,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
        inverseSurface: AppColors.inverseSurface,
        onInverseSurface: AppColors.inverseOnSurface,
        inversePrimary: AppColors.inversePrimary,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: headlineMd,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size.fromHeight(minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusDefault),
          ),
          textStyle: bodyMd.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1),
          minimumSize: const Size.fromHeight(minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusDefault),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLowest,
        labelStyle: bodySm.copyWith(fontWeight: FontWeight.w600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          borderSide: const BorderSide(color: AppColors.outline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          borderSide: const BorderSide(color: AppColors.outline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: AppColors.level1CardBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      textTheme: TextTheme(
        displayLarge: displayCurrency,
        headlineLarge: headlineLg,
        headlineMedium: headlineMd,
        bodyLarge: bodyLg,
        bodyMedium: bodyMd,
        bodySmall: bodySm,
        labelMedium: labelMono,
      ),
    );
  }
}