import 'package:flutter/material.dart';

/// Palette ported 1:1 from bench_tracker.py so the Flutter app and the Python
/// app are visually the same product.
abstract final class AppColors {
  static const bgBase = Color(0xFFFFFFFF); // window background
  static const bgSurface = Color(0xFFF9FAFB); // page background
  static const card = Color(0xFFF3F4F6); // card fill
  static const border = Color(0xFFE5E7EB); // hairline borders

  static const accent = Color(0xFF0D9488); // teal — primary, heavy day
  static const accentDim = Color(0xFF0F766E);
  static const accentTint = Color(0xFFCCFBF1);

  static const success = Color(0xFF10B981); // green — completed, volume day
  static const successDim = Color(0xFF059669);
  static const successTint = Color(0xFFD1FAE5);

  static const danger = Color(0xFFEF4444); // red — failed sets
  static const dangerTint = Color(0xFFFEE2E2);

  static const warning = Color(0xFFF59E0B); // amber — deload, plateau
  static const warningTint = Color(0xFFFEF3C7);

  // Macro accents. Amber is deliberately NOT reused here: a ring turns amber
  // when it goes over target, so an always-amber macro could not signal that.
  static const carbs = Color(0xFF3B82F6); // blue
  static const fats = Color(0xFF8B5CF6); // violet

  static const onAccent = Color(0xFFFFFFFF);

  static const textHi = Color(0xFF111827); // charcoal — headings
  static const textMid = Color(0xFF4B5563); // medium gray — body
  static const textLow = Color(0xFF9CA3AF); // light gray — captions

  /// Deliberately louder than the app chrome.
  static const confetti = <Color>[
    Color(0xFF0D9488), Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFEF4444),
    Color(0xFF3B82F6), Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFF14B8A6),
  ];
}

abstract final class AppRadii {
  static const card = 16.0;
  static const control = 12.0;
}

/// A single light theme. The spec calls for a strict premium light look, so no
/// dark variant is offered — a half-built dark mode is worse than none.
ThemeData buildTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.accent,
    onPrimary: AppColors.onAccent,
    secondary: AppColors.success,
    onSecondary: AppColors.onAccent,
    error: AppColors.danger,
    onError: AppColors.onAccent,
    surface: AppColors.bgBase,
    onSurface: AppColors.textHi,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bgSurface,
    fontFamily: 'Segoe UI',
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bgBase,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.textHi,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bgBase,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.6),
      ),
      labelStyle: const TextStyle(color: AppColors.textMid),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
          color: AppColors.textHi, fontWeight: FontWeight.w700, fontSize: 22),
      titleMedium: TextStyle(
          color: AppColors.textHi, fontWeight: FontWeight.w600, fontSize: 16),
      bodyMedium: TextStyle(color: AppColors.textMid, fontSize: 14),
      labelSmall: TextStyle(
          color: AppColors.textLow, fontSize: 11, letterSpacing: 0.6),
    ),
  );
}
