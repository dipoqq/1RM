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
  String? _goalError;
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Seeded once: refilling on every rebuild (and the language switch causes
    // one) would fight the user while they are typing.
    if (!_seeded) {
      _benchGoalCtrl.text = ui.fmtKg(context.app.profile.benchGoalKg);
      _seeded = true;
    }
  }

  @override
  void dispose() {
    _benchGoalCtrl.dispose();
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
  Future<bool> _commitGoal() async {
    final state = context.app;
    final s = state.s;
    final parsed =
        double.tryParse(_benchGoalCtrl.text.trim().replaceAll(',', '.'));

    if (parsed == null || !Profile.isValidGoal(parsed)) {
      setState(
          () => _goalError = s.benchGoalOutOfRange(kMinGoalKg, kMaxGoalKg));
      return false;
    }
    setState(() => _goalError = null);

    if (parsed == state.profile.benchGoalKg) return true;

    try {
      await state.update(benchGoalKg: parsed);
      return true;
    } catch (e) {
      if (!mounted) return false;
      // update() rolled the profile back; put the field back with it rather
      // than leaving a number on screen that is not the one in force.
      _benchGoalCtrl.text = ui.fmtKg(state.profile.benchGoalKg);
      _snack(s.couldNotSaveSettings('$e'));
      return false;
    }
  }

  /// The Save button. Confirms with a single success SnackBar covering whatever
  /// the user changed — the goal they typed, the language they picked, or both.
  Future<void> _save() async {
    final s = context.app.s;
    final ok = await _commitGoal();
    if (!mounted || !ok) return;
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
                  style: const TextStyle(fontSize: 12, color: AppColors.textLow),
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
                  style: const TextStyle(fontSize: 12, color: AppColors.textLow),
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
                TextField(
                  controller: _benchGoalCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: InputDecoration(
                    labelText: s.benchGoalLabel,
                    suffixText: s.unitKg,
                    errorText: _goalError,
                  ),
                  onSubmitted: (_) => _save(),
                  onTapOutside: (_) {
                    // Tapping away commits silently — the success SnackBar is
                    // the Save button's job, and a toast on every blur would be
                    // noise.
                    _commitGoal();
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  s.benchGoalHint,
                  style: const TextStyle(
                      fontSize: 12, height: 1.4, color: AppColors.textLow),
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
        ],
      ),
    );
  }
}
