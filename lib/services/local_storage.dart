import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // -- Reminders --
  static bool getReminder(String key) {
    return _prefs?.getBool('reminder_$key') ?? false;
  }

  static Future<void> setReminder(String key, bool value) async {
    await _prefs?.setBool('reminder_$key', value);
  }

  /// The target times for a reminder, each a 24-hour "HH:mm" string. A habit can
  /// hold several daily slots (e.g. meals at 09:00, 13:00, 18:00, 21:00).
  ///
  /// Reads through the legacy single-time key (`reminder_time_<key>`, written by
  /// 1.2.1) once, so a user upgrading to 1.3.0 keeps the time they already set
  /// instead of losing it.
  static List<String> getReminderTimes(String key) {
    final list = _prefs?.getStringList('reminder_times_$key');
    if (list != null) return list;
    final legacy = _prefs?.getString('reminder_time_$key');
    return legacy != null ? [legacy] : const [];
  }

  static Future<void> setReminderTimes(String key, List<String> times) async {
    await _prefs?.setStringList('reminder_times_$key', times);
  }

  // -- Strength goals --------------------------------------------------------
  //
  // A local cache of the three target 1RMs. The source of truth is the Supabase
  // profile; these are mirrored on every change so the goals survive offline and
  // are available before the profile round-trips. Keys match the DB columns.

  static const _benchGoalKey = 'bench_goal_kg';
  static const _squatGoalKey = 'squat_goal_kg';
  static const _deadliftGoalKey = 'deadlift_goal_kg';

  static double? getBenchGoal() => _prefs?.getDouble(_benchGoalKey);
  static double? getSquatGoal() => _prefs?.getDouble(_squatGoalKey);
  static double? getDeadliftGoal() => _prefs?.getDouble(_deadliftGoalKey);

  /// Persist all three target 1RMs together, so the local cache is never left
  /// describing a half-updated set of goals.
  static Future<void> setGoals({
    required double benchKg,
    required double squatKg,
    required double deadliftKg,
  }) async {
    await _prefs?.setDouble(_benchGoalKey, benchKg);
    await _prefs?.setDouble(_squatGoalKey, squatKg);
    await _prefs?.setDouble(_deadliftGoalKey, deadliftKg);
  }

  // -- Home-screen widget -----------------------------------------------------

  /// Which lift the strength widget tracks, as an [Exercise.name] string
  /// ('benchPress' | 'squat' | 'deadlift'). Null until the user picks one —
  /// callers default to the bench press.
  static const _widgetExerciseKey = 'widget_exercise';

  static String? getWidgetExercise() => _prefs?.getString(_widgetExerciseKey);

  static Future<void> setWidgetExercise(String name) async {
    await _prefs?.setString(_widgetExerciseKey, name);
  }

  // -- Hydration --

  /// Serialises every hydration write. `addWaterMl` is a read-modify-write, so
  /// two fast taps on "+250 ml" could both read the same starting value and one
  /// increment would be lost. Chaining each write onto the previous one's
  /// completion forces them to run strictly in order — no interleave, no lost
  /// update. When this moves to Supabase, do the same atomically server-side
  /// (see the add_water RPC in the audit).
  static Future<void> _chain = Future.value();

  static String _waterKey(DateTime date) =>
      'water_${date.year}_${date.month}_${date.day}';

  static int getWaterMl(DateTime date) {
    return _prefs?.getInt(_waterKey(date)) ?? 0;
  }

  /// Add [amount] ml to [date]'s total. Pass a negative [amount] to subtract
  /// (the "-250 ml" button). The result is clamped at 0 — water logged can never
  /// go below empty — and the clamp lives inside the [_chain] critical section
  /// so a subtract racing an add still reads the true current value first.
  static Future<void> addWaterMl(DateTime date, int amount) {
    // Each call runs after the previous one resolves, so the read below always
    // sees the prior write.
    final next = _chain.then((_) async {
      final key = _waterKey(date);
      final current = _prefs?.getInt(key) ?? 0;
      final updated = (current + amount).clamp(0, 1 << 31);
      await _prefs?.setInt(key, updated);
    });
    // Swallow failures on the chain itself so one failed write can't wedge every
    // later one; the awaited `next` still surfaces this call's own error.
    _chain = next.catchError((_) {});
    return next;
  }
}
