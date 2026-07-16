import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../core/l10n/app_locale.dart';
import '../core/theme.dart';
import '../models/profile.dart';
import '../models/workout.dart';
import '../services/widget_service.dart';
import '../state/app_state.dart';
import 'auth_gate.dart' show LanguageToggle;
import 'widgets/common.dart' as ui;

/// Application settings: the language, the lifter's gender, their goals for
/// the three primary lifts, and which of those lifts the home-screen widget
/// tracks.
///
/// The profile-backed settings write straight through [AppState], so the
/// Training tab's bar, the Nutrition tab's targets and the whole app's copy
/// change on the same frame — this screen keeps no local copy of any of them
/// beyond the text the user is mid-way through typing. The widget's tracked
/// lift is device-local (SharedPreferences), like the widget itself.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

/// What committing one goal field amounted to: a real write ([saved]), a value
/// already in force ([unchanged]), or a rejection — invalid input or a failed
/// write ([rejected]). [_SettingsScreenState._save] uses the distinction to
/// name the lift that actually changed in its confirmation.
enum _CommitResult { saved, unchanged, rejected }

class _SettingsScreenState extends State<SettingsScreen> {
  final _benchGoalCtrl = TextEditingController();
  final _squatGoalCtrl = TextEditingController();
  final _deadliftGoalCtrl = TextEditingController();
  String? _goalError;
  String? _squatError;
  String? _deadliftError;
  bool _seeded = false;

  /// The lift the home-screen strength widget tracks. Seeded from the local
  /// preference in [initState]; bench until the read lands.
  Exercise _widgetExercise = Exercise.benchPress;

  /// Goals written since the last success SnackBar. Fed by every commit —
  /// including the silent tap-away ones — and drained by [_save], so the
  /// confirmation can name the lift that changed even though tapping the Save
  /// button blurs the field and commits it BEFORE the button's own commit
  /// runs (which then sees the value already in force).
  final Set<Exercise> _savedSinceConfirm = {};

  @override
  void initState() {
    super.initState();
    _loadWidgetExercise();
  }

  Future<void> _loadWidgetExercise() async {
    final exercise = await WidgetService.selectedExercise();
    if (!mounted || exercise == _widgetExercise) return;
    setState(() => _widgetExercise = exercise);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Seeded once: refilling on every rebuild (and the language switch causes
    // one) would fight the user while they are typing.
    if (!_seeded) {
      final p = context.app.profile;
      _benchGoalCtrl.text = ui.fmtKg(p.benchGoalKg);
      _squatGoalCtrl.text = ui.fmtKg(p.squatGoalKg);
      _deadliftGoalCtrl.text = ui.fmtKg(p.deadliftGoalKg);
      _seeded = true;
    }
  }

  @override
  void dispose() {
    _benchGoalCtrl.dispose();
    _squatGoalCtrl.dispose();
    _deadliftGoalCtrl.dispose();
    super.dispose();
  }

  /// Persist the typed goal. Returns false when the field did not parse, so
  /// [_save] knows not to claim success over an invalid number.
  ///
  /// Every `context`-dependent call below is either taken BEFORE the await or
  /// guarded by [mounted] after it. The screen can be popped while the Supabase
  /// write is in flight — a back-tap on a slow connection is enough — and
  /// reaching for `ScaffoldMessenger.of(context)` on the far side of that await
  /// is what produced "Looking up a deactivated widget's ancestor is unsafe".
  /// Parse, validate, and persist one goal field. Generic over the three lifts:
  /// [current] reads the value in force, [apply] writes the new one, [setError]
  /// shows the field's error. Reports [_CommitResult.rejected] when the field
  /// did not parse (so [_save] does not claim success over an invalid number)
  /// or the write failed, and distinguishes a real write ([_CommitResult.saved])
  /// from a field left as it already was ([_CommitResult.unchanged]) so the
  /// success SnackBar can name the lift that actually moved.
  ///
  /// Every `context`-dependent call is taken before the await or guarded by
  /// [mounted] after it — a back-tap on a slow connection can pop this screen
  /// while a Supabase write is in flight.
  Future<_CommitResult> _commit({
    required Exercise exercise,
    required TextEditingController ctrl,
    required double Function() current,
    required Future<void> Function(double) apply,
    required void Function(String?) setError,
  }) async {
    final s = context.app.s;
    final parsed = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));

