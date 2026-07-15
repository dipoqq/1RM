import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../core/l10n/app_locale.dart';
import '../core/theme.dart';
import '../models/profile.dart';
import '../state/app_state.dart';
import 'auth_gate.dart' show LanguageToggle;
import 'widgets/common.dart' as ui;

/// Application settings: the language, the lifter's gender and their own bench
/// press goal.
///
/// All three write straight through [AppState], so the Training tab's bar, the
/// Nutrition tab's targets and the whole app's copy change on the same frame —
/// this screen keeps no local copy of any of them beyond the text the user is
/// mid-way through typing.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _benchGoalCtrl = TextEditingController();
  final _squatGoalCtrl = TextEditingController();
  final _deadliftGoalCtrl = TextEditingController();
  String? _goalError;
  String? _squatError;
  String? _deadliftError;
  bool _seeded = false;

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
  /// shows the field's error. Returns false when the field did not parse (so
  /// [_save] does not claim success over an invalid number) or the write failed.
  ///
  /// Every `context`-dependent call is taken before the await or guarded by
  /// [mounted] after it — a back-tap on a slow connection can pop this screen
  /// while a Supabase write is in flight.
  Future<bool> _commit({
    required TextEditingController ctrl,
    required double Function() current,
    required Future<void> Function(double) apply,
    required void Function(String?) setError,
  }) async {
    final s = context.app.s;
    final parsed = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));

    if (parsed == null || !Profile.isValidGoal(parsed)) {
      setError(s.benchGoalOutOfRange(kMinGoalKg, kMaxGoalKg));
      return false;
    }
    setError(null);

    if (parsed == current()) return true;

    try {
      await apply(parsed);
      return true;
    } catch (e) {
      if (!mounted) return false;
      // update() rolled the profile back; put the field back with it rather
      // than leaving a number on screen that is not the one in force.
      ctrl.text = ui.fmtKg(current());
      _snack(s.couldNotSaveSettings('$e'));
      return false;
    }
  }

  Future<bool> _commitGoal() => _commit(
        ctrl: _benchGoalCtrl,
        current: () => context.app.profile.benchGoalKg,
        apply: (v) => context.app.update(benchGoalKg: v),
        setError: (e) => setState(() => _goalError = e),
      );

  Future<bool> _commitSquat() => _commit(
        ctrl: _squatGoalCtrl,
        current: () => context.app.profile.squatGoalKg,
        apply: (v) => context.app.update(squatGoalKg: v),
        setError: (e) => setState(() => _squatError = e),
      );

  Future<bool> _commitDeadlift() => _commit(
        ctrl: _deadliftGoalCtrl,
        current: () => context.app.profile.deadliftGoalKg,
        apply: (v) => context.app.update(deadliftGoalKg: v),
        setError: (e) => setState(() => _deadliftError = e),
      );

  /// The Save button. Commits all three goal fields and confirms with a single
  /// success SnackBar covering whatever the user changed — a typed goal, the
  /// language they picked, or both. An invalid field blocks the success.
  Future<void> _save() async {
    final s = context.app.s;
    final ok = await _commitGoal();
    final okSquat = await _commitSquat();
    final okDeadlift = await _commitDeadlift();
    if (!mounted || !(ok && okSquat && okDeadlift)) return;
    _snack(s.settingsSaved);
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
          ui.SectionCard(
            title: s.benchGoalSection,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GoalField(
                  fieldKey: const Key('benchGoalField'),
                  controller: _benchGoalCtrl,
                  label: s.benchGoalLabel,
                  suffix: s.unitKg,
                  error: _goalError,
                  onSubmitted: _save,
                  onCommit: _commitGoal,
                ),
                const SizedBox(height: 10),
                Text(
                  s.benchGoalHint,
                  style: TextStyle(
                      fontSize: 12, height: 1.4, color: c.textLow),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _save,
                    child: Text(s.save),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Squat & deadlift join bench as first-class targets. Each commits on
          // blur/submit; the shared Save above also flushes all three.
          ui.SectionCard(
            title: s.strengthGoalsSection,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GoalField(
                  fieldKey: const Key('squatGoalField'),
                  controller: _squatGoalCtrl,
                  label: s.squatGoalLabel,
                  suffix: s.unitKg,
                  error: _squatError,
                  onSubmitted: _save,
                  onCommit: _commitSquat,
                ),
                const SizedBox(height: 12),
                _GoalField(
                  fieldKey: const Key('deadliftGoalField'),
                  controller: _deadliftGoalCtrl,
                  label: s.deadliftGoalLabel,
                  suffix: s.unitKg,
                  error: _deadliftError,
                  onSubmitted: _save,
                  onCommit: _commitDeadlift,
                ),
                const SizedBox(height: 10),
                Text(
                  s.strengthGoalsHint,
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
  final Future<bool> Function() onCommit;

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
