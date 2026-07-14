/// Which palette the app renders in.
///
/// Two explicit choices, not three: there is no "system" option, because the
/// theme is persisted per account and synced (see `profiles.theme`), and a
/// value meaning "whatever this device says" cannot sync to another device in
/// any meaningful way. The lifter picks a look; it follows them.
///
/// This lives apart from theme.dart — which is all Flutter — so that [Profile]
/// can carry the preference without the model layer importing material.dart.
library;

enum AppThemeMode {
  dark('dark'),
  light('light');

  const AppThemeMode(this.code);

  /// Persisted verbatim in `profiles.theme`; the SQL CHECK constraint depends
  /// on these exact strings.
  final String code;

  /// The other one. What the switch flips to.
  AppThemeMode get opposite => this == dark ? light : dark;

  static AppThemeMode fromCode(String? code) =>
      values.firstWhere((t) => t.code == code, orElse: () => dark);
}