    if (parsed == null || !Profile.isValidGoal(parsed)) {
      setError(s.benchGoalOutOfRange(kMinGoalKg, kMaxGoalKg));
      return _CommitResult.rejected;
    }
    setError(null);

    if (parsed == current()) return _CommitResult.unchanged;

    try {
      await apply(parsed);
      // Remembered until the next success SnackBar drains it, so the
      // confirmation names this lift even when the write happened on the
      // tap-away that preceded the Save press.
      _savedSinceConfirm.add(exercise);
      return _CommitResult.saved;
    } catch (e) {
      if (!mounted) return _CommitResult.rejected;
      // update() rolled the profile back; put the field back with it rather
      // than leaving a number on screen that is not the one in force.
      ctrl.text = ui.fmtKg(current());
      _snack(s.couldNotSaveSettings('$e'));
      return _CommitResult.rejected;
    }
  }

  Future<_CommitResult> _commitGoal() => _commit(
        exercise: Exercise.benchPress,
        ctrl: _benchGoalCtrl,
        current: () => context.app.profile.benchGoalKg,
        apply: (v) => context.app.update(benchGoalKg: v),
        setError: (e) => setState(() => _goalError = e),
      );

  Future<_CommitResult> _commitSquat() => _commit(
        exercise: Exercise.squat,
        ctrl: _squatGoalCtrl,
        current: () => context.app.profile.squatGoalKg,
        apply: (v) => context.app.update(squatGoalKg: v),
        setError: (e) => setState(() => _squatError = e),
      );

  Future<_CommitResult> _commitDeadlift() => _commit(
        exercise: Exercise.deadlift,
        ctrl: _deadliftGoalCtrl,
        current: () => context.app.profile.deadliftGoalKg,
        apply: (v) => context.app.update(deadliftGoalKg: v),
        setError: (e) => setState(() => _deadliftError = e),
      );

  /// The Save button. Commits all three goal fields and confirms with a single
  /// success SnackBar. An invalid field blocks the success.
  ///
  /// The confirmation names the lift whose goal actually changed — saving the
  /// squat goal must say "squat", never claim a bench press update. Keyed off
  /// what was WRITTEN since the last confirmation ([_savedSinceConfirm]), not
  /// off which section's button was pressed: every Save commits all three
  /// fields, and the write itself may already have happened on the tap-away
  /// that blurred the field a moment before this button's own commit ran.
  /// When several goals land at once (or nothing changed at all) the generic
  /// message covers it.
  Future<void> _save() async {
    final s = context.app.s;
    final bench = await _commitGoal();
    final squat = await _commitSquat();
    final deadlift = await _commitDeadlift();
    if (!mounted ||
        bench == _CommitResult.rejected ||
        squat == _CommitResult.rejected ||
        deadlift == _CommitResult.rejected) {
      return;
    }

    final changed = _savedSinceConfirm.toList();
    _savedSinceConfirm.clear();
    _snack(changed.length == 1
        ? s.goalSaved(changed.single)
        : s.settingsSaved);
  }

  Future<void> _setLocale(AppLocale locale) async {
    final state = context.app;
    try {
      await state.update(locale: locale);
    } catch (e) {
      if (!mounted) return;
      _snack(state.s.couldNotSaveSettings('$e'));
    }
  }

  Future<void> _setTheme(AppThemeMode mode) async {
    final state = context.app;
    try {
      // Optimistic, like the language: the repaint lands on this frame and the
      // write follows. A theme switch that waited for Supabase would feel like
      // a bug in the switch.
      await state.update(themeMode: mode);
    } catch (e) {
      if (!mounted) return;
      _snack(state.s.couldNotSaveSettings('$e'));
    }
  }

  /// Persist which lift the strength widget tracks, then repaint the widget
  /// with that lift's numbers right away — switching from bench to squat must
  /// not leave bench's bar on the home screen until the next workout is logged.
  Future<void> _setWidgetExercise(Exercise exercise) async {
    final state = context.app;
    setState(() => _widgetExercise = exercise);
    await WidgetService.setSelectedExercise(exercise);
    unawaited(state.refreshWidgets());
  }

  Future<void> _setGender(Gender gender) async {
    final state = context.app;
    try {
      await state.update(gender: gender);
      if (!mounted) return;
      _snack(state.s.settingsSaved);
    } catch (e) {
      if (!mounted) return;
      _snack(state.s.couldNotSaveSettings('$e'));
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.s;
    final state = context.app;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.settings,
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          ui.SectionCard(
            title: s.language,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LanguageToggle(
                  locale: state.locale,
                  onChanged: _setLocale,
                ),
                const SizedBox(height: 10),
                Text(
                  s.languageHint,
                  style: TextStyle(fontSize: 12, color: c.textLow),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ui.SectionCard(
            title: s.theme,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ui.ThemeToggle(
                  mode: state.themeMode,
                  onChanged: _setTheme,
                ),
                const SizedBox(height: 10),
                Text(
                  s.themeHint,
                  style: TextStyle(fontSize: 12, color: c.textLow),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ui.SectionCard(
            title: s.gender,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ui.GenderToggle(
                  gender: state.profile.gender,
                  onChanged: _setGender,
                ),
                const SizedBox(height: 10),
                Text(
                  s.genderHint,
                  style: TextStyle(fontSize: 12, color: c.textLow),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // The three primary lifts, each in an IDENTICAL section: field, hint,
          // Save button. Any Save commits all three fields (plus whatever else
          // changed), so it never matters which of the buttons was pressed.
          _GoalSection(
            title: s.benchGoalSection,
            fieldKey: const Key('benchGoalField'),
            controller: _benchGoalCtrl,
            label: s.benchGoalLabel,
            hint: s.benchGoalHint,
            error: _goalError,
            onSave: _save,
            onCommit: _commitGoal,
          ),
          const SizedBox(height: 16),
          _GoalSection(
            title: s.squatGoalSection,
            fieldKey: const Key('squatGoalField'),
            controller: _squatGoalCtrl,
            label: s.squatGoalLabel,
            hint: s.squatGoalHint,
            error: _squatError,
            onSave: _save,
            onCommit: _commitSquat,
          ),
          const SizedBox(height: 16),
          _GoalSection(
            title: s.deadliftGoalSection,
            fieldKey: const Key('deadliftGoalField'),
            controller: _deadliftGoalCtrl,
            label: s.deadliftGoalLabel,
            hint: s.deadliftGoalHint,
            error: _deadliftError,
            onSave: _save,
            onCommit: _commitDeadlift,
          ),
          const SizedBox(height: 16),
          // Which lift the home-screen strength widget tracks. Device-local:
          // the widget lives on this device's launcher, not in the profile.
          ui.SectionCard(
            title: s.widgetSection,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<Exercise>(
                    segments: [
                      for (final e in Exercise.values)
                        ButtonSegment(
                          value: e,
                          label: Text(
                            s.exerciseName(e),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    selected: {_widgetExercise},
                    onSelectionChanged: (set) => _setWidgetExercise(set.first),
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      textStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  s.widgetExerciseHint,
                  style: TextStyle(
                      fontSize: 12, height: 1.4, color: c.textLow),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One primary lift's goal card: the target-1RM field, its hint, and the same
/// full-width Save button in every card — bench, squat and deadlift get the
/// exact same layout, so no lift reads as a second-class target.
class _GoalSection extends StatelessWidget {
  const _GoalSection({
    required this.title,
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.hint,
    required this.error,
    required this.onSave,
    required this.onCommit,
  });

  final String title;
  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? error;
  final VoidCallback onSave;
  final Future<_CommitResult> Function() onCommit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.s;

    return ui.SectionCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GoalField(
            fieldKey: fieldKey,
            controller: controller,
            label: label,
            suffix: s.unitKg,
            error: error,
            onSubmitted: onSave,
            onCommit: onCommit,
          ),
          const SizedBox(height: 10),
          Text(
            hint,
            style: TextStyle(fontSize: 12, height: 1.4, color: c.textLow),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onSave,
              child: Text(s.save),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single target-1RM input: numeric, commits on submit and on tap-away.
class _GoalField extends StatelessWidget {
  const _GoalField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.suffix,
    required this.error,
    required this.onSubmitted,
    required this.onCommit,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final String suffix;
  final String? error;
  final VoidCallback onSubmitted;
  final Future<_CommitResult> Function() onCommit;

  @override
  Widget build(BuildContext context) => TextField(
        key: fieldKey,
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          errorText: error,
        ),
        onSubmitted: (_) => onSubmitted(),
        onTapOutside: (_) {
          // Tapping away commits silently — the success SnackBar is the Save
          // button's job, and a toast on every blur would be noise.
          onCommit();
          FocusManager.instance.primaryFocus?.unfocus();
        },
      );
}
