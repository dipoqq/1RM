import 'package:flutter/material.dart';

import '../../core/ranks.dart';
import '../../core/theme.dart';
import '../../models/profile.dart';
import '../../models/workout.dart';
import '../../state/app_state.dart';

/// The lifter's current powerlifting rank ("Звание"), shown prominently on the
/// Training and Analytics screens.
///
/// The rank is computed live from the sum of the best estimated 1RMs across the
/// big three divided by the lifter's *current* bodyweight (read straight from
/// [profile]). Change the bodyweight in Settings or log a heavier lift and the
/// badge re-ranks on the next build — there is no cached or hardcoded weight.
class RankBadge extends StatelessWidget {
  const RankBadge({super.key, required this.history, required this.profile});

  final WorkoutHistory history;
  final Profile profile;

  double _best(Exercise e) => history.forExercise(e).bestEstimated1rm ?? 0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.s;

    final bench = _best(Exercise.benchPress);
    final squat = _best(Exercise.squat);
    final deadlift = _best(Exercise.deadlift);

    final rank = Ranks.forLifts(
      benchKg: bench,
      squatKg: squat,
      deadliftKg: deadlift,
      bodyweightKg: profile.weightKg,
    );
    final ratio = Ranks.ratio(
      totalKg: bench + squat + deadlift,
      bodyweightKg: profile.weightKg,
    );

    final (icon, tint) = _face(rank, c);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tint.withValues(alpha: 0.22), c.card],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: tint.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: tint, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.rankTitle.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: c.textLow,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s.rankLabel(rank),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: c.textHi,
                    height: 1.1,
                  ),
                ),
                if (ratio != null && ratio > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    s.rankRatio(ratio.toStringAsFixed(1)),
                    style: TextStyle(fontSize: 12, color: c.textMid),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The icon and accent colour that escalate with the rank.
  (IconData, Color) _face(StrengthRank rank, AppPalette c) => switch (rank) {
        StrengthRank.starter => (Icons.self_improvement, c.textMid),
        StrengthRank.beginner => (Icons.fitness_center, c.accentDim),
        StrengthRank.intermediate => (Icons.bolt, c.accent),
        StrengthRank.advanced => (Icons.military_tech, c.warning),
        StrengthRank.elite => (Icons.emoji_events, c.success),
      };
}
