import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/progression.dart';
import '../../core/theme.dart';
import '../../models/profile.dart';
import '../../models/workout.dart';
import '../../state/app_state.dart';
import '../widgets/adaptive.dart';
import '../widgets/common.dart' as ui;
import '../widgets/confetti.dart';

class TrainingTab extends StatefulWidget {
  const TrainingTab({
    super.key,
    required this.state,
    required this.confetti,
  });

  final AppState state;
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

  /// Which quote is on screen. Held here, and re-rolled only in [_load], so the
  /// card is stable across rebuilds — a language switch re-renders the SAME
  /// quote, translated, instead of dealing a new one.
  double _quote = ui.QuoteCard.roll();

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
      final history = await widget.state.service.fetchWorkouts();
      if (!mounted) return;
      setState(() {
        _history = history;
        _loading = false;
        _error = null;
        // A refresh is the one moment the lifter asked for a new quote.
        _quote = ui.QuoteCard.roll();
      });
      // Seed the calculator with the recommended weight — already deloaded 10%
      // if the plateau detector has fired.
      final rec = history.recommendedWorkingWeight;
      if (rec != null && _weightCtrl.text.isEmpty) {
        _weightCtrl.text = ui.fmtKg(rec);
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
    final s = context.s;
    final weight = double.tryParse(_weightCtrl.text.replaceAll(',', '.'));
    final reps = int.tryParse(_repsCtrl.text);
    final sets = int.tryParse(_setsCtrl.text);
    if (weight == null || weight <= 0 || reps == null || reps <= 0 ||
        sets == null || sets <= 0) {
      _snack(s.enterPositiveNumbers);
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.state.service.addWorkout(Workout(
        date: DateTime.now(),
        workoutType: _type,
        weight: weight,
        reps: reps,
        sets: sets,
        completed: _completed,
      ));

      final history = await widget.state.service.fetchWorkouts();
      if (!mounted) return;
      setState(() {
        _history = history;
        _saving = false;
      });

      await _celebrateIfMilestone(history);
      if (mounted) _snack(s.sessionLogged);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(s.couldNotSave('$e'));
    }
  }

  /// Fire confetti the moment a completed session pushes the best 1RM past a
  /// milestone that has never been celebrated.
  ///
  /// The milestones are the lifter's own: the fixed 80 kg rubicon plus whatever
  /// bench goal they set in Settings. The claim is made in the database first —
  /// if this milestone was already banked (e.g. the 80 kg in your existing
  /// workout_data.json, or a session logged on your phone), claimMilestone
  /// returns false and nothing fires.
  Future<void> _celebrateIfMilestone(WorkoutHistory history) async {
    final best = history.bestEstimated1rm;
    if (best == null) return;

    // Highest cleared milestone first, so one monster session that clears both
    // celebrates the goal rather than the 80 kg on the way to it.
    for (final m in widget.state.profile.milestones.reversed) {
      if (best < m.kg) continue;
      final claimed = await widget.state.claimMilestone(m.kg);
      if (!claimed) continue;
      if (!mounted) return;
      widget.confetti.fire();
      _showMilestoneDialog(m, best);
      return;
    }
  }

  void _showMilestoneDialog(Milestone milestone, double best) {
    final s = context.s;
    final c = context.colors;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c.bgBase,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        title: Text(
          s.milestoneTitle(ui.fmtKg(milestone.kg)),
          style: TextStyle(
              fontWeight: FontWeight.w800, color: c.accent),
        ),
        content: Text(
          '${s.milestoneSubtitle(milestone.isFinal)}\n\n'
          '${s.milestoneBody(best.toStringAsFixed(1))}',
          style: TextStyle(color: c.textMid, height: 1.5),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.backToWork),
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _load);
    }

    // The goal comes from the profile, so editing it in Settings rebuilds this
    // card — bar, remaining kilos and percentage together — with no refetch.
    final progress =
        context.app.profile.benchProgress(_history.bestEstimated1rm);

    return AdaptiveColumns(
      onRefresh: _load,
      primary: [
        ui.QuoteCard(pick: _quote),
        if (_history.plateauDetected)
          _PlateauBanner(
            streak: _history.failedHeavyStreak,
            from: _history.currentWorkingWeight ?? 0,
            to: _history.recommendedWorkingWeight ?? 0,
            onApply: () {
              final rec = _history.recommendedWorkingWeight;
              if (rec != null) _weightCtrl.text = ui.fmtKg(rec);
            },
          ),
        _StatsRow(history: _history, progress: progress),
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
            await widget.state.service.deleteWorkout(w.id!);
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
    final c = context.colors;
    final s = context.s;

    return ui.Banner(
      icon: Icons.warning_amber_rounded,
      title: s.plateauTitle,
      message: s.plateauMessage(streak, ui.fmtKg(from), ui.fmtKg(to)),
      color: c.warning,
      tint: c.warningTint,
      action: FilledButton.tonal(
        onPressed: onApply,
        style: FilledButton.styleFrom(
          backgroundColor: c.warning,
          foregroundColor: c.onAccent,
          minimumSize: const Size(0, 40),
        ),
        child: Text(s.loadWeight(ui.fmtKg(to))),
      ),
    );
  }
}

