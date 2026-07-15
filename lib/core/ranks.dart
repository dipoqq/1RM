/// A powerlifting strength rank ("Звание"), earned by relative strength rather
/// than raw kilos so a lighter lifter is not permanently outranked by a heavier
/// one who moves the same bar.
///
/// The names the UI shows are localized (`AppStrings.rankLabel`); the enum only
/// carries the ordering. Ascending: [starter] is the weakest, [elite] the
/// strongest.
enum StrengthRank { starter, beginner, intermediate, advanced, elite }

/// The strength-rank math.
///
/// The rank is a function of ONE ratio: the sum of the lifter's best estimated
/// 1RMs across the big three (bench + squat + deadlift) divided by their own
/// current bodyweight. Bodyweight is always passed in from the live profile —
/// there is deliberately no hardcoded weight anywhere in here, because a fixed
/// bodyweight is exactly the bug that made every lifter share one person's
/// numbers.
abstract final class Ranks {
  /// Ratio thresholds on (bench + squat + deadlift 1RM) ÷ bodyweight. Chosen to
  /// track the usual raw-total milestones: ~2× bodyweight is a trained novice,
  /// ~5× is competitive, ~7× is elite. Each rank starts at its lower bound.
  static const double beginnerAt = 2.0;
  static const double intermediateAt = 3.5;
  static const double advancedAt = 5.0;
  static const double eliteAt = 7.0;

  /// The relative-strength ratio, or null when it cannot be computed because
  /// there is no usable bodyweight (a profile that has not loaded, or a nonsense
  /// row). A [totalKg] of zero is a *valid* ratio of 0 — an untrained lifter —
  /// not an error.
  static double? ratio({
    required double totalKg,
    required double bodyweightKg,
  }) {
    if (!bodyweightKg.isFinite || bodyweightKg <= 0) return null;
    if (!totalKg.isFinite || totalKg <= 0) return 0;
    return totalKg / bodyweightKg;
  }

  /// The rank a given relative-strength [ratio] earns.
  static StrengthRank forRatio(double ratio) {
    if (ratio >= eliteAt) return StrengthRank.elite;
    if (ratio >= advancedAt) return StrengthRank.advanced;
    if (ratio >= intermediateAt) return StrengthRank.intermediate;
    if (ratio >= beginnerAt) return StrengthRank.beginner;
    return StrengthRank.starter;
  }

  /// Rank straight from the three best 1RMs and the lifter's bodyweight. A
  /// missing lift is simply a zero contribution. Falls back to [StrengthRank
  /// .starter] when the bodyweight is unusable, so the UI always has a badge to
  /// show rather than a hole.
  static StrengthRank forLifts({
    required double benchKg,
    required double squatKg,
    required double deadliftKg,
    required double bodyweightKg,
  }) {
    final r = ratio(
      totalKg: benchKg + squatKg + deadliftKg,
      bodyweightKg: bodyweightKg,
    );
    return forRatio(r ?? 0);
  }
}
