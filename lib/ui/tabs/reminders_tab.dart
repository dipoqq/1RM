import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../services/local_storage.dart';
import '../../services/notification_service.dart';
import '../../state/app_state.dart';

/// One configurable habit reminder: an on/off state plus a LIST of target times.
/// Both persist in [LocalStorage] — the boolean under `reminder_<key>`, the
/// times as a `List<String>` of "HH:mm" under `reminder_times_<key>`.
class _Habit {
  const _Habit(this.key, this.icon, this.label);

  final String key;
  final IconData icon;

  /// Pulled from [AppStrings] so the label follows the language toggle.
  final String Function(AppStrings s) label;
}

class RemindersTab extends StatefulWidget {
  const RemindersTab({super.key});

  @override
  State<RemindersTab> createState() => _RemindersTabState();
}

class _RemindersTabState extends State<RemindersTab> {
  static const _habits = <_Habit>[
    _Habit('creatine', Icons.science_outlined, _creatineLabel),
    _Habit('meal', Icons.restaurant_menu, _mealLabel),
    _Habit('hydrate', Icons.water_drop_outlined, _hydrateLabel),
    _Habit('workout', Icons.fitness_center, _workoutLabel),
  ];

  // Static tear-offs so the list above can stay `const`.
  static String _creatineLabel(AppStrings s) => s.reminderTakeCreatine;
  static String _mealLabel(AppStrings s) => s.reminderEatMeal;
  static String _hydrateLabel(AppStrings s) => s.reminderHydrate;
  static String _workoutLabel(AppStrings s) => s.reminderWorkoutTime;

  // Seeded with defaults synchronously so the tab renders immediately — a local
  // read is not worth a loading spinner, and gating the whole tab on one used to
  // spin forever wherever SharedPreferences was not initialised.
  final Map<String, bool> _enabled = {for (final h in _habits) h.key: false};
  final Map<String, List<TimeOfDay>> _times = {
    for (final h in _habits) h.key: <TimeOfDay>[],
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await LocalStorage.init();
    } catch (_) {
      // No stored prefs available (e.g. under test): keep the defaults.
      return;
    }
    if (!mounted) return;
    setState(() {
      for (final h in _habits) {
        _enabled[h.key] = LocalStorage.getReminder(h.key);
        _times[h.key] = LocalStorage.getReminderTimes(h.key)
            .map(_parseTime)
            .whereType<TimeOfDay>()
            .toList()
          ..sort(_byTime);
      }
    });
  }

  Future<void> _toggle(String key, bool value) async {
    final s = context.s;
    await LocalStorage.setReminder(key, value);
    if (!mounted) return;
    setState(() => _enabled[key] = value);

    // Turning a reminder ON is the moment to ask the OS for notification
    // permission (the Android 13+ POST_NOTIFICATIONS runtime prompt) — the
    // user just expressed exactly the intent the permission covers.
    if (value) {
      final granted = await NotificationService.requestPermission();
      if (!granted && mounted) _snack(s.notificationsDenied);
    }
    // Re-register the OS schedule either way: on registers the habit's slots,
    // off cancels them.
    await NotificationService.rescheduleAll(s);
  }

  Future<void> _persistTimes(String key) =>
      LocalStorage.setReminderTimes(key, _times[key]!.map(_formatTime).toList());

  Future<void> _addTime(_Habit habit) async {
    final s = context.s;
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: habit.label(s),
    );
    if (picked == null || !mounted) return;

    final slots = _times[habit.key]!;
    // Ignore a duplicate slot rather than storing the same time twice.
    if (slots.any((t) => t.hour == picked.hour && t.minute == picked.minute)) {
      return;
    }

    setState(() {
      slots
        ..add(picked)
        ..sort(_byTime);
      // Registering a time is an implicit "yes, remind me": don't leave a
      // scheduled slot on an inactive habit.
      _enabled[habit.key] = true;
    });
    await _persistTimes(habit.key);
    await LocalStorage.setReminder(habit.key, true);

    // A new slot is a new scheduled notification; ask for permission (no-op if
    // already granted) and rebuild the OS schedule so it fires on time.
    final granted = await NotificationService.requestPermission();
    if (!granted && mounted) _snack(s.notificationsDenied);
    await NotificationService.rescheduleAll(s);
  }

  Future<void> _removeTime(String key, TimeOfDay time) async {
    final s = context.s;
    setState(() => _times[key]!
        .removeWhere((t) => t.hour == time.hour && t.minute == time.minute));
    await _persistTimes(key);
    // The slot's notification must go with it.
    await NotificationService.rescheduleAll(s);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // -- HH:mm <-> TimeOfDay ----------------------------------------------------

  static int _byTime(TimeOfDay a, TimeOfDay b) =>
      (a.hour * 60 + a.minute) - (b.hour * 60 + b.minute);

  static TimeOfDay? _parseTime(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return TimeOfDay(hour: h, minute: m);
  }

  static String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final c = context.colors;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              s.remindersTitle,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: c.textHi,
              ),
            ),
            const SizedBox(height: 20),
            for (final h in _habits) _habitCard(h),
          ],
        ),
      ),
    );
  }

  Widget _habitCard(_Habit habit) {
    final s = context.s;
    final c = context.colors;
    final slots = _times[habit.key] ?? const <TimeOfDay>[];
    final enabled = _enabled[habit.key] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: enabled ? c.accent.withValues(alpha: 0.35) : c.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Habit icon in a tinted disc — mint when the habit is on.
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: enabled ? c.accentTint : c.bgBase,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  habit.icon,
                  size: 20,
                  color: enabled ? c.accentDim : c.textLow,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  habit.label(s),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: c.textHi,
                  ),
                ),
              ),
              Switch(
                value: enabled,
                activeThumbColor: c.onAccent,
                activeTrackColor: c.accent,
                onChanged: (v) => _toggle(habit.key, v),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Smoothly grows/shrinks as time pills are added and removed.
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (slots.isEmpty)
                  Text(
                    s.reminderNoTime,
                    style: TextStyle(
                      color: c.textLow,
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                    ),
                  ),
                for (final t in slots)
                  _TimePill(
                    label: _formatTime(t),
                    onDelete: () => _removeTime(habit.key, t),
                  ),
                _AddTimePill(
                  label: s.reminderAddTime,
                  onTap: () => _addTime(habit),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A scheduled-time pill with a clock icon and a tap-to-remove X.
class _TimePill extends StatelessWidget {
  const _TimePill({required this.label, required this.onDelete});

  final String label;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: c.accentTint,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 15, color: c.accentDim),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: c.accentDim,
            ),
          ),
          const SizedBox(width: 2),
          InkWell(
            onTap: onDelete,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Icon(Icons.close, size: 15, color: c.accentDim),
            ),
          ),
        ],
      ),
    );
  }
}

/// The dashed "add time" pill that opens the time picker.
class _AddTimePill extends StatelessWidget {
  const _AddTimePill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: c.bgBase,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: c.textMid),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.textMid,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