/// Estimated 1RM against the lifter's own bench press goal: the number, a bar,
/// the completion percentage and the kilos still to add. Every one of those
/// four comes from the same [BenchProgress], so they cannot contradict each
/// other when the goal changes.
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.history, required this.progress});

  final WorkoutHistory history;
  final BenchProgress progress;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.s;
    final goalKg = ui.fmtKg(progress.goalKg);

    return ui.SectionCard(
      title: s.estimated1rm,
      trailing: _Chip(
        label: s.percentOfGoal(progress.percent),
        color: progress.cleared ? c.success : c.accentDim,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                progress.best == null
                    ? '—'
                    : progress.best!.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: c.textHi,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Text('/ $goalKg ${s.unitKg}',
                  style:
                      TextStyle(fontSize: 16, color: c.textLow)),
              const Spacer(),
              _Chip(
                label: s.weeksCompleted(history.weeksCompleted),
                color: c.textMid,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              // Animated so that raising the goal in Settings visibly *drains*
              // the bar rather than teleporting it.
              tween: Tween(begin: 0, end: progress.ratio),
              duration: const Duration(milliseconds: 550),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: c.border,
                valueColor: AlwaysStoppedAnimation(
                  progress.cleared
                      ? c.success
                      // Thresholds are fractions of the lifter's own goal, not
                      // a hardcoded 80 kg: a 75 kg goal has no "80 kg" stage.
                      : progress.ratio >= 0.85
                          ? c.accent
                          : c.accentDim,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            progress.cleared
                ? s.goalCleared(goalKg)
                : s.remainingToGoal(ui.fmtKg(progress.remainingKg), goalKg),
            style: TextStyle(fontSize: 12, color: c.textLow),
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
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.bgBase,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.border),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
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
    final c = context.colors;
    final s = context.s;

    return ui.SectionCard(
      title: s.logSession,
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: type,
            isExpanded: true,
            decoration: InputDecoration(labelText: s.workoutTypeField),
            items: [
              // The VALUE stays the English string the database stores; only
              // the label is translated.
              for (final t in WorkoutType.all)
                DropdownMenuItem(value: t, child: Text(s.workoutType(t))),
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
                  decoration: InputDecoration(
                      labelText: s.weight, suffixText: s.unitKg),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: repsCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: s.reps),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: setsCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: s.sets),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            value: completed,
            onChanged: onCompleted,
            contentPadding: EdgeInsets.zero,
            activeThumbColor: c.success,
            title: Text(
              completed ? s.allSetsCompleted : s.failedReps,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: completed ? c.success : c.danger,
              ),
            ),
            subtitle: Text(
              s.failedDrivePlateau,
              style:
                  TextStyle(fontSize: 12, color: c.textLow),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onSubmit,
              child: saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: c.onAccent),
                    )
                  : Text(s.logSessionButton),
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
    final c = context.colors;
    final s = context.s;
    final sets = Progression.warmup(working);
    final accents = [
      c.textMid,
      c.success,
      c.accent,
      c.warning,
    ];

    return ui.SectionCard(
      title: s.warmupRamp,
      trailing: Text(
        s.warmupTo(ui.fmtKg(working)),
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: c.textMid),
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
                  width: 92,
                  child: Text(
                    s.warmupLabel(sets[i].stage),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: c.textHi),
                  ),
                ),
                Expanded(
                  child: Text(
                    s.warmupPurpose(sets[i].stage),
                    style: TextStyle(
                        fontSize: 12, color: c.textLow),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${ui.fmtKg(sets[i].weight)} ${s.unitKg} × ${sets[i].reps}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.textHi),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Text(
            s.warmupFootnote,
            style: TextStyle(fontSize: 11, color: c.textLow),
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
    final c = context.colors;
    final s = context.s;
    final recent = history.all.take(8).toList();

    return ui.SectionCard(
      title: s.recentSessions,
      child: recent.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(s.noSessions,
                  style: TextStyle(color: c.textLow)),
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
    final c = context.colors;
    final AppStrings s = context.s;
    final color = switch (w.workoutType) {
      WorkoutType.heavy => c.accent,
      WorkoutType.volume => c.success,
      _ => c.warning,
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
                w.summary(s.unitKg),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.textHi),
              ),
              Text(
                // Month names follow the language too, hence the locale code.
                '${DateFormat('MMM d, HH:mm', s.locale.code).format(w.date)} · '
                '${s.workoutType(w.workoutType)}',
                style: TextStyle(fontSize: 11, color: c.textLow),
              ),
            ],
          ),
        ),
        Icon(
          w.completed ? Icons.check_circle : Icons.cancel,
          size: 18,
          color: w.completed ? c.success : c.danger,
        ),
        IconButton(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline, size: 18),
          color: c.textLow,
          tooltip: s.delete,
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
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, color: c.textLow, size: 36),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textMid)),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: Text(context.s.retry)),
          ],
        ),
      ),
    );
  }
}
