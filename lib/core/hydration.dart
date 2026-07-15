/// Smart daily water-intake math.
///
/// The target is derived from the lifter's *current* bodyweight (from the live
/// profile — nothing hardcoded), at [mlPerKg] millilitres per kilogram, plus a
/// fixed bonus on days they actually trained, when sweat losses are higher.
///
/// Pure and side-effect free so it is trivially unit-tested and can be recomputed
/// on every rebuild as weight or the day's training status changes.
abstract final class WaterMath {
  /// Baseline intake per kilogram of bodyweight. 35 ml/kg is the common
  /// sports-nutrition rule of thumb for an active adult.
  static const double mlPerKg = 35;

  /// Added to the target on a day the lifter logged a workout, to cover the
  /// extra fluid lost to training.
  static const int trainingDayBonusMl = 600;

  /// The daily target in millilitres for [weightKg], with the training-day bonus
  /// applied when [trainedOnDay] is true.
  ///
  /// Returns 0 for an unusable weight (a profile still loading, a nonsense row)
  /// rather than inventing a target from a body no one has.
  static int dailyTargetMl(double weightKg, {bool trainedOnDay = false}) {
    if (!weightKg.isFinite || weightKg <= 0) return 0;
    final base = weightKg * mlPerKg;
    return (base + (trainedOnDay ? trainingDayBonusMl : 0)).round();
  }
}
