import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../core/l10n/app_strings.dart';
import '../models/meal.dart';
import '../models/profile.dart';
import '../models/workout.dart';
import 'local_storage.dart';

/// Bridges the app's live data to the native home-screen widgets.
///
/// Two widgets live out there: the strength widget (the tracked lift's 1RM
/// against its goal) and the nutrition widget (today's КБЖУ against the daily
/// targets). Everything here is best-effort and never throws into the caller:
/// on desktop and web `home_widget` has no platform implementation, and even
/// on mobile a missing widget is not an error the log flow should care about.
/// So all calls funnel through [_guard], which swallows failures — the widgets
/// are a nicety, not a source of truth.
class WidgetService {
  WidgetService._();

  /// The Android widget provider classes (see the .kt files by these names).
  /// Redrawing is addressed to them by name.
  static const _androidProvider = 'OneRMWidgetProvider';
  static const _nutritionProvider = 'NutritionWidgetProvider';

  // Keys written into the shared native container, read back by the widgets.
  static const _kExercise = 'widget_exercise_name';
  static const _kCurrent = 'widget_current_1rm';
  static const _kProgress = 'widget_progress_percent';
  // Not in the original three, but the native layout shows "81.7 kg / 90 kg",
  // so the goal has to cross the bridge too.
  static const _kGoal = 'widget_goal_1rm';

  /// Which lift the strength widget tracks, as an [Exercise.name] string —
  /// mirrored into the native container so the Kotlin side can read the user's
  /// choice directly, alongside the resolved values below.
  static const _kSelectedExercise = 'widget_selected_exercise';

  // Nutrition widget keys. All display values cross as pre-formatted strings
  // (see [updateHomeScreen] for why); only the bar percent crosses as an int.
  static const _kNutritionTitle = 'widget_nutrition_title';
  static const _kNutritionKcal = 'widget_nutrition_kcal';
  static const _kNutritionPercent = 'widget_nutrition_percent';
  static const _kNutritionMacros = 'widget_nutrition_macros';

  /// The lift the user chose for the strength widget in Settings, defaulting
  /// to the bench press until they pick one.
  static Future<Exercise> selectedExercise() async {
    try {
      await LocalStorage.init();
    } catch (_) {
      // No prefs on this platform (e.g. under test): fall through to default.
    }
    final stored = LocalStorage.getWidgetExercise();
    return Exercise.values.firstWhere(
      (e) => e.name == stored,
      orElse: () => Exercise.benchPress,
    );
  }

  /// Persist the widget's tracked lift and mirror it to the native container.
  /// The caller follows up with a data refresh (see AppState.refreshWidgets) so
  /// the widget repaints with the newly selected lift's numbers immediately.
  static Future<void> setSelectedExercise(Exercise exercise) async {
    try {
      await LocalStorage.init();
      await LocalStorage.setWidgetExercise(exercise.name);
    } catch (_) {}
    await _guard(() async {
      await HomeWidget.saveWidgetData<String>(_kSelectedExercise, exercise.name);
    });
  }

  /// Recompute the strength widget from the full state and force a redraw.
  ///
  /// The lift shown is the one picked in Settings — NOT the tab's active
  /// exercise — so logging a squat while the widget tracks the bench leaves
  /// the widget on the bench, correctly refreshed. Called on every workout
  /// insert and delete, and on every goal change.
  static Future<void> syncStrength({
    required WorkoutHistory history,
    required Profile profile,
  }) async {
    final exercise = await selectedExercise();
    final best = history.forExercise(exercise).bestEstimated1rm ?? 0;
    await updateHomeScreen(exercise, best, profile.goalFor(exercise));
  }

  /// Push the tracked lift's numbers to the widget and trigger a native redraw.
  ///
  /// [current1RM] is the best estimated 1RM for [exercise]; [goal1RM] the target
  /// it is measured against. The progress percent is clamped to 0..100 so the
  /// native progress bar never overflows even when the goal is beaten.
  ///
  /// The kg values cross the bridge as pre-formatted STRINGS, not doubles:
  /// home_widget serialises a Dart double as `Long.doubleToRawLongBits`, which is
  /// awkward to read back in Kotlin. A string (putString/getString) and an int
  /// (putInt/getInt) round-trip cleanly, and the native layout only needs them
  /// for display anyway.
  static Future<void> updateHomeScreen(
    Exercise exercise,
    double current1RM,
    double goal1RM,
  ) async {
    final percent = goal1RM > 0
        ? (current1RM / goal1RM * 100).round().clamp(0, 100)
        : 0;

    await _guard(() async {
      await HomeWidget.saveWidgetData<String>(_kExercise, exercise.label);
      await HomeWidget.saveWidgetData<String>(_kCurrent, _fmt(current1RM));
      await HomeWidget.saveWidgetData<String>(_kGoal, _fmt(goal1RM));
      await HomeWidget.saveWidgetData<int>(_kProgress, percent);
      await HomeWidget.updateWidget(androidName: _androidProvider);
    });
  }

  /// Push today's КБЖУ — calories, protein, fats, carbs against the daily
  /// targets — to the nutrition widget and trigger a native redraw. Called on
  /// every meal insert/delete/clear and whenever the targets move (bodyweight,
  /// goal or activity edited).
  ///
  /// [s] localises the header and the Б/Ж/У initials, so the widget follows
  /// the app's language.
  static Future<void> updateNutrition({
    required AppStrings s,
    required MacroTotals totals,
    required Targets targets,
  }) async {
    final percent = targets.kcal > 0
        ? (totals.calories / targets.kcal * 100).round().clamp(0, 100)
        : 0;

    final macros = '${s.proteinInitial} ${totals.protein.round()}/'
        '${targets.protein}${s.unitGrams}  ·  '
        '${s.fatsInitial} ${totals.fats.round()}/'
        '${targets.fats}${s.unitGrams}  ·  '
        '${s.carbsInitial} ${totals.carbs.round()}/'
        '${targets.carbs}${s.unitGrams}';

    await _guard(() async {
      await HomeWidget.saveWidgetData<String>(
          _kNutritionTitle, s.widgetNutritionTitle);
      await HomeWidget.saveWidgetData<String>(_kNutritionKcal,
          '${totals.calories.round()} / ${targets.kcal} ${s.unitKcal}');
      await HomeWidget.saveWidgetData<int>(_kNutritionPercent, percent);
      await HomeWidget.saveWidgetData<String>(_kNutritionMacros, macros);
      await HomeWidget.updateWidget(androidName: _nutritionProvider);
    });
  }

  /// One decimal, trailing ".0" dropped: 81.67 -> "81.7", 90.0 -> "90".
  static String _fmt(double v) {
    final s = v.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  static Future<void> _guard(Future<void> Function() body) async {
    // Only mobile has a native widget host; skip the plugin call elsewhere so a
    // desktop/web run doesn't pay a MissingPluginException on every log.
    if (kIsWeb ||
        !(defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      return;
    }
    try {
      await body();
    } catch (e) {
      debugPrint('WidgetService: home-screen update skipped ($e)');
    }
  }
}
