import 'package:bench_app/core/constants.dart';
import 'package:bench_app/models/workout.dart';
import 'package:flutter_test/flutter_test.dart';

Workout _w({
  required DateTime date,
  Exercise exercise = Exercise.benchPress,
  double weight = 100,
  bool completed = true,
}) =>
    Workout(
      date: date,
      exercise: exercise,
      workoutType: WorkoutType.heavy,
      weight: weight,
      reps: 5,
      sets: 3,
      completed: completed,
    );

void main() {
  group('WorkoutHistory calendar helpers', () {
    test('onDay returns every session logged that local calendar day', () {
      final history = WorkoutHistory([
        _w(date: DateTime(2026, 7, 15, 8), exercise: Exercise.benchPress),
        _w(date: DateTime(2026, 7, 15, 19), exercise: Exercise.squat),
        _w(date: DateTime(2026, 7, 14, 18), exercise: Exercise.deadlift),
      ]);

      final onThe15th = history.onDay(DateTime(2026, 7, 15));
      expect(onThe15th, hasLength(2));
      expect(
        onThe15th.map((w) => w.exercise).toSet(),
        {Exercise.benchPress, Exercise.squat},
      );
      expect(history.onDay(DateTime(2026, 7, 14)), hasLength(1));
      expect(history.onDay(DateTime(2026, 7, 13)), isEmpty);
    });

    test('a late-evening session stays on its own local day', () {
      final history =
          WorkoutHistory([_w(date: DateTime(2026, 7, 15, 23, 45))]);
      expect(history.onDay(DateTime(2026, 7, 15)), hasLength(1));
      expect(history.onDay(DateTime(2026, 7, 16)), isEmpty);
    });

    test('completedDays marks only days with a completed session', () {
      final history = WorkoutHistory([
        _w(date: DateTime(2026, 7, 15), completed: true),
        _w(date: DateTime(2026, 7, 14), completed: false), // failed only
        _w(date: DateTime(2026, 7, 13), completed: true),
      ]);

      final days = history.completedDays;
      expect(days, contains(DateTime(2026, 7, 15)));
      expect(days, contains(DateTime(2026, 7, 13)));
      // A failed-only day earns no highlight dot.
      expect(days, isNot(contains(DateTime(2026, 7, 14))));
      expect(history.hasCompletedOn(DateTime(2026, 7, 15)), isTrue);
      expect(history.hasCompletedOn(DateTime(2026, 7, 14)), isFalse);
    });

    test('a day with both a failed and a completed session still counts', () {
      final history = WorkoutHistory([
        _w(date: DateTime(2026, 7, 15, 9), completed: false),
        _w(date: DateTime(2026, 7, 15, 18), completed: true),
      ]);
      expect(history.hasCompletedOn(DateTime(2026, 7, 15)), isTrue);
      expect(history.onDay(DateTime(2026, 7, 15)), hasLength(2));
    });
  });
}
