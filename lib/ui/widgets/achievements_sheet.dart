import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/achievements.dart';
import '../../core/theme.dart';
import '../../state/app_state.dart';

/// Opens the unified achievements list as a bottom sheet.
///
/// One flat, scrollable list — no categories, no nested tabs. Unlocked
/// achievements rise to the top (most recent first) and shine mint with their
/// unlock date; locked ones sit below, elegantly greyed out.
void showAchievementsSheet(
  BuildContext context,
  AppState state,
  List<Achievement> achievements,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.bgBase,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => AppScope(
      state: state,
      child: _AchievementsSheet(achievements: achievements),
    ),
  );
}

/// Sort key: unlocked before locked; within unlocked, most-recently unlocked
/// first; within locked, keep the engine's order (bench → squat → deadlift →
/// fun). Pure and separate from the widget so it can be reasoned about.
List<Achievement> sortedForDisplay(List<Achievement> input) {
  final unlocked = input.where((a) => a.unlocked).toList()
    ..sort((a, b) {
      final ad = a.unlockedAt, bd = b.unlockedAt;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad); // newest first
    });
  final locked = input.where((a) => !a.unlocked).toList();
  return [...unlocked, ...locked];
}

class _AchievementsSheet extends StatelessWidget {
  const _AchievementsSheet({required this.achievements});

  final List<Achievement> achievements;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.s;
    final items = sortedForDisplay(achievements);
    final unlockedCount = achievements.where((a) => a.unlocked).length;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.92,
      builder: (context, scroll) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: c.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            s.achievementsTitle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: c.textHi,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$unlockedCount / ${achievements.length}',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: c.success),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _AchievementTile(a: items[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.a});

  final Achievement a;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.s;
    final unlocked = a.unlocked;

    // Unlocked shines mint; locked is greyed out.
    final accent = unlocked ? c.success : c.textLow;
    final titleColor = unlocked ? c.textHi : c.textLow;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: unlocked ? c.successTint : c.card,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: unlocked ? c.success.withValues(alpha: 0.4) : c.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: unlocked
                  ? c.success.withValues(alpha: 0.18)
                  : c.bgBase,
              shape: BoxShape.circle,
            ),
            child: Icon(
              unlocked ? Icons.emoji_events : Icons.lock_outline,
              color: accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.achievementTitle(a.id),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: unlocked ? FontWeight.w700 : FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  unlocked ? s.achievementDesc(a.id) : s.achievementNotUnlocked,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: c.textLow,
                    fontStyle: unlocked ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
                if (unlocked && a.unlockedAt != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.event_available, size: 13, color: c.success),
                      const SizedBox(width: 5),
                      Text(
                        s.achievementUnlockedAt(
                          DateFormat.yMMMd(s.locale.code)
                              .format(a.unlockedAt!),
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: c.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
