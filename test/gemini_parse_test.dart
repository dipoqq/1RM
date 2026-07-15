import 'package:bench_app/models/meal.dart';
import 'package:bench_app/services/gemini_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Strict JSON mode means the model returns a single JSON object; [parse] turns
/// it into (prose, Meal). These lock the happy path, the resilience fallbacks,
/// and the "don't log garbage" contract.
void main() {
  final day = DateTime(2026, 7, 15);

  group('parse — JSON mode', () {
    test('reads a well-formed object into prose + meal', () {
      final r = GeminiService.parse(
        '{"name":"Oats & Whey","advice":"Fits your remaining protein nicely.",'
        '"calories":420,"proteins":38,"carbs":51,"fats":9}',
        day,
      );

      expect(r.prose, 'Fits your remaining protein nicely.');
      expect(r.meal, isNotNull);
      expect(r.meal!.name, 'Oats & Whey');
      expect(r.meal!.calories, 420);
      expect(r.meal!.protein, 38);
      expect(r.meal!.carbs, 51);
      expect(r.meal!.fats, 9);
      // Logged against the day passed in, time stripped.
      expect(r.meal!.day, Meal.dayOf(day));
    });

    test('tolerates a markdown fence and surrounding prose', () {
      final r = GeminiService.parse(
        'Here you go:\n```json\n'
        '{"name":"Banana","advice":"A fine snack.","calories":105,'
        '"proteins":1,"carbs":27,"fats":0}\n```',
        day,
      );
      expect(r.meal, isNotNull);
      expect(r.meal!.name, 'Banana');
      expect(r.prose, 'A fine snack.');
    });

    test('accepts numeric strings with stray units', () {
      final r = GeminiService.parse(
        '{"name":"Plate","advice":"ok","calories":"~550 kcal",'
        '"proteins":"32 g","carbs":"40","fats":"18"}',
        day,
      );
      expect(r.meal, isNotNull);
      expect(r.meal!.calories, 550);
      expect(r.meal!.protein, 32);
    });

    test('missing name or core macros yields a null meal, keeping the prose',
        () {
      final r = GeminiService.parse(
        '{"advice":"I need to know what the portion was.","calories":0}',
        day,
      );
      expect(r.meal, isNull);
      expect(r.prose, 'I need to know what the portion was.');
    });
  });

  group('parse — legacy [DATA] fallback', () {
    test('still reads a [DATA] block when JSON mode was ignored', () {
      final r = GeminiService.parse(
        'Looks solid.\n[DATA] Name: Rice Bowl | Calories: 600 | Protein: 25 | '
        'Carbs: 90 | Fats: 12 [/DATA]',
        day,
      );
      expect(r.meal, isNotNull);
      expect(r.meal!.name, 'Rice Bowl');
      expect(r.meal!.calories, 600);
      expect(r.prose, 'Looks solid.');
    });

    test('plain prose with no data anywhere is a null meal', () {
      final r = GeminiService.parse('Tell me the portion size first.', day);
      expect(r.meal, isNull);
      expect(r.prose, 'Tell me the portion size first.');
    });
  });
}
