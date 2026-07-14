import 'constants.dart';

/// The rungs of the warm-up ramp.
///
/// The label and the purpose text live in the localization layer, keyed by this
/// enum — the ramp is a rule of the program, not an English sentence, and this
/// file stays free of both Flutter and copy.
enum WarmupStage { bar, sixty, eighty, ninety }

/// A single warm-up set in the ramp.
typedef WarmupSet = ({WarmupStage stage, double weight, int reps});

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
        (stage: WarmupStage.bar, weight: kBarbellKg, reps: 10),
        (
          stage: WarmupStage.sixty,
          weight: roundToPlate(workingWeight * 0.60),
          reps: 5,
        ),
        (
          stage: WarmupStage.eighty,
          weight: roundToPlate(workingWeight * 0.80),
          reps: 3,
        ),
        (
          stage: WarmupStage.ninety,
          weight: roundToPlate(workingWeight * 0.90),
          reps: 1,
        ),
      ];

  /// The weight to rebuild from once a plateau is active: a forced 10% cut,
  /// snapped back to a loadable bar.
  static double deloaded(double workingWeight) =>
      roundToPlate(workingWeight * (1 - kPlateauDeload));
}
