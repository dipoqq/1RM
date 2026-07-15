import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../models/workout.dart';
import '../../state/app_state.dart';
import 'common.dart' as ui;

/// A horizontally scrolling training calendar.
///
/// Days that carry a completed session get a subtle mint highlight and a dot;
/// tapping any day opens a bottom sheet listing what was done that day. Built as
/// a horizontal strip (rather than pulling in table_calendar) so it matches the
/// nutrition tab's calendar and needs no extra dependency.
class WorkoutCalendar extends StatefulWidget {
  const WorkoutCalendar({
    super.key,
    required this.history,
    required this.state,
    this.daysBack = 41,
  });

  final WorkoutHistory history;

  /// Needed only to re-establish [AppScope] inside the pushed bottom sheet.
  final AppState state;
  final int daysBack;

  @override
  State<WorkoutCalendar> createState() => _WorkoutCalendarState();
}

class _WorkoutCalendarState extends State<WorkoutCalendar> {
  static const _itemWidth = 52.0;
  static const _itemGap = 8.0;

  late final ScrollController _scroll = ScrollController();
  late final DateTime _today = WorkoutHistory.dayOf(DateTime.now());
  late final List<DateTime> _days = List.generate(
    widget.daysBack + 1,
    (i) => _today.subtract(Duration(days: widget.daysBack - i)),
  );

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Start scrolled to today (the far right) once layout gives us an extent.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients && _scroll.offset == 0) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });

    final completed = widget.history.completedDays;

    return SizedBox(
      height: 74,
      child: ListView.separated(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _days.length,
        separatorBuilder: (_, _) => const SizedBox(width: _itemGap),
        itemBuilder: (context, i) {
          final day = _days[i];
          return _DayCell(
            day: day,
            width: _itemWidth,
            trained: completed.contains(day),
            isToday: day == _today,
            onTap: () => _openDay(day),
          );
        },
      ),
    );
  }

  void _openDay(DateTime day) {
    final workouts = widget.history.onDay(day);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.bgBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AppScope(
        state: widget.state,
        child: WorkoutDaySheet(day: day, workouts: workouts),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.width,
    required this.trained,
    required this.isToday,
    required this.onTap,
  });

  final DateTime day;
  final double width;
  final bool trained;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          // A completed day glows mint; everything else is the flat base.
          color: trained ? c.successTint : c.bgBase,
          borderRadius: BorderRadius.circular(AppRadii.control),
          border: Border.all(
            color: isToday
                ? c.accent.withValues(alpha: 0.6)
                : trained
                    ? c.success.withValues(alpha: 0.4)
                    : c.border,
            width: isToday ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('E', context.s.locale.code).format(day).toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w600,
                color: c.textLow,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: trained ? c.success : c.textHi,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: trained ? c.success : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The day-detail bottom sheet: every session logged on [day], with weight,
/// reps and sets. Empty days say so rather than opening a blank sheet.
class WorkoutDaySheet extends StatelessWidget {
  const WorkoutDaySheet({super.key, required this.day, required this.workouts});

  final DateTime day;
  final List<Workout> workouts;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.s;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              DateFormat('EEEE, MMMM d', s.locale.code).format(day),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: c.textHi,
              ),
            ),
            const SizedBox(height: 16),
            if (workouts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(s.noSessions, style: TextStyle(color: c.textLow)),
              )
            else
              for (var i = 0; i < workouts.length; i++) ...[
                if (i > 0) const Divider(height: 20),
                _WorkoutLine(w: workouts[i]),
              ],
          ],
        ),
      ),
    );
  }
}

class _WorkoutLine extends StatelessWidget {
  const _WorkoutLine({required this.w});

  final Workout w;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.s;

    return Row(
      children: [
        Icon(
          w.completed ? Icons.check_circle : Icons.cancel,
          size: 20,
          color: w.completed ? c.success : c.danger,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                w.exercise.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: c.textHi,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${w.summary(s.unitKg)} · ${s.workoutType(w.workoutType)}',
                style: TextStyle(fontSize: 12, color: c.textLow),
              ),
            ],
          ),
        ),
        Text(
          '${ui.fmtKg(w.estimated1rm)} ${s.unitKg}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: c.accentDim,
          ),
        ),
      ],
    );
  }
}
