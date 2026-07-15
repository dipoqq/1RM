import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../models/workout.dart';
import '../../state/app_state.dart';
import '../widgets/adaptive.dart';
import '../widgets/common.dart' as ui;

/// A single personal-record step: the session that first pushed the estimated
/// 1RM higher than everything before it.
class _Pr {
  const _Pr({required this.date, required this.value, required this.sinceStart});
  final DateTime date;
  final double value;

  /// How much higher than the very first logged session, in kg.
  final double sinceStart;
}

/// Tab 4 — analytics. An estimated-1RM line chart over time plus the list of
/// personal records, filtered by the same active exercise the Training tab uses.
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key, required this.state});

  final AppState state;

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  WorkoutHistory _history = const WorkoutHistory([]);
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final history = await widget.state.service.fetchWorkouts();
      if (!mounted) return;
      setState(() {
        _history = history;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  /// Completed sessions for [exercise], oldest first (charts read left→right).
  List<Workout> _sessions(Exercise exercise) => _history
      .forExercise(exercise)
      .all
      .where((w) => w.completed)
      .toList()
      .reversed
      .toList();

  double _goalFor(Exercise exercise) => switch (exercise) {
        Exercise.benchPress => widget.state.profile.benchGoalKg,
        Exercise.squat => widget.state.profile.squatGoalKg,
        Exercise.deadlift => widget.state.profile.deadliftGoalKg,
      };

  /// The record ladder: each session whose 1RM beat the running best.
  List<_Pr> _prs(List<Workout> sessions) {
    if (sessions.isEmpty) return const [];
    final baseline = sessions.first.estimated1rm;
    final prs = <_Pr>[];
    double? best;
    for (final s in sessions) {
      final e = s.estimated1rm;
      if (best == null || e > best + 0.01) {
        best = e;
        prs.add(_Pr(date: s.date, value: e, sinceStart: e - baseline));
      }
    }
    return prs.reversed.toList(); // newest record first
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }

    // Subscribe to the shared active exercise so the Training tab's segmented
    // button and this one stay in step.
    final exercise = context.app.activeExercise;
    final sessions = _sessions(exercise);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<Exercise>(
              segments: const [
                ButtonSegment(value: Exercise.benchPress, label: Text('Bench')),
                ButtonSegment(value: Exercise.squat, label: Text('Squat')),
                ButtonSegment(value: Exercise.deadlift, label: Text('Deadlift')),
              ],
              selected: {exercise},
              onSelectionChanged: (set) =>
                  widget.state.setActiveExercise(set.first),
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                textStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        Expanded(
          child: sessions.isEmpty
              ? _EmptyState(message: s.historyNoData)
              : AdaptiveColumns(
                  onRefresh: _load,
                  primary: [
                    ui.SectionCard(
                      title: s.historyChartTitle,
                      child: _OneRmChart(
                        sessions: sessions,
                        goalKg: _goalFor(exercise),
                      ),
                    ),
                  ],
                  secondary: [
                    ui.SectionCard(
                      title: s.historyPersonalRecords,
                      child: _PrList(prs: _prs(sessions)),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart, size: 48, color: c.textLow),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMid),
            ),
          ],
        ),
      ),
    );
  }
}

class _OneRmChart extends StatelessWidget {
  const _OneRmChart({required this.sessions, required this.goalKg});

  final List<Workout> sessions;
  final double goalKg;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final spots = <FlSpot>[
      for (var i = 0; i < sessions.length; i++)
        FlSpot(i.toDouble(), sessions[i].estimated1rm),
    ];

    final values = sessions.map((w) => w.estimated1rm);
    final dataMax = values.reduce(math.max);
    final dataMin = values.reduce(math.min);
    // Leave headroom, and always keep the goal line in frame.
    final maxY = (math.max(dataMax, goalKg) + 5).ceilToDouble();
    final minY = math.max(0, dataMin - 5).floorToDouble();
    final maxX = (sessions.length - 1).toDouble();

    // Show at most ~4 date labels so the axis never crowds.
    final labelStep = math.max(1, (sessions.length / 4).ceil());

    return AspectRatio(
      aspectRatio: 1.5,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX == 0 ? 1 : maxX,
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: math.max(1, (maxY - minY) / 4),
            getDrawingHorizontalLine: (_) =>
                FlLine(color: c.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: math.max(1, (maxY - minY) / 4),
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: TextStyle(color: c.textLow, fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i >= sessions.length) {
                    return const SizedBox.shrink();
                  }
                  // Sample: first, last, and every labelStep in between.
                  final isEdge = i == 0 || i == sessions.length - 1;
                  if (!isEdge && i % labelStep != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      DateFormat('d/M').format(sessions[i].date),
                      style: TextStyle(color: c.textLow, fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          // The goal, as a dashed horizontal line.
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: goalKg,
                color: c.warning,
                strokeWidth: 1.5,
                dashArray: [6, 4],
              ),
            ],
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.25,
              color: c.accent,
              barWidth: 3,
              dotData: FlDotData(
                show: sessions.length <= 12,
                getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                  radius: 3,
                  color: c.accent,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: c.accent.withValues(alpha: 0.12),
              ),
            ),
          ],
          lineTouchData: const LineTouchData(enabled: true),
        ),
      ),
    );
  }
}

class _PrList extends StatelessWidget {
  const _PrList({required this.prs});
  final List<_Pr> prs;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.s;

    return Column(
      children: [
        for (final pr in prs)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(Icons.emoji_events, size: 18, color: c.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${ui.fmtKg(pr.value)} ${s.unitKg}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: c.textHi,
                        ),
                      ),
                      Text(
                        DateFormat.yMMMd(s.locale.code).format(pr.date),
                        style: TextStyle(fontSize: 12, color: c.textLow),
                      ),
                    ],
                  ),
                ),
                if (pr.sinceStart > 0.01)
                  Text(
                    s.historySinceStart(ui.fmtKg(pr.sinceStart)),
                    style: TextStyle(
                      color: c.accentDim,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
