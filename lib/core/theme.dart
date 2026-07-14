import 'package:flutter/material.dart';

import 'theme_mode.dart';

// Re-exported so a widget needing both the palette and the enum has one import.
export 'theme_mode.dart';

/// Every semantic colour in the app, for one theme.
///
/// This used to be a set of `static const` fields, which meant the palette was
/// baked into the widget tree at compile time — including into `const` widgets,
/// which is precisely what a runtime theme switch cannot survive. It is now a
/// [ThemeExtension] carried by [ThemeData], so a switch rebuilds the tree with
/// the other instance and every screen follows.
///
/// Widgets read it as `context.colors`. The names are unchanged from the old
/// AppColors, so what each one MEANS is the same in both themes — `card` is
/// always the card fill, `textLow` is always the quietest text — and no screen
/// has to know which theme is in force.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.bgBase,
    required this.bgSurface,
    required this.card,
    required this.border,
    required this.accent,
    required this.accentDim,
    required this.accentTint,
    required this.success,
    required this.successDim,
    required this.successTint,
    required this.danger,
    required this.dangerTint,
    required this.warning,
    required this.warningTint,
    required this.carbs,
    required this.fats,
    required this.onAccent,
    required this.textHi,
    required this.textMid,
    required this.textLow,
  });

  final Brightness brightness;

  final Color bgBase; // window background, app bar, input fill
  final Color bgSurface; // page background
  final Color card; // card fill
  final Color border; // hairline borders

  final Color accent; // mint — primary, heavy day
  final Color accentDim; // accent text ON accentTint
  final Color accentTint; // accent wash behind accentDim

  final Color success; // completed, volume day
  final Color successDim;
  final Color successTint;

  final Color danger; // failed sets
  final Color dangerTint;

  final Color warning; // deload, plateau, over-target rings
  final Color warningTint;

  /// Macro accents. The warning colour is deliberately NOT reused here: a ring
  /// turns [warning] when it goes over target, so an always-amber macro could
  /// not signal that.
  final Color carbs;
  final Color fats;

  final Color onAccent; // text/icons on top of [accent]

  final Color textHi; // headings
  final Color textMid; // body
  final Color textLow; // captions

  @override
  AppPalette copyWith({
    Brightness? brightness,
    Color? bgBase,
    Color? bgSurface,
    Color? card,
    Color? border,
    Color? accent,
    Color? accentDim,
    Color? accentTint,
    Color? success,
    Color? successDim,
    Color? successTint,
    Color? danger,
    Color? dangerTint,
    Color? warning,
    Color? warningTint,
    Color? carbs,
    Color? fats,
    Color? onAccent,
    Color? textHi,
    Color? textMid,
    Color? textLow,
  }) =>
      AppPalette(
        brightness: brightness ?? this.brightness,
        bgBase: bgBase ?? this.bgBase,
        bgSurface: bgSurface ?? this.bgSurface,
        card: card ?? this.card,
        border: border ?? this.border,
        accent: accent ?? this.accent,
        accentDim: accentDim ?? this.accentDim,
        accentTint: accentTint ?? this.accentTint,
        success: success ?? this.success,
        successDim: successDim ?? this.successDim,
        successTint: successTint ?? this.successTint,
        danger: danger ?? this.danger,
        dangerTint: dangerTint ?? this.dangerTint,
        warning: warning ?? this.warning,
        warningTint: warningTint ?? this.warningTint,
        carbs: carbs ?? this.carbs,
        fats: fats ?? this.fats,
        onAccent: onAccent ?? this.onAccent,
        textHi: textHi ?? this.textHi,
        textMid: textMid ?? this.textMid,
        textLow: textLow ?? this.textLow,
      );

  /// Crossfades the whole palette, so flipping the switch animates every
  /// surface, border and label together instead of snapping.
  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      bgBase: c(bgBase, other.bgBase),
      bgSurface: c(bgSurface, other.bgSurface),
      card: c(card, other.card),
      border: c(border, other.border),
      accent: c(accent, other.accent),
      accentDim: c(accentDim, other.accentDim),
      accentTint: c(accentTint, other.accentTint),
      success: c(success, other.success),
      successDim: c(successDim, other.successDim),
      successTint: c(successTint, other.successTint),
      danger: c(danger, other.danger),
      dangerTint: c(dangerTint, other.dangerTint),
      warning: c(warning, other.warning),
      warningTint: c(warningTint, other.warningTint),
      carbs: c(carbs, other.carbs),
      fats: c(fats, other.fats),
      onAccent: c(onAccent, other.onAccent),
      textHi: c(textHi, other.textHi),
      textMid: c(textMid, other.textMid),
      textLow: c(textLow, other.textLow),
    );
  }
}

/// The original light palette, ported 1:1 from bench_tracker.py so the Flutter
/// app and the Python app remain visually the same product.
const kLightPalette = AppPalette(
  brightness: Brightness.light,
  bgBase: Color(0xFFFFFFFF),
  bgSurface: Color(0xFFF9FAFB),
  card: Color(0xFFF3F4F6),
  border: Color(0xFFE5E7EB),
  accent: Color(0xFF0D9488), // teal
  accentDim: Color(0xFF0F766E),
  accentTint: Color(0xFFCCFBF1),
  success: Color(0xFF10B981),
  successDim: Color(0xFF059669),
  successTint: Color(0xFFD1FAE5),
  danger: Color(0xFFEF4444),
  dangerTint: Color(0xFFFEE2E2),
  warning: Color(0xFFF59E0B),
  warningTint: Color(0xFFFEF3C7),
  carbs: Color(0xFF3B82F6), // blue
  fats: Color(0xFF8B5CF6), // violet
  onAccent: Color(0xFFFFFFFF),
  textHi: Color(0xFF111827), // charcoal
  textMid: Color(0xFF4B5563),
  textLow: Color(0xFF9CA3AF),
);

