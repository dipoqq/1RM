/// A single password rule, in the order it is checked. The UI translates each
/// one — the policy itself stays language-free so it can be unit-tested and
/// reused wherever a password is set (sign-up today, the reset flow tomorrow).
enum PasswordRule {
  /// At least [PasswordPolicy.minLength] characters.
  minLength,

  /// Contains a lowercase letter.
  lowercase,

  /// Contains an uppercase letter.
  uppercase,

  /// Contains a digit.
  digit,

  /// Contains a special (non-alphanumeric) symbol.
  symbol,
}

/// Strict password requirements, enforced on account creation and password
/// resets: at least 8 characters with lowercase, uppercase, a digit and a
/// symbol. Pure — no Flutter, no I/O — so it is trivially testable.
abstract final class PasswordPolicy {
  static const int minLength = 8;

  /// The first rule [password] fails, or null if it satisfies all of them.
  ///
  /// Returning the *first* unmet rule (rather than a bool) lets the UI tell the
  /// user exactly what to fix, one concrete step at a time, in their language.
  static PasswordRule? firstUnmet(String password) {
    if (password.length < minLength) return PasswordRule.minLength;
    if (!password.contains(RegExp('[a-z]'))) return PasswordRule.lowercase;
    if (!password.contains(RegExp('[A-Z]'))) return PasswordRule.uppercase;
    if (!password.contains(RegExp('[0-9]'))) return PasswordRule.digit;
    // Anything that is not a letter, a digit or whitespace counts as a symbol.
    if (!password.contains(RegExp(r'[^A-Za-z0-9\s]'))) return PasswordRule.symbol;
    return null;
  }

  /// Whether [password] satisfies every rule.
  static bool isValid(String password) => firstUnmet(password) == null;
}
