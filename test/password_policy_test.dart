import 'package:bench_app/core/password_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PasswordPolicy.firstUnmet', () {
    test('accepts a password that satisfies every rule', () {
      expect(PasswordPolicy.firstUnmet('Str0ng!pw'), isNull);
      expect(PasswordPolicy.isValid('Str0ng!pw'), isTrue);
    });

    test('reports the rules in a stable order, one at a time', () {
      // Too short is reported before anything else.
      expect(PasswordPolicy.firstUnmet('Aa1!'), PasswordRule.minLength);
      // Long enough, but all uppercase + digit + symbol, no lowercase.
      expect(PasswordPolicy.firstUnmet('ABCDEF1!'), PasswordRule.lowercase);
      // Missing an uppercase letter.
      expect(PasswordPolicy.firstUnmet('abcdef1!'), PasswordRule.uppercase);
      // Missing a digit.
      expect(PasswordPolicy.firstUnmet('Abcdefg!'), PasswordRule.digit);
      // Missing a symbol.
      expect(PasswordPolicy.firstUnmet('Abcdefg1'), PasswordRule.symbol);
    });

    test('exactly eight strong characters is enough', () {
      expect(PasswordPolicy.isValid('Aa1!Aa1!'), isTrue);
    });

    test('a space alone does not count as a symbol', () {
      // Whitespace is excluded from the symbol class, so this fails on symbol.
      expect(PasswordPolicy.firstUnmet('Abcdef1 '), PasswordRule.symbol);
    });

    test('rejects the empty password on length first', () {
      expect(PasswordPolicy.firstUnmet(''), PasswordRule.minLength);
    });
  });
}
