/// Program constants, ported from bench_tracker.py.
library;

const double kMilestoneKg = 80.0; // intermediate 1RM rubicon
const double kDefaultGoalKg = 95.0; // 1RM goal a fresh profile starts on

/// Bounds on the custom bench press goal. The floor is the empty bar — a goal
/// below it is not a goal — and the ceiling is comfortably past the all-time
/// raw world record, so it only ever catches a typo (950 for 95).
const double kMinGoalKg = 20.0;
const double kMaxGoalKg = 500.0;

const double kBarbellKg = 20.0; // standard Olympic bar
const double kPlateStepKg = 2.5; // smallest practical jump (2 x 1.25 kg)
const int kPlateauThreshold = 3; // consecutive failed heavy days = plateau
const double kPlateauDeload = 0.10; // forced 10% cut once a plateau is detected

/// Persisted verbatim in `workouts.workout_type`; the SQL CHECK constraint and
/// the plateau detector both depend on these exact strings.
abstract final class WorkoutType {
  static const heavy = 'Heavy Day (Strength)';
  static const volume = 'Volume Day (Hypertrophy/Technique)';
  static const deload = 'Deload (Recovery)';

  static const all = <String>[heavy, volume, deload];
}

/// A 1RM worth celebrating. [isFinal] marks the lifter's own goal, as opposed
/// to the fixed 80 kg rubicon on the way to it.
typedef Milestone = ({double kg, bool isFinal});

/// The milestones for a lifter whose goal is [goalKg], ascending.
///
/// The 80 kg rubicon is only a milestone if the goal is actually above it —
/// with a 75 kg goal there is nothing intermediate about 80, and celebrating a
/// milestone the lifter has not set and may never reach would be nonsense. A
/// goal of exactly 80 kg collapses the two into one final milestone rather than
/// firing twice for the same weight.
List<Milestone> milestonesFor(double goalKg) => [
      if (goalKg > kMilestoneKg) (kg: kMilestoneKg, isFinal: false),
      (kg: goalKg, isFinal: true),
    ];

/// The lifter, as Gemini should understand him.
const kLifterProfile =
    'an 18-year-old, 197 cm tall, 94 kg lifter';
