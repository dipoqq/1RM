import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/progression.dart';
import '../../core/theme.dart';
import '../../models/workout.dart';
import '../../services/supabase_service.dart';
import '../widgets/adaptive.dart';
import '../widgets/common.dart' as ui;
import '../widgets/confetti.dart';

class TrainingTab extends StatefulWidget {
  const TrainingTab({
    super.key,
    required this.service,
    required this.confetti,
  });

  final SupabaseService service;
  final ConfettiController confetti;

  @override
  State<TrainingTab> createState() => _TrainingTabState();
}

class _TrainingTabState extends State<TrainingTab> {
  final _weightCtrl = TextEditingController();
  final _repsCtrl = TextEditingController(text: '5');
  final _setsCtrl = TextEditingController(text: '3');

  WorkoutHistory _history = const WorkoutHistory([]);
  String _type = WorkoutType.heavy;
  bool _completed = true;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  /// Working weight the warm-up calculator is currently ramping to.
  double _working = 60;

  @override
  void initState() {
    super.initState();
    _weightCtrl.addListener(_onWeightChanged);
    _load();
  }

  @override
  void dispose() {
    _weightCtrl.removeListener(_onWeightChanged);
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    _setsCtrl.dispose();
    super.dispose();
  }

  void _onWeightChanged() {
    final v = double.tryParse(_weightCtrl.text.replaceAll(',', '.'));
    if (v != null && v > 0 && v != _working) setState(() => _working = v);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final history = await widget.service.fetchWorkouts();
      if (!mounted) return;
      setState(() {
        _history = history;
        _loading = false;
        _error = null;
      });
      // Seed the calculator with the recommended weight — already deloaded 10%
      // if the plateau detector has fired.
      final rec = history.recommendedWorkingWeight;
      if (rec != null && _weightCtrl.text.isEmpty) {
        _weightCtrl.text = _fmt(rec);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _log() async {
    final weight = double.tryParse(_weightCtrl.text.replaceAll(',', '.'));
    final reps = int.tryParse(_repsCtrl.text);
    final sets = int.tryParse(_setsCtrl.text);
    if (weight == null || weight <= 0 || reps == null || reps <= 0 ||
        sets == null || sets <= 0) {
      _snack('Enter a weight, reps and sets greater than zero.');
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.service.addWorkout(Workout(
        date: DateTime.now(),
        workoutType: _type,
        weight: weight,
        reps: reps,
        sets: sets,
        completed: _completed,
      ));

      final history = await widget.service.fetchWorkouts();
      if (!mounted) return;
      setState(() {
        _history = history;
        _saving = false;
      });

      await _celebrateIfMilestone(history);
      if (mounted) _snack('Session logged.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Could not save: $e');
    }
  }

  /// Fire confetti the moment a completed session pushes the best 1RM past a
  /// milestone that has never been celebrated.
  ///
  /// The claim is made in the database first: if this milestone was already
  /// banked (e.g. the 80 kg in your existing workout_data.json, or a session
  /// logged on your phone), claimMilestone returns false and nothing fires.
  Future<void> _celebrateIfMilestone(WorkoutHistory history) async {
    final best = history.bestEstimated1rm;
    if (best == null) return;

    // Highest cleared milestone first, so one monster session that clears both
    // celebrates 95 kg rather than 80 kg.
    for (final m in kMilestones.reversed) {
      if (best < m.kg) continue;
      final claimed = await widget.service.claimMilestone(m.kg);
      if (!claimed) continue;
      if (!mounted) return;
      widget.confetti.fire();
      _showMilestoneDialog(m.title, m.subtitle, best);
      return;
    }
  }

  void _showMilestoneDialog(String title, String subtitle, double best) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgBase,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w800, color: AppColors.accent)),
        content: Text(
          '$subtitle\n\nEstimated 1RM: ${best.toStringAsFixed(1)} kg.',
          style: const TextStyle(color: AppColors.textMid, height: 1.5),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to work'),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _load);
    }

    final best = _history.bestEstimated1rm;