/// The dark/mint palette.
///
/// Not the light palette inverted. Two things are deliberately re-derived
/// rather than flipped:
///
///   * The mint is BRIGHTER than the light theme's teal (#2DD4BF vs #0D9488).
///     A colour that reads as a confident accent on white is a muddy smear on
///     near-black; it has to gain luminance to keep the same visual weight.
///   * `accentDim` and the `*Tint` pairs swap roles. In the light theme the
///     tint is pale and the text on it is dark; here the tint is a deep wash
///     and the text on it is bright. The NAMES still mean what they meant —
///     "accentDim on accentTint is legible" — which is why no widget had to
///     learn about themes.
///
/// `onAccent` is near-black, not white: mint at this luminance carries dark
/// text at a far better contrast ratio than white text, which would fail WCAG
/// AA on every filled button in the app.
const kDarkPalette = AppPalette(
  brightness: Brightness.dark,
  bgBase: Color(0xFF121918), // app bar, input fill — lifted off the page
  bgSurface: Color(0xFF0B100F), // page background — the deepest surface
  card: Color(0xFF161F1D),
  border: Color(0xFF24302E),
  accent: Color(0xFF2DD4BF), // mint
  accentDim: Color(0xFF5EEAD4),
  accentTint: Color(0xFF10332F),
  success: Color(0xFF34D399),
  successDim: Color(0xFF6EE7B7),
  successTint: Color(0xFF0F3A2E),
  danger: Color(0xFFF87171),
  dangerTint: Color(0xFF3B1D1D),
  warning: Color(0xFFFBBF24),
  warningTint: Color(0xFF3A2E12),
  carbs: Color(0xFF60A5FA),
  fats: Color(0xFFA78BFA),
  onAccent: Color(0xFF06251F), // dark text on bright mint
  textHi: Color(0xFFE6F1EF),
  textMid: Color(0xFF9CB0AC),
  textLow: Color(0xFF6B807C),
);

AppPalette paletteFor(AppThemeMode mode) =>
    mode == AppThemeMode.dark ? kDarkPalette : kLightPalette;

/// Colours that do not belong to a theme.
abstract final class AppColors {
  /// Deliberately louder than the app chrome — and the same in both themes.
  /// Confetti that dimmed itself to match the background would be missing the
  /// point of confetti.
  static const confetti = <Color>[
    Color(0xFF14B8A6), Color(0xFF34D399), Color(0xFFFBBF24), Color(0xFFF87171),
    Color(0xFF60A5FA), Color(0xFFA78BFA), Color(0xFFF472B6), Color(0xFF2DD4BF),
  ];
}

abstract final class AppRadii {
  static const card = 16.0;
  static const control = 12.0;
}

/// The palette in force. Every widget reads its colours through this.
extension AppPaletteContext on BuildContext {
  AppPalette get colors =>
      Theme.of(this).extension<AppPalette>() ?? kDarkPalette;
}

/// Builds the theme for [mode]. Both themes are built from the same code path,
/// so a widget styled by [ThemeData] alone (buttons, inputs, dividers) needs no
/// per-theme handling at all.
ThemeData buildTheme(AppThemeMode mode) {
  final c = paletteFor(mode);
  final dark = mode == AppThemeMode.dark;

  final scheme = ColorScheme(
    brightness: c.brightness,
    primary: c.accent,
    onPrimary: c.onAccent,
    secondary: c.success,
    onSecondary: c.onAccent,
    error: c.danger,
    onError: dark ? const Color(0xFF2A0F0F) : c.onAccent,
    surface: c.bgBase,
    onSurface: c.textHi,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: c.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bgSurface,
    fontFamily: 'Segoe UI',
    splashFactory: InkSparkle.splashFactory,
    // The palette rides on the theme, which is what makes `context.colors`
    // work — and what makes the switch animate rather than snap.
    extensions: [c],
    appBarTheme: AppBarTheme(
      backgroundColor: c.bgBase,
      surfaceTintColor: Colors.transparent,
      foregroundColor: c.textHi,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: c.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: BorderSide(color: c.border),
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
      fillColor: c.bgBase,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: BorderSide(color: c.accent, width: 1.6),
      ),
      labelStyle: TextStyle(color: c.textMid),
    ),
    dividerTheme: DividerThemeData(
      color: c.border,
      thickness: 1,
      space: 1,
    ),
    textTheme: TextTheme(
      headlineSmall: TextStyle(
          color: c.textHi, fontWeight: FontWeight.w700, fontSize: 22),
      titleMedium: TextStyle(
          color: c.textHi, fontWeight: FontWeight.w600, fontSize: 16),
      bodyMedium: TextStyle(color: c.textMid, fontSize: 14),
      labelSmall:
          TextStyle(color: c.textLow, fontSize: 11, letterSpacing: 0.6),
    ),
  );
}
