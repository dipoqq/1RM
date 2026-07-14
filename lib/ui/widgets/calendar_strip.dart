import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../models/meal.dart';

/// Horizontally scrolling day strip.
///
/// Days run from [daysBack] ago up to today. Future days are not offered —
/// you cannot eat a meal tomorrow, and allowing them would let the diary log
/// entries that the totals could never reconcile.
class CalendarStrip extends StatefulWidget {
  const CalendarStrip({
    super.key,
    required this.selected,
    required this.onSelect,
    this.daysBack = 60,
  });

  final DateTime selected;
  final ValueChanged<DateTime> onSelect;
  final int daysBack;

  @override
  State<CalendarStrip> createState() => _CalendarStripState();
}

class _CalendarStripState extends State<CalendarStrip> {
  static const _itemWidth = 60.0;
  static const _itemGap = 8.0;

  late final ScrollController _scroll;
  late final DateTime _today = Meal.dayOf(DateTime.now());
  late final List<DateTime> _days = List.generate(
    widget.daysBack + 1,
    (i) => _today.subtract(Duration(days: widget.daysBack - i)),
  );

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController(initialScrollOffset: _offsetOf(widget.selected));
  }

  @override
  void didUpdateWidget(CalendarStrip old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      _scrollTo(widget.selected);
    }
  }

  /// Left-align the day, then nudge it toward centre where there is room.
  double _offsetOf(DateTime day) {
    final i = _days.indexWhere((d) => d == Meal.dayOf(day));
    if (i == -1) return 0;
    return (i * (_itemWidth + _itemGap)) - 120;
  }

  void _scrollTo(DateTime day) {
    if (!_scroll.hasClients) return;
    final target =
        _offsetOf(day).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Jump to today's cell after first layout, when maxScrollExtent is known.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients && _scroll.offset == 0) {
        final target =
            _offsetOf(widget.selected).clamp(0.0, _scroll.position.maxScrollExtent);
        if (target > 0) _scroll.jumpTo(target);
      }
    });

    return SizedBox(
      height: 78,
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
            selected: day == Meal.dayOf(widget.selected),
            isToday: day == _today,
            onTap: () => widget.onSelect(day),
          );
        },
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.width,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final DateTime day;
  final double width;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.onAccent : AppColors.textHi;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: width,
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.bgBase,
          borderRadius: BorderRadius.circular(AppRadii.control),
          border: Border.all(
            color: selected
                ? AppColors.accent
                : isToday
                    ? AppColors.accent.withValues(alpha: 0.45)
                    : AppColors.border,
            width: isToday && !selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('E').format(day).toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.onAccent : AppColors.textLow,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
            const SizedBox(height: 3),
            // Today gets a dot so it stays findable after you scroll away.
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isToday
                    ? (selected ? AppColors.onAccent : AppColors.accent)
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
