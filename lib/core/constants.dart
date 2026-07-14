/// Program constants, ported from bench_tracker.py.
library;

const double kMilestoneKg = 80.0; // intermediate 1RM rubicon
const double kDefaultGoalKg = 95.0; // 1RM goal a fresh profile starts on

/// Bounds on the custom bench press goal. The floor is the empty bar — a goal
/// below it is not a goal — and the ceiling is comfortably past the all-time
/// raw world record, so it only ever catches a typo (950 for 95).
const double kMinGoalKg = 20.0;
const double kMaxGoalKg = 500.0;

/// Bounds on the body metrics collected at onboarding. Wide enough that no real
/// lifter is locked out, tight enough to catch the slip that would otherwise
/// feed Mifflin-St Jeor a nonsense BMR — 18 kg for 180, or a height typed into
/// the weight field.
const double kMinHeightCm = 100.0;
const double kMaxHeightCm = 250.0;
const double kMinWeightKg = 30.0;
const double kMaxWeightKg = 300.0;
const int kMinAge = 13;
const int kMaxAge = 100;

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

/// What the AI is told when a body metric is missing or nonsense.
///
/// This used to be a hardcoded description of one specific lifter, which every
/// user's prompt was built from — so the AI sized a stranger's meals against
/// that lifter's body. The metrics now come from the live [Profile]; when one
/// of them is unusable the prompt says so rather than substituting a number,
/// because inventing a plausible body is the bug, not the fix.
const kUnknownMetric = 'unknown';
