import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../services/local_storage.dart';
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
    await LocalStorage.setReminder(key, value);
    if (!mounted) return;
    setState(() => _enabled[key] = value);
  }

  Future<void> _persistTimes(String key) =>
      LocalStorage.setReminderTimes(key, _times[key]!.map(_formatTime).toList());

  Future<void> _addTime(_Habit habit) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: habit.label(context.s),
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
  }

  Future<void> _removeTime(String key, TimeOfDay time) async {
    setState(() => _times[key]!
        .removeWhere((t) => t.hour == time.hour && t.minute == time.minute));
    await _persistTimes(key);
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

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              s.remindersTitle,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            for (final h in _habits) _habitCard(h),
          ],
        ),
      ),
    );
  }

  Widget _habitCard(_Habit habit) {
    final s = context.s;
    final slots = _times[habit.key] ?? const <TimeOfDay>[];
    final enabled = _enabled[habit.key] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(habit.icon),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    habit.label(s),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                Switch(
                  value: enabled,
                  onChanged: (v) => _toggle(habit.key, v),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (slots.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      s.reminderNoTime,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                for (final t in slots)
                  Chip(
                    label: Text(_formatTime(t)),
                    onDeleted: () => _removeTime(habit.key, t),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(s.reminderAddTime),
                  onPressed: () => _addTime(habit),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
