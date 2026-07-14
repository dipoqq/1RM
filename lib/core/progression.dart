import 'constants.dart';

/// A single warm-up set in the ramp.
typedef WarmupSet = ({String label, double weight, int reps, String purpose});

/// Pure functions implementing the program's progression rules.
///
/// No IO, no Flutter imports — these are the rules of the program and are
/// unit-tested directly in test/progression_test.dart.
abstract final class Progression {
  /// Round to the nearest loadable 2.5 kg increment, never below the bare bar.
  ///
  /// Gyms stock 1.25 kg plates and up, so a calculated 47.3 kg is not something
  /// you can actually load onto a barbell.
  static double roundToPlate(double weight) {
    final snapped = (weight / kPlateStepKg).round() * kPlateStepKg;
    return snapped < kBarbellKg ? kBarbellKg : snapped;
  }

  /// Epley estimate: 1RM ~= w * (1 + reps / 30). Only meaningful for a set
  /// that was actually completed.
  static double estimated1rm(double weight, int reps) =>
      weight * (1 + reps / 30);

  /// Ramp-up sets for a heavy day, from a 20 kg Olympic bar.
  ///
  /// The intent is neural activation, not fatigue: reps fall as weight climbs
  /// and the top set is a single. Every load is snapped to a real 2.5 kg
  /// increment and floored at the empty bar.
  static List<WarmupSet> warmup(double workingWeight) => [
        (
          label: 'Empty Bar',
          weight: kBarbellKg,
          reps: 10,
          purpose: 'Blood flow & joint lubrication',
        ),
        (
          label: '60%',
          weight: roundToPlate(workingWeight * 0.60),
          reps: 5,
          purpose: 'Grooving the movement pattern',
        ),
        (
          label: '80%',
          weight: roundToPlate(workingWeight * 0.80),
          reps: 3,
          purpose: 'CNS activation',
        ),
        (
          label: '90%',
          weight: roundToPlate(workingWeight * 0.90),
          reps: 1,
          purpose: 'Heavy single - feel the load, no fatigue',
        ),
      ];

  /// The weight to rebuild from once a plateau is active: a forced 10% cut,
  /// snapped back to a loadable bar.
  static double deloaded(double workingWeight) =>
      roundToPlate(workingWeight * (1 - kPlateauDeload));
}
