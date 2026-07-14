import 'package:bench_app/core/constants.dart';
import 'package:bench_app/core/l10n/app_locale.dart';
import 'package:bench_app/models/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('milestonesFor', () {
    test('a goal above 80 kg keeps the 80 kg rubicon on the way', () {
      expect(milestonesFor(95), [(kg: 80.0, isFinal: false), (kg: 95.0, isFinal: true)]);
      expect(milestonesFor(90).map((m) => m.kg), [80.0, 90.0]);
    });

    test('a goal at or below 80 kg has no intermediate milestone', () {
      // Nothing "intermediate" about 80 kg when 75 kg is the whole goal, and
      // celebrating a weight the lifter never set would be nonsense.
      expect(milestonesFor(75), [(kg: 75.0, isFinal: true)]);
      // Exactly 80: one milestone, not two firing on the same weight.
      expect(milestonesFor(80), [(kg: 80.0, isFinal: true)]);
    });

    test('the goal is always the final milestone', () {
      for (final goal in [40.0, 80.0, 95.0, 200.0]) {
        expect(milestonesFor(goal).last, (kg: goal, isFinal: true));
      }
    });
  });

  group('benchProgress', () {
    Profile goal(double kg) => Profile(benchGoalKg: kg);

    test('bar, remaining kilos and percentage all read off the custom goal', () {
      final p = goal(90).benchProgress(45);
      expect(p.goalKg, 90);
      expect(p.ratio, closeTo(0.5, 0.001));
      expect(p.remainingKg, 45);
      expect(p.percent, 50);
      expect(p.cleared, isFalse);
    });

    test('raising the goal drains the same 1RM back down the bar', () {
      // The whole point of the feature: 82.5 kg is 87% of a 95 kg goal and
      // 100% of an 82.5 kg one, and nothing in the UI may disagree about that.
      expect(goal(95).benchProgress(82.5).percent, 87);
      expect(goal(82.5).benchProgress(82.5).percent, 100);
      expect(goal(82.5).benchProgress(82.5).cleared, isTrue);
    });

    test('a cleared goal never shows negative kilos remaining', () {
      final p = goal(90).benchProgress(100);
      expect(p.cleared, isTrue);
      expect(p.remainingKg, 0);
      // The bar is full, but the percentage tells the truth about the overshoot
      // rather than rounding it away to 100%.
      expect(p.ratio, 1.0);
      expect(p.percent, 111);
    });

    test('no logged sessions is 0%, not a crash', () {
      final p = goal(95).benchProgress(null);
      expect(p.best, isNull);
      expect(p.ratio, 0);
      expect(p.percent, 0);
      expect(p.remainingKg, 95);
    });
  });

  group('goal validation', () {
    test('accepts a sane custom target, rejects a typo', () {
      expect(Profile.isValidGoal(90), isTrue);
      expect(Profile.isValidGoal(kMinGoalKg), isTrue);
      expect(Profile.isValidGoal(kMaxGoalKg), isTrue);
      expect(Profile.isValidGoal(19.9), isFalse); // below the empty bar
      expect(Profile.isValidGoal(950), isFalse); // 950 for 95
    });

    test('copyWith clamps rather than storing an unusable goal', () {
      expect(const Profile().copyWith(benchGoalKg: 0).benchGoalKg, kMinGoalKg);
      expect(const Profile().copyWith(benchGoalKg: 9999).benchGoalKg, kMaxGoalKg);
    });
  });

  group('profile persistence', () {
    test('the goal and the language survive a round trip', () {
      const p = Profile(benchGoalKg: 92.5, locale: AppLocale.ru);
      final row = p.toUpsert('user-1');

      expect(row['bench_goal_kg'], 92.5);
      expect(row['language'], 'ru');

      // The column names are the ones the desktop app writes and the phone
      // reads back — this is the whole sync contract.
      final back = Profile.fromJson({...row, 'user_id': 'user-1'});
      expect(back.benchGoalKg, 92.5);
      expect(back.locale, AppLocale.ru);
    });

    test('a row written before migration 004 still loads', () {
      // No bench_goal_kg, no language: the pre-004 shape.
      final old = Profile.fromJson({
        'weight_kg': 94,
        'height_cm': 197,
        'age': 18,
        'goal': 'Lean Bulk',
        'activity_level': 'Very Active',
        'celebrated_milestones': [80.0],
      });
      expect(old.benchGoalKg, kDefaultGoalKg);
      expect(old.hasCelebrated(80), isTrue);
    });

    test('a goal already banked never re-fires, whatever the new goal is', () {
      const p = Profile(benchGoalKg: 90, celebratedMilestones: [80.0]);
      expect(p.hasCelebrated(80), isTrue);
      // Moving the goal from 95 to 90 exposes a milestone that has NOT been
      // celebrated — that one is allowed to fire.
      expect(p.hasCelebrated(90), isFalse);
      expect(p.milestones.map((m) => m.kg), [80.0, 90.0]);
    });
  });
}
