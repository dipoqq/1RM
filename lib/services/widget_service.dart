import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/workout.dart';

/// Bridges the app's live 1RM to the native home-screen widget.
///
/// Everything here is best-effort and never throws into the caller: on desktop
/// and web `home_widget` has no platform implementation, and even on mobile a
/// missing widget is not an error the log flow should care about. So all calls
/// funnel through [_guard], which swallows failures — the widget is a nicety,
/// not a source of truth.
class WidgetService {
  WidgetService._();

  /// The Android widget provider class (see OneRMWidgetProvider.kt). Redrawing
  /// is addressed to it by name.
  static const _androidProvider = 'OneRMWidgetProvider';

  // Keys written into the shared native container, read back by the widget.
  static const _kExercise = 'widget_exercise_name';
  static const _kCurrent = 'widget_current_1rm';
  static const _kProgress = 'widget_progress_percent';
  // Not in the original three, but the native layout shows "81.7 kg / 90 kg",
  // so the goal has to cross the bridge too.
  static const _kGoal = 'widget_goal_1rm';

  /// Push the active lift's numbers to the widget and trigger a native redraw.
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
