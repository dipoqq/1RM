import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/profile.dart';
import '../state/app_state.dart';
import 'widgets/common.dart' as ui;

/// First-run setup. Shown by [AuthGate] in place of the tabs — not on top of
/// them — for any account that has never completed it, so there is no back
/// gesture and no way around it. The only exit is [_finish] succeeding.
///
/// A single page, not a wizard. Five fields do not need five screens, and a
/// lifter can see the whole ask at once and fill it in one pass. It keeps its
/// own controllers and its own draft of the two enum choices; nothing touches
/// [AppState] until Finish, because a half-filled onboarding must not leave a
/// partial profile in Supabase that the default-metrics logic can no longer
/// tell from a finished one.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.state});

  final AppState state;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _age = TextEditingController();
  final _benchGoal = TextEditingController();

  // The draft. Starts on the same defaults a fresh Profile carries, so the
  // segmented control has a selection from the first frame — but these are
  // deliberately NOT pre-filling the text fields: a lifter must enter their own
  // metrics, which is the entire reason this screen exists.
  Gender _gender = Gender.male;

  bool _busy = false;

  /// Per-field errors, cleared as soon as the user edits. Null means valid.
  String? _heightError;
  String? _weightError;
  String? _ageError;
  String? _benchGoalError;

  @override
  void dispose() {
    _height.dispose();
    _weight.dispose();
    _age.dispose();
    _benchGoal.dispose();
    super.dispose();
  }

  double? _parse(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  /// Validate every field, collect the errors, and only save if all pass.
  ///
  /// Validation is deliberately all-at-once rather than bailing on the first
  /// bad field: a lifter who mistyped two numbers should see both, not fix one
  /// and be told about the next.
  Future<void> _finish() async {
    final s = widget.state.s;

    final height = _parse(_height);
    final weight = _parse(_weight);
    final ageVal = _parse(_age);
    final goal = _parse(_benchGoal);

    final heightErr = height == null ||
            height < kMinHeightCm ||
            height > kMaxHeightCm
        ? s.heightOutOfRange(kMinHeightCm, kMaxHeightCm)
        : null;
    final weightErr = weight == null ||
            weight < kMinWeightKg ||
            weight > kMaxWeightKg
        ? s.weightOutOfRange(kMinWeightKg, kMaxWeightKg)
        : null;
    // Age is whole years; a decimal point in the field is a typo, not a value.
    final ageErr = ageVal == null ||
            ageVal != ageVal.roundToDouble() ||
            ageVal < kMinAge ||
            ageVal > kMaxAge
        ? s.ageOutOfRange(kMinAge, kMaxAge)
        : null;
    final goalErr = goal == null || !Profile.isValidGoal(goal)
        ? s.benchGoalOutOfRange(kMinGoalKg, kMaxGoalKg)
        : null;

    if (heightErr != null ||
        weightErr != null ||
        ageErr != null ||
        goalErr != null) {
      setState(() {
        _heightError = heightErr;
        _weightError = weightErr;
        _ageError = ageErr;
        _benchGoalError = goalErr;
      });
      return;
    }

    setState(() {
      _busy = true;
      _heightError = null;
      _weightError = null;
      _ageError = null;
      _benchGoalError = null;
    });

    try {
      // Not optimistic: the tabs open only once this is actually in Supabase.
      // See AppState.completeOnboarding for why this one write waits.
      await widget.state.completeOnboarding(
        gender: _gender,
        heightCm: height!,
        weightKg: weight!,
        age: ageVal!.round(),
        benchGoalKg: goal!,
      );
      // On success AppState notifies, AuthGate re-runs its branch and swaps this
      // screen for HomeShell — there is nothing to navigate here.
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(widget.state.s.couldNotSave('$e'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.s;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Icon(Icons.fitness_center, size: 40, color: c.accent),
                  const SizedBox(height: 18),
                  Text(
                    s.onboardingTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: c.textHi),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.onboardingSubtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: c.accent),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.onboardingIntro,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13, height: 1.5, color: c.textMid),
                  ),
                  const SizedBox(height: 24),
                  ui.SectionCard(
                    title: s.onboardingBodySection,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ui.GenderToggle(
                          gender: _gender,
                          onChanged: _busy
                              ? (_) {}
                              : (g) => setState(() => _gender = g),
                        ),
                        const SizedBox(height: 14),
                        _field(
                          controller: _height,
                          label: s.height,
                          suffix: s.unitCm,
                          error: _heightError,
                          onChanged: () {
                            if (_heightError != null) {
                              setState(() => _heightError = null);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _weight,
                          label: s.bodyweight,
                          suffix: s.unitKg,
                          error: _weightError,
                          onChanged: () {
                            if (_weightError != null) {
                              setState(() => _weightError = null);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _age,
                          label: s.age,
                          suffix: s.unitYears,
                          error: _ageError,
                          decimal: false,
                          onChanged: () {
                            if (_ageError != null) {
                              setState(() => _ageError = null);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ui.SectionCard(
                    title: s.onboardingGoalSection,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _field(
                          controller: _benchGoal,
                          label: s.benchGoalLabel,
                          suffix: s.unitKg,
                          error: _benchGoalError,
                          onSubmitted: _finish,
                          onChanged: () {
                            if (_benchGoalError != null) {
                              setState(() => _benchGoalError = null);
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        Text(
                          s.onboardingGoalHint,
                          style: TextStyle(
                              fontSize: 12, height: 1.4, color: c.textLow),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _finish,
                    child: _busy
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: c.onAccent),
                          )
                        : Text(s.onboardingFinish),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String suffix,
    required String? error,
    required VoidCallback onChanged,
    bool decimal = true,
    VoidCallback? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      enabled: !_busy,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          decimal ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]'),
        ),
      ],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        errorText: error,
      ),
      onChanged: (_) => onChanged(),
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted(),
    );
  }
}
