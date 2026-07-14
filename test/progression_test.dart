import 'package:bench_app/core/constants.dart';
import 'package:bench_app/core/progression.dart';
import 'package:bench_app/models/meal.dart';
import 'package:bench_app/models/profile.dart';
import 'package:bench_app/models/workout.dart';
import 'package:bench_app/services/gemini_service.dart';
import 'package:flutter_test/flutter_test.dart';

Workout heavy({required bool completed, double weight = 70}) => Workout(
      date: DateTime(2026, 7, 14),
      workoutType: WorkoutType.heavy,
      weight: weight,
      reps: 5,
      sets: 3,
      completed: completed,
    );

Workout volume({bool completed = false}) => Workout(
      date: DateTime(2026, 7, 14),
      workoutType: WorkoutType.volume,
      weight: 65,
      reps: 8,
      sets: 3,
      completed: completed,
    );

void main() {
  group('roundToPlate', () {
    test('snaps to the nearest loadable 2.5 kg increment', () {
      expect(Progression.roundToPlate(47.3), 47.5);
      expect(Progression.roundToPlate(61.2), 60.0);
      expect(Progression.roundToPlate(62.5), 62.5);
    });

    test('never returns less than the empty bar', () {
      expect(Progression.roundToPlate(5), kBarbellKg);
      expect(Progression.roundToPlate(0), kBarbellKg);
    });
  });

  group('estimated1rm (Epley)', () {
    test('w * (1 + reps/30)', () {
      expect(Progression.estimated1rm(70, 1), closeTo(72.33, 0.01));
      expect(Progression.estimated1rm(60, 5), closeTo(70.0, 0.01));
    });
  });

  group('warmup', () {
    test('is a 20kg bar then 60/80/90% at 10/5/3/1 reps', () {
      final sets = Progression.warmup(100);
      expect(sets.map((s) => s.weight).toList(), [20.0, 60.0, 80.0, 90.0]);
      expect(sets.map((s) => s.reps).toList(), [10, 5, 3, 1]);
    });

    test('every load is loadable and floored at the bar', () {
      // 60% of 30 kg is 18 kg — below the bar, so it must clamp up to 20.
      final sets = Progression.warmup(30);
      expect(sets[1].weight, kBarbellKg);
      for (final s in sets) {
        expect(s.weight % kPlateStepKg, 0, reason: '${s.weight} is not loadable');
      }
    });
  });

  group('plateau detection', () {
    test('fires only after 3 consecutive failed heavy days', () {
      expect(WorkoutHistory([heavy(completed: false), heavy(completed: false)])
          .plateauDetected, isFalse);
      expect(WorkoutHistory([
        heavy(completed: false),
        heavy(completed: false),
        heavy(completed: false),
      ]).plateauDetected, isTrue);
    });

    test('a single success anywhere in the window clears it', () {
      expect(WorkoutHistory([
        heavy(completed: false),
        heavy(completed: true), // <- breaks the streak
        heavy(completed: false),
        heavy(completed: false),
      ]).plateauDetected, isFalse);
    });

    test('volume and deload days are ignored entirely', () {
      // Failed volume days interleaved must not count toward the streak, and
      // must not break it either.
      final h = WorkoutHistory([
        heavy(completed: false),
        volume(),
        heavy(completed: false),
        volume(),
        heavy(completed: false),
      ]);
      expect(h.plateauDetected, isTrue);
      expect(h.failedHeavyStreak, 3);
    });

    test('forces a 10% deload, snapped to a loadable bar', () {
      final h = WorkoutHistory([
        heavy(completed: false, weight: 70),
        heavy(completed: false, weight: 70),
        heavy(completed: false, weight: 70),
      ]);
      // 70 * 0.9 = 63 -> nearest 2.5 kg is 62.5
      expect(h.recommendedWorkingWeight, 62.5);
    });

    test('no plateau means no deload', () {
      final h = WorkoutHistory([heavy(completed: true, weight: 70)]);
      expect(h.recommendedWorkingWeight, 70);
    });
  });

  group('bestEstimated1rm', () {
    test('ignores failed sets — a miss proves nothing', () {
      final h = WorkoutHistory([
        heavy(completed: false, weight: 200), // huge, but failed
        heavy(completed: true, weight: 60),
      ]);
      expect(h.bestEstimated1rm, closeTo(70.0, 0.01));
    });

    test('is null with no completed sessions', () {
      expect(WorkoutHistory([heavy(completed: false)]).bestEstimated1rm, isNull);
      expect(const WorkoutHistory([]).bestEstimated1rm, isNull);
    });
  });

  group('targets', () {
    // The reference lifter: 94 kg, 180 cm, 30 y.
    //   BMR  = 10(94) + 6.25(180) - 5(30) + 5 = 1920 kcal
    //   TDEE = 1920 × 1.55 (moderately active)  = 2976 kcal
    Targets forGoal(Goal goal, {ActivityLevel? activity}) => targetsFor(
          weightKg: 94,
          heightCm: 180,
          age: 30,
          goal: goal,
          activity: activity ?? ActivityLevel.moderatelyActive,
        );

    test('Mifflin-St Jeor BMR and the activity multiplier', () {
      final t = forGoal(Goal.maintenance);
      expect(t.bmr, closeTo(1920, 0.01));
      expect(t.tdee, closeTo(2976, 0.01));

      expect(forGoal(Goal.maintenance, activity: ActivityLevel.sedentary).tdee,
          closeTo(1920 * 1.2, 0.01));
      expect(
          forGoal(Goal.maintenance, activity: ActivityLevel.lightlyActive).tdee,
          closeTo(1920 * 1.375, 0.01));
      expect(forGoal(Goal.maintenance, activity: ActivityLevel.veryActive).tdee,
          closeTo(1920 * 1.725, 0.01));
    });

    test('the goal shifts TDEE by its delta', () {
      expect(forGoal(Goal.leanBulk).kcal, 3276); // 2976 + 300
      expect(forGoal(Goal.maintenance).kcal, 2976);
      expect(forGoal(Goal.cut).kcal, 2476); // 2976 - 500
    });

    test('macros split 2 g/kg protein, 25% fats, the rest carbs', () {
      final t = forGoal(Goal.leanBulk);
      expect(t.protein, 188); // 2.0 × 94 kg
      expect(t.fats, 91); // 3276 × 0.25 / 9
      expect(t.carbs, 426); // (3276 - 752 - 819) / 4

      // And the split adds back up to the calorie target, bar rounding.
      final kcal = t.protein * 4 + t.carbs * 4 + t.fats * 9;
      expect(kcal, closeTo(t.kcal, 12));
    });

    test('protein does not depend on the goal, fats and carbs do', () {
      expect(forGoal(Goal.cut).protein, forGoal(Goal.leanBulk).protein);
      expect(forGoal(Goal.cut).carbs, lessThan(forGoal(Goal.leanBulk).carbs));
      expect(forGoal(Goal.cut).fats, lessThan(forGoal(Goal.leanBulk).fats));
    });

    test('carbs never go negative when protein and fats eat the budget', () {
      final t = targetsFor(
        weightKg: 200,
        heightCm: 150,
        age: 80,
        goal: Goal.cut,
        activity: ActivityLevel.sedentary,
      );
      expect(t.carbs, greaterThanOrEqualTo(0));
    });
  });

  group('milestones', () {
    test('80 kg already celebrated does not re-fire', () {
      const p = Profile(celebratedMilestones: [80.0]);
      expect(p.hasCelebrated(80.0), isTrue);
      expect(p.hasCelebrated(95.0), isFalse);
    });
  });

  group('GeminiService.parseReply', () {
    final day = DateTime(2026, 7, 12);

    test('extracts the meal and strips the block from the prose', () {
      const reply = 'Solid protein hit.\n'
          '[DATA] Name: Chicken Pasta | Calories: 775 | Protein: 77 | '
          'Carbs: 94 | Fats: 9 [/DATA]';
      final r = GeminiService.parseReply(reply, day);

      expect(r.prose, 'Solid protein hit.');
      expect(r.prose, isNot(contains('[DATA]')));
      expect(r.meal!.name, 'Chicken Pasta');
      expect(r.meal!.calories, 775);
      expect(r.meal!.protein, 77);
      expect(r.meal!.carbs, 94);
      expect(r.meal!.fats, 9);
    });

    test('logs against the SELECTED day, not today', () {
      const reply =
          '[DATA] Name: X | Calories: 1 | Protein: 1 | Carbs: 1 | Fats: 1 [/DATA]';
      expect(GeminiService.parseReply(reply, day).meal!.day, DateTime(2026, 7, 12));
    });

    test('tolerates units and approximations in the numbers', () {
      const reply =
          '[DATA] Name: Oats | Calories: ~550 kcal | Protein: 32.5 g | '
          'Carbs: 80g | Fats: 12 g [/DATA]';
      final m = GeminiService.parseReply(reply, day).meal!;
      expect(m.calories, 550);
      expect(m.protein, 32.5);
      expect(m.carbs, 80);
    });

    test('returns a null meal when the block is missing', () {
      final r = GeminiService.parseReply('Just prose, no block.', day);
      expect(r.meal, isNull);
      expect(r.prose, 'Just prose, no block.');
    });

    test('returns a null meal when required fields are absent', () {
      // No protein -> unusable, must fall back to the manual form rather than
      // logging a meal with a silently-zeroed macro.
      const reply = '[DATA] Name: Mystery | Calories: 400 [/DATA]';
      expect(GeminiService.parseReply(reply, day).meal, isNull);
    });

    test('carbs and fats default to zero when omitted', () {
      const reply = '[DATA] Name: Shake | Calories: 200 | Protein: 40 [/DATA]';
      final m = GeminiService.parseReply(reply, day).meal!;
      expect(m.carbs, 0);
      expect(m.fats, 0);
    });
  });

  group('Meal.dateKey', () {
    test('uses local calendar components, so a late meal stays on its own day', () {
      // 23:30 local on the 14th must key to the 14th, not the 15th in UTC.
      expect(Meal.dateKey(DateTime(2026, 7, 14, 23, 30)), '2026-07-14');
      expect(Meal.dateKey(DateTime(2026, 1, 5)), '2026-01-05');
    });
  });
}