    return AdaptiveColumns(
      onRefresh: _load,
      primary: [
        ui.QuoteCard(),
        if (_history.plateauDetected)
          _PlateauBanner(
            streak: _history.failedHeavyStreak,
            from: _history.currentWorkingWeight ?? 0,
            to: _history.recommendedWorkingWeight ?? 0,
            onApply: () {
              final rec = _history.recommendedWorkingWeight;
              if (rec != null) _weightCtrl.text = _fmt(rec);
            },
          ),
        _StatsRow(history: _history, best: best),
        _LogCard(
          weightCtrl: _weightCtrl,
          repsCtrl: _repsCtrl,
          setsCtrl: _setsCtrl,
          type: _type,
          completed: _completed,
          saving: _saving,
          onType: (t) => setState(() => _type = t),
          onCompleted: (v) => setState(() => _completed = v),
          onSubmit: _saving ? null : _log,
        ),
      ],
      secondary: [
        _WarmupCard(working: _working),
        _HistoryCard(
          history: _history,
          onDelete: (w) async {
            if (w.id == null) return;
            await widget.service.deleteWorkout(w.id!);
            await _load();
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _PlateauBanner extends StatelessWidget {
  const _PlateauBanner({
    required this.streak,
    required this.from,
    required this.to,
    required this.onApply,
  });

  final int streak;
  final double from;
  final double to;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return ui.Banner(
      icon: Icons.warning_amber_rounded,
      title: 'Plateau detected — deload block forced',
      message: '$streak consecutive heavy days failed. Grinding the same weight '
          'from here buys nothing but an injury. Drop 10% to '
          '${_TrainingTabState._fmt(to)} kg (from ${_TrainingTabState._fmt(from)} kg), '
          'rebuild momentum, then climb again.',
      color: AppColors.warning,
      tint: AppColors.warningTint,
      action: FilledButton.tonal(
        onPressed: onApply,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.warning,
          foregroundColor: AppColors.onAccent,
          minimumSize: const Size(0, 40),
        ),
        child: Text('Load ${_TrainingTabState._fmt(to)} kg'),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.history, required this.best});

  final WorkoutHistory history;
  final double? best;

  @override
  Widget build(BuildContext context) {
    final b = best ?? 0;
    final progress = (b / kGoalKg).clamp(0.0, 1.0);

    return ui.SectionCard(
      title: 'Estimated 1RM (Epley)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                best == null ? '—' : b.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textHi,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              const Text('kg',
                  style: TextStyle(fontSize: 16, color: AppColors.textLow)),
              const Spacer(),
              _Chip(
                label: '${history.weeksCompleted} weeks',
                color: AppColors.textMid,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(
                b >= kGoalKg
                    ? AppColors.success
                    : b >= kMilestoneKg
                        ? AppColors.accent
                        : AppColors.accentDim,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            b >= kGoalKg
                ? 'Goal cleared — ${kGoalKg.toStringAsFixed(0)} kg is behind you.'
                : '${(kGoalKg - b).toStringAsFixed(1)} kg to the '
                    '${kGoalKg.toStringAsFixed(0)} kg goal.',
            style: const TextStyle(fontSize: 12, color: AppColors.textLow),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.bgBase,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );
}

class _LogCard extends StatelessWidget {
  const _LogCard({
    required this.weightCtrl,
    required this.repsCtrl,
    required this.setsCtrl,
    required this.type,
    required this.completed,
    required this.saving,
    required this.onType,
    required this.onCompleted,
    required this.onSubmit,
  });

  final TextEditingController weightCtrl;
  final TextEditingController repsCtrl;
  final TextEditingController setsCtrl;
  final String type;
  final bool completed;
  final bool saving;
  final ValueChanged<String> onType;
  final ValueChanged<bool> onCompleted;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return ui.SectionCard(
      title: 'Log a session',
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'Workout type'),
            items: [
              for (final t in WorkoutType.all)
                DropdownMenuItem(value: t, child: Text(t)),
            ],
            onChanged: (v) => v == null ? null : onType(v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: weightCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: const InputDecoration(
                      labelText: 'Weight', suffixText: 'kg'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: repsCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Reps'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: setsCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Sets'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            value: completed,
            onChanged: onCompleted,
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.success,
            title: Text(
              completed ? 'All sets completed' : 'Failed / missed reps',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: completed ? AppColors.success : AppColors.danger,
              ),
            ),
            subtitle: const Text(
              'Failed heavy days drive the plateau detector.',
              style: TextStyle(fontSize: 12, color: AppColors.textLow),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onSubmit,
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.onAccent),
                    )
                  : const Text('Log session'),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarmupCard extends StatelessWidget {
  const _WarmupCard({required this.working});

  final double working;

  @override
  Widget build(BuildContext context) {
    final sets = Progression.warmup(working);
    const accents = [
      AppColors.textMid,
      AppColors.success,
      AppColors.accent,
      AppColors.warning,
    ];

    return ui.SectionCard(
      title: 'Warm-up ramp',
      trailing: Text(
        'to ${_TrainingTabState._fmt(working)} kg',
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMid),
      ),
      child: Column(
        children: [
          for (var i = 0; i < sets.length; i++) ...[
            if (i > 0) const Divider(height: 20),
            Row(
              children: [
                Container(
                  width: 4,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accents[i],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 74,
                  child: Text(
                    sets[i].label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textHi),
                  ),
                ),
                Expanded(
                  child: Text(
                    sets[i].purpose,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textLow),
                  ),
                ),
                Text(
                  '${_TrainingTabState._fmt(sets[i].weight)} kg × ${sets[i].reps}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHi),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Every load is snapped to a real 2.5 kg increment and floored at '
            'the empty 20 kg bar.',
            style: TextStyle(fontSize: 11, color: AppColors.textLow),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.history, required this.onDelete});

  final WorkoutHistory history;
  final ValueChanged<Workout> onDelete;

  @override
  Widget build(BuildContext context) {
    final recent = history.all.take(8).toList();

    return ui.SectionCard(
      title: 'Recent sessions',
      child: recent.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No sessions logged yet.',
                  style: TextStyle(color: AppColors.textLow)),
            )
          : Column(
              children: [
                for (var i = 0; i < recent.length; i++) ...[
                  if (i > 0) const Divider(height: 18),
                  _WorkoutRow(w: recent[i], onDelete: () => onDelete(recent[i])),
                ],
              ],
            ),
    );
  }
}

class _WorkoutRow extends StatelessWidget {
  const _WorkoutRow({required this.w, required this.onDelete});

  final Workout w;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = switch (w.workoutType) {
      WorkoutType.heavy => AppColors.accent,
      WorkoutType.volume => AppColors.success,
      _ => AppColors.warning,
    };

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                w.summary,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHi),
              ),
              Text(
                '${DateFormat('MMM d, HH:mm').format(w.date)} · ${w.workoutType}',
                style: const TextStyle(fontSize: 11, color: AppColors.textLow),
              ),
            ],
          ),
        ),
        Icon(
          w.completed ? Icons.check_circle : Icons.cancel,
          size: 18,
          color: w.completed ? AppColors.success : AppColors.danger,
        ),
        IconButton(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline, size: 18),
          color: AppColors.textLow,
          tooltip: 'Delete',
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, color: AppColors.textLow, size: 36),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMid)),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}
