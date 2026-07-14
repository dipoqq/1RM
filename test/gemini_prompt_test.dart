import 'package:bench_app/core/constants.dart';
import 'package:bench_app/core/l10n/strings_en.dart';
import 'package:bench_app/models/meal.dart';
import 'package:bench_app/models/profile.dart';
import 'package:bench_app/services/gemini_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The system prompt is per-user data, not a constant.
///
/// It used to be built from a hardcoded description of the app author — "an
/// 18-year-old, 197 cm tall, 94 kg lifter" — so every beta user's meals were
/// sized against *his* body. These tests exist to make that regression loud:
/// the metrics in the prompt must come from the profile that was passed in.
void main() {
  const strings = EnStrings();
  const eaten = MacroTotals();

  String promptFor(Profile p) => GeminiService.systemPrompt(p, eaten, strings);

  group('systemPrompt body metrics', () {
    test('injects the metrics of the profile it is given', () {
      final prompt = promptFor(const Profile(
        gender: Gender.female,
        heightCm: 164,
        weightKg: 58,
        age: 27,
      ));

      expect(prompt, contains('Gender: Female'));
      expect(prompt, contains('Height: 164 cm'));
      expect(prompt, contains('Weight: 58 kg'));
      expect(prompt, contains('Age: 27 years'));
    });

    test("carries no trace of the author's body", () {
      final prompt = promptFor(const Profile(
        gender: Gender.female,
        heightCm: 164,
        weightKg: 58,
        age: 27,
      ));

      // The exact values that used to be hardcoded, and the wording that
      // carried them.
      expect(prompt, isNot(contains('197')));
      expect(prompt, isNot(contains('93')));
      expect(prompt, isNot(contains('94')));
      expect(prompt, isNot(contains('18-year-old')));
    });

    test('two different users get two different prompts', () {
      final a = promptFor(const Profile(heightCm: 197, weightKg: 93, age: 18));
      final b = promptFor(const Profile(heightCm: 164, weightKg: 58, age: 27));

      expect(a, contains('Height: 197 cm'));
      expect(b, contains('Height: 164 cm'));
      expect(a, isNot(equals(b)));
    });
  });

  group('systemPrompt fallbacks', () {
    // A profile that has not loaded, or a row written by a bad migration, can
    // carry a metric no body has. The prompt must decline to state it rather
    // than substitute a plausible-looking number — a wrong-but-confident body
    // is the failure being fixed, and a silent default is just a quieter one.
    test('declines to state a metric it does not have', () {
      final prompt = promptFor(const Profile(heightCm: 0, weightKg: -1, age: 0));

      expect(prompt, contains('Height: $kUnknownMetric'));
      expect(prompt, contains('Weight: $kUnknownMetric'));
      expect(prompt, contains('Age: $kUnknownMetric'));
      expect(prompt, isNot(contains('Height: 0 cm')));
      expect(prompt, isNot(contains('Weight: -1 kg')));
    });

    test('a bad metric does not suppress the good ones', () {
      final prompt = promptFor(const Profile(heightCm: 0, weightKg: 58, age: 27));

      expect(prompt, contains('Height: $kUnknownMetric'));
      expect(prompt, contains('Weight: 58 kg'));
      expect(prompt, contains('Age: 27 years'));
    });

    test('tells the model not to guess the unknown metric', () {
      final prompt = promptFor(const Profile(heightCm: 0));

      expect(prompt, contains('Do not guess a value'));
    });
  });
}
