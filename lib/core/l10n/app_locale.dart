import 'dart:ui' show PlatformDispatcher;

/// The languages the app ships.
///
/// [code] is persisted verbatim in `profiles.language`; the SQL CHECK
/// constraint depends on these exact strings.
enum AppLocale {
  en('en', 'English'),
  ru('ru', 'Русский');

  const AppLocale(this.code, this.nativeName);

  final String code;

  /// Shown in the language switch. Deliberately NOT localized — a Russian
  /// speaker looking for their language in an English UI needs to see
  /// "Русский", not "Russian".
  final String nativeName;

  static AppLocale fromCode(String? code) =>
      values.firstWhere((l) => l.code == code, orElse: () => fromSystem());

  /// The language to open on before a profile has been loaded — i.e. on the
  /// sign-in screen, which is shown before we know who the user is and
  /// therefore before we know what they chose last time.
  static AppLocale fromSystem() {
    final tag = PlatformDispatcher.instance.locale.languageCode;
    return values.firstWhere(
      (l) => l.code == tag,
      orElse: () => en,
    );
  }
}
