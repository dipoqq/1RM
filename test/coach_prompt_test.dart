import 'package:bench_app/core/constants.dart';
import 'package:bench_app/core/l10n/strings_en.dart';
import 'package:bench_app/models/profile.dart';
import 'package:bench_app/models/workout.dart';
import 'package:bench_app/services/gemini_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The coach prompt is compiled from the lifter's own history and body — these
/// lock what actually reaches the model, without a network call.
void main() {
  const strings = EnStrings();
  const profile = Profile(weightKg: 82, benchGoalKg: 120);

  Workout w({
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

  test('includes the bodyweight and each trained lift with its goal', () {
    final history = WorkoutHistory([
      w(date: DateTime(2026, 7, 14), exercise: Exercise.benchPress, weight: 100),
      w(date: DateTime(2026, 7, 12), exercise: Exercise.squat, weight: 140),
    ]);

    final prompt = GeminiService.coachPrompt(history, profile, strings);

    expect(prompt, contains('82 kg')); // bodyweight
    expect(prompt, contains('Bench Press'));
    expect(prompt, contains('Squat'));
    expect(prompt, contains('goal 120 kg')); // bench goal
    // A lift never trained is not fabricated into the prompt.
    expect(prompt, isNot(contains('Deadlift')));
  });

  test('flags a detected plateau for the model', () {
    // Three consecutive failed heavy bench days -> plateau.
    final history = WorkoutHistory([
      w(date: DateTime(2026, 7, 14), weight: 110, completed: false),
      w(date: DateTime(2026, 7, 11), weight: 110, completed: false),
      w(date: DateTime(2026, 7, 8), weight: 110, completed: false),
    ]);

    final prompt = GeminiService.coachPrompt(history, profile, strings);
    expect(prompt, contains('PLATEAU'));
  });

  test('caps the history window rather than dumping everything', () {
    // 20 bench sessions; only the most recent handful should appear.
    final many = [
      for (var i = 0; i < 20; i++)
        w(date: DateTime(2026, 7, 20).subtract(Duration(days: i)), weight: 100),
    ];
    final prompt = GeminiService.coachPrompt(
        WorkoutHistory(many), profile, strings);

    // Each rendered session line carries a "kg 1RM" tag; count them.
    final lines = '1RM'.allMatches(prompt).length;
    // best-1RM summary line + at most the capped window of sessions.
    expect(lines, lessThanOrEqualTo(8));
  });

  test('asks the model to reply in the app language', () {
    final history = WorkoutHistory([w(date: DateTime(2026, 7, 14))]);
    final prompt = GeminiService.coachPrompt(history, profile, strings);
    expect(prompt, contains(strings.geminiReplyLanguage));
  });
}
