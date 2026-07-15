import 'package:flutter/material.dart';

import '../models/workout.dart';
import '../state/app_state.dart';
import '../services/local_storage.dart';

enum AchievementCategory { benchPress, squats, deadlift, easterEggs }

class Achievement {
  final String id;
  final AchievementCategory category;
  final bool unlocked;
  final DateTime? unlockedAt;

  const Achievement({
    required this.id,
    required this.category,
    required this.unlocked,
    this.unlockedAt,
  });
}

class AchievementsEngine {
  static List<Achievement> evaluate(WorkoutHistory history, AppState state) {
    final List<Achievement> results = [];
    final allWorkouts = history.all.reversed.toList(); // chronological

    // Helper to evaluate 1RM achievements
    void eval1RM(String prefix, AchievementCategory cat, Exercise ex, List<double> milestones) {
      final exWorkouts = allWorkouts.where((w) => w.exercise == ex && w.completed).toList();
      for (final ms in milestones) {
        DateTime? unlockDate;
        for (final w in exWorkouts) {
          if (w.estimated1rm >= ms) {
            unlockDate = w.date;
            break; // found the first time it was exceeded
          }
        }
        results.add(Achievement(
          id: '${prefix}_${ms.toInt()}',
          category: cat,
          unlocked: unlockDate != null,
          unlockedAt: unlockDate,
        ));
      }
    }

    eval1RM('bench', AchievementCategory.benchPress, Exercise.benchPress, [50, 80, 100, 120, 150]);
    eval1RM('squat', AchievementCategory.squats, Exercise.squat, [60, 100, 140, 180, 200]);
    eval1RM('deadlift', AchievementCategory.deadlift, Exercise.deadlift, [100, 150, 200, 250, 300]);

    // Easter Eggs
    bool barWon = false;
    DateTime? barWonDate;
    bool stepBack = false;
    DateTime? stepBackDate;

    double? prevBench, prevSquat, prevDeadlift;

    for (final w in allWorkouts) {
      if (!w.completed) {
        if (!barWon) {
          barWon = true;
          barWonDate = w.date;
        }
      }
      
      bool isStepBack(double? prev) => prev != null && w.weight < prev;
      if (w.exercise == Exercise.benchPress) {
        if (isStepBack(prevBench)) { stepBack = true; stepBackDate ??= w.date; }
        prevBench = w.weight;
      } else if (w.exercise == Exercise.squat) {
        if (isStepBack(prevSquat)) { stepBack = true; stepBackDate ??= w.date; }
        prevSquat = w.weight;
      } else if (w.exercise == Exercise.deadlift) {
        if (isStepBack(prevDeadlift)) { stepBack = true; stepBackDate ??= w.date; }
        prevDeadlift = w.weight;
      }
    }

    results.add(Achievement(
      id: 'fun_bar_won',
      category: AchievementCategory.easterEggs,
      unlocked: barWon,
      unlockedAt: barWonDate,
    ));
    results.add(Achievement(
      id: 'fun_step_back',
      category: AchievementCategory.easterEggs,
      unlocked: stepBack,
      unlockedAt: stepBackDate,
    ));

    // Time-based easter eggs (persisted in LocalStorage)
    final earlyUnlocked = LocalStorage.getReminder('fun_early_bird');
    results.add(Achievement(
      id: 'fun_early_bird',
      category: AchievementCategory.easterEggs,
      unlocked: earlyUnlocked,
      unlockedAt: earlyUnlocked ? DateTime.now() : null, // Simplification
    ));

    final nightUnlocked = LocalStorage.getReminder('fun_night_owl');
    results.add(Achievement(
      id: 'fun_night_owl',
      category: AchievementCategory.easterEggs,
      unlocked: nightUnlocked,
      unlockedAt: nightUnlocked ? DateTime.now() : null, // Simplification
    ));

    return results;
  }
}

class AchievementUnlockedNotification extends Notification {
  final String title;
  const AchievementUnlockedNotification(this.title);
}
