import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/meal.dart';
import '../../models/profile.dart';
import '../../services/gemini_service.dart';
import '../../services/local_storage.dart';
import '../../state/app_state.dart';
import '../widgets/adaptive.dart';
import '../widgets/calendar_strip.dart';
import '../widgets/common.dart' as ui;

class NutritionTab extends StatefulWidget {
  const NutritionTab({super.key, required this.state});

  final AppState state;

  @override
  State<NutritionTab> createState() => _NutritionTabState();
}

class _NutritionTabState extends State<NutritionTab> {
  final _gemini = GeminiService();
  final _picker = ImagePicker();
  final _describeCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();

  /// The day the diary is showing. Defaults to today — this is the "midnight
  /// reset": a new calendar day starts empty, and yesterday's meals stay in
  /// Supabase under yesterday's date rather than carrying over.
  DateTime _selected = Meal.dayOf(DateTime.now());

  List<Meal> _meals = const [];
  bool _loading = true;
  bool _analyzing = false;

  Uint8List? _image;
  String _imageMime = 'image/jpeg';
  String? _analysis;

  /// The profile lives in AppState, not here — the bench goal and the language
  /// on it are read by the Training tab and the shell as well, and two copies
  /// of one row is how they drift apart.
  Profile get _profile => widget.state.profile;

  DateTime get _today => Meal.dayOf(DateTime.now());
  bool get _isToday => _selected == _today;

  @override
  void initState() {
    super.initState();
    _load();
    LocalStorage.init().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _describeCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await widget.state.load();
      final meals = await widget.state.service.fetchMeals(_selected);
      if (!mounted) return;
      setState(() {
        _meals = meals;
        _loading = false;
      });
      // Only seed the fields on first load; refilling them on every refresh
      // would fight the user while they are typing.
      if (_weightCtrl.text.isEmpty) {
        _weightCtrl.text = ui.fmtKg(_profile.weightKg);
      }
      if (_heightCtrl.text.isEmpty) {
        _heightCtrl.text = ui.fmtKg(_profile.heightCm);
      }
      if (_ageCtrl.text.isEmpty) {
        _ageCtrl.text = _profile.age.toString();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(context.s.couldNotLoad('$e'));
    }
  }

  /// Selecting a date reloads that day's meals; the rings follow from them.
  Future<void> _selectDay(DateTime day) async {
    setState(() {
      _selected = Meal.dayOf(day);
      _meals = const [];
      _loading = true;
      _analysis = null;
    });
    final meals = await widget.state.service.fetchMeals(_selected);
    if (!mounted) return;
    setState(() {
      _meals = meals;
      _loading = false;
    });
  }

  Future<void> _saveProfile({
    double? weight,
    double? height,
    int? age,
    Gender? gender,
    Goal? goal,
    ActivityLevel? activity,
  }) async {
    try {
      await widget.state.update(
        weightKg: weight,
        heightCm: height,
        age: age,
        gender: gender,
        goal: goal,
        activity: activity,
      );
    } catch (e) {
      if (mounted) _snack(context.s.couldNotSaveSettings('$e'));
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _image = bytes;
        _imageMime = file.mimeType ??
            (file.path.toLowerCase().endsWith('.png')
                ? 'image/png'
                : 'image/jpeg');
      });
    } catch (e) {
      if (mounted) _snack(context.s.couldNotOpenPicker('$e'));
    }
  }

  /// Run the Gemini call off the UI thread; the button spins and is disabled
  /// throughout, so the rest of the tab stays interactive.
  Future<void> _analyze() async {
    final s = context.s;
    if (!GeminiService.isConfigured) {
      _snack(s.geminiNotConfigured);
      return;
    }
    if (_describeCtrl.text.trim().isEmpty && _image == null) {
      _snack(s.describeOrPhoto);
      return;
    }

    setState(() {
      _analyzing = true;
      _analysis = null;
    });

    // Captured before the await: the meal is logged against the day that was
    // selected when the user pressed Analyze, even if they scroll the strip
    // while the request is in flight.
    final day = _selected;

    try {
      final result = await _gemini.analyze(
        text: _describeCtrl.text,
        image: _image,
        imageMime: _imageMime,
        // The signed-in user's own body — height, weight, age and gender all
        // reach the prompt from here.
        profile: _profile,
        eaten: MacroTotals.of(_meals),
        day: day,
        // Gemini answers in the language the app is being read in.
        strings: s,
      );

      if (!mounted) return;
      setState(() => _analysis = result.prose);

      final meal = result.meal;
      if (meal == null) {
        setState(() => _analyzing = false);
        _snack(s.geminiNoDataBlock);
        return;
      }

      await widget.state.service.addMeal(meal);
      final meals = await widget.state.service.fetchMeals(day);
      if (!mounted) return;
      setState(() {
        // Guard against the user having switched days mid-flight.
        if (day == _selected) _meals = meals;
        _analyzing = false;
        _describeCtrl.clear();
        _image = null;
      });
      _snack(s.mealLogged(meal.name, meal.calories.round()));
    } catch (e) {
      if (!mounted) return;
      setState(() => _analyzing = false);
      _snack(s.analysisFailed('$e'));
    }
  }

  Future<void> _addManual(Meal meal) async {
    await widget.state.service.addMeal(meal);
    final meals = await widget.state.service.fetchMeals(_selected);
    if (!mounted) return;
    setState(() => _meals = meals);
  }

  Future<void> _clearDay() async {
    final s = context.s;
    final c = context.colors;
    final label = DateFormat('MMMM d', s.locale.code).format(_selected);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c.bgBase,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        title: Text(s.clearDayTitle),
        content: Text(
          s.clearDayBody(_meals.length, label),
          style: TextStyle(color: c.textMid, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: c.danger),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await widget.state.service.clearDay(_selected);
    if (!mounted) return;
    setState(() => _meals = const []);
    _snack(s.dayCleared(label));
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
    // Subscribes this tab to the profile: a bodyweight edit, or a language
    // switch made over in Settings, rebuilds the targets and the copy here.
    final profile = context.app.profile;
    final totals = MacroTotals.of(_meals);
    final targets = profile.targets;

    return AdaptiveColumns(
      onRefresh: _load,
      header: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: CalendarStrip(selected: _selected, onSelect: _selectDay),
      ),
      primary: [
        if (!_isToday)
          ui.Banner(
            icon: Icons.history,
            title: s.viewingHistory(
                DateFormat('MMMM d, y', s.locale.code).format(_selected)),
            message: s.viewingHistoryBody,
            color: c.warning,
            tint: c.warningTint,
            action: FilledButton.tonal(
              onPressed: () => _selectDay(_today),
              style: FilledButton.styleFrom(
                backgroundColor: c.warning,
                foregroundColor: c.onAccent,
                minimumSize: const Size(0, 40),
              ),
              child: Text(s.backToToday),
            ),
          ),
        _GoalsCard(
          weightCtrl: _weightCtrl,
          heightCtrl: _heightCtrl,
          ageCtrl: _ageCtrl,
          profile: profile,
          onWeight: (w) => _saveProfile(weight: w),
          onHeight: (h) => _saveProfile(height: h),
          onAge: (a) => _saveProfile(age: a),
          onGender: (g) => _saveProfile(gender: g),
          onGoal: (g) => _saveProfile(goal: g),
          onActivity: (a) => _saveProfile(activity: a),
        ),
        _RingsCard(
          title: _isToday
              ? s.today
              : DateFormat('EEEE, MMM d', s.locale.code).format(_selected),
          loading: _loading,
          totals: totals,
          targets: targets,
        ),
        _HydrationCard(
          day: _selected,
          profile: profile,
          onAdd: () async {
            await LocalStorage.addWaterMl(_selected, 250);
            if (mounted) setState(() {});
          },
          onRemove: () async {
            await LocalStorage.addWaterMl(_selected, -250);
            if (mounted) setState(() {});
          },
        ),
      ],
      secondary: [
        _AnalyzeCard(
          describeCtrl: _describeCtrl,
          image: _image,
          analyzing: _analyzing,
          analysis: _analysis,
          onPick: _pickImage,
          onClearImage: () => setState(() => _image = null),
          onAnalyze: _analyzing ? null : _analyze,
          onManual: () => _openManualSheet(context),
        ),
        _MealsCard(
          meals: _meals,
          onClearDay: _meals.isEmpty ? null : _clearDay,
          onDelete: (m) async {
            if (m.id == null) return;
            await widget.state.service.deleteMeal(m.id!);
            final meals = await widget.state.service.fetchMeals(_selected);
            if (!mounted) return;
            setState(() => _meals = meals);
          },
        ),
      ],
    );
  }

  void _openManualSheet(BuildContext context) {
    final c = context.colors;
    final state = widget.state;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.bgBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      // A sheet is its own route, so the scope has to be re-established for
      // context.s to resolve inside it.
      builder: (context) => AppScope(
        state: state,
        child: _ManualMealSheet(
          day: _selected,
          onSubmit: (meal) async {
            Navigator.pop(context);
            await _addManual(meal);
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _GoalsCard extends StatelessWidget {
  const _GoalsCard({
    required this.weightCtrl,
    required this.heightCtrl,
    required this.ageCtrl,
    required this.profile,
    required this.onWeight,
    required this.onHeight,
    required this.onAge,
    required this.onGender,
    required this.onGoal,
    required this.onActivity,
  });

  final TextEditingController weightCtrl;
  final TextEditingController heightCtrl;
  final TextEditingController ageCtrl;
  final Profile profile;
  final ValueChanged<double> onWeight;
  final ValueChanged<double> onHeight;
  final ValueChanged<int> onAge;
  final ValueChanged<Gender> onGender;
  final ValueChanged<Goal> onGoal;
  final ValueChanged<ActivityLevel> onActivity;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.s;
    final t = profile.targets;

    return ui.SectionCard(
      title: s.dailyTargets,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _MeasureField(
                  controller: weightCtrl,
                  label: s.bodyweight,
                  suffix: s.unitKg,
                  current: profile.weightKg,
                  onCommit: onWeight,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MeasureField(
                  controller: heightCtrl,
                  label: s.height,
                  suffix: s.unitCm,
                  current: profile.heightCm,
                  onCommit: onHeight,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MeasureField(
                  controller: ageCtrl,
                  label: s.age,
                  suffix: s.unitYears,
                  decimal: false,
                  current: profile.age.toDouble(),
                  onCommit: (v) => onAge(v.round()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Above the activity level, because it belongs with the body metrics
          // it is measured with: gender picks which Mifflin-St Jeor equation
          // the BMR line below is computed from, so a change here visibly moves
          // every number in this card.
          Text(
            s.gender,
            style: TextStyle(fontSize: 12, color: c.textLow),
          ),
          const SizedBox(height: 6),
          ui.GenderToggle(
            gender: profile.gender,
            onChanged: onGender,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ActivityLevel>(
            initialValue: profile.activity,
            isExpanded: true,
            decoration: InputDecoration(labelText: s.activityLevel),
            items: [
              for (final a in ActivityLevel.values)
                DropdownMenuItem(
                  value: a,
                  child: Text(
                    '${s.activityLabel(a)} · ${s.activityDescription(a)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (a) => a == null ? null : onActivity(a),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Goal>(
            initialValue: profile.goal,
            isExpanded: true,
            decoration: InputDecoration(labelText: s.goal),
            items: [
              for (final g in Goal.values)
                DropdownMenuItem(
                  value: g,
                  child: Text('${s.goalLabel(g)} · ${s.goalDelta(g)}'),
                ),
            ],
            onChanged: (g) => g == null ? null : onGoal(g),
          ),

          // The arithmetic, shown rather than hidden: the lifter can see that a
          // target moved because his weight moved, not because the app guessed.
          const SizedBox(height: 14),
          Text(
            s.bmrLine(
              t.bmr.round(),
              profile.activity.multiplier,
              s.activityLabel(profile.activity),
              t.tdee.round(),
            ),
            style: TextStyle(fontSize: 11, color: c.textLow),
          ),

          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _TargetTile(
                  value: '${t.kcal}',
                  unit: s.unitKcal,
                  detail: s.tdeeAnd(s.goalDelta(profile.goal)),
                  color: c.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TargetTile(
                  value: '${t.protein}',
                  unit: s.gProtein,
                  detail: s.proteinPerKg(ui.fmtKg(profile.weightKg)),
                  color: c.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _TargetTile(
                  value: '${t.carbs}',
                  unit: s.gCarbs,
                  detail: s.remainingCalories,
                  color: c.carbs,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TargetTile(
                  value: '${t.fats}',
                  unit: s.gFats,
                  detail: s.fatsShare(t.kcal),
                  color: c.fats,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A numeric profile field that commits on submit and on tap-away, and only
/// when the value actually parsed, is positive, and differs from what is
/// already stored — so blurring an untouched field does not write to Supabase.
class _MeasureField extends StatelessWidget {
  const _MeasureField({
    required this.controller,
    required this.label,
    required this.suffix,
    required this.current,
    required this.onCommit,
    this.decimal = true,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;
  final double current;
  final ValueChanged<double> onCommit;
  final bool decimal;

  void _commit() {
    final v = double.tryParse(controller.text.replaceAll(',', '.'));
    if (v == null || v <= 0 || v == current) return;
    onCommit(v);
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            decimal ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]'),
          ),
        ],
        decoration: InputDecoration(labelText: label, suffixText: suffix),
        onSubmitted: (_) => _commit(),
        onTapOutside: (_) {
          _commit();
          FocusManager.instance.primaryFocus?.unfocus();
        },
      );
}

class _TargetTile extends StatelessWidget {
  const _TargetTile({
    required this.value,
    required this.unit,
    required this.detail,
    required this.color,
  });

  final String value;
  final String unit;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.bgBase,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: color,
                      height: 1)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(unit,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: c.textLow)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: c.textLow)),
        ],
      ),
    );
  }
}

/// The four macro rings for the selected day.
///
/// Four 116 px rings do not fit across a phone, so they lay out 4-up only when
/// the card is genuinely wide enough and fall back to a 2×2 grid otherwise;
/// the ring itself shrinks to whatever cell it lands in.
class _RingsCard extends StatelessWidget {
  const _RingsCard({
    required this.title,
    required this.loading,
    required this.totals,
    required this.targets,
  });

  final String title;
  final bool loading;
  final MacroTotals totals;
  final Targets targets;

  static const _gap = 12.0;
  static const _maxRing = 116.0;
  static const _minRing = 92.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.s;

    return ui.SectionCard(
      title: title,
      child: loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final fourUp = width >= _minRing * 4 + _gap * 3;
                final perRow = fourUp ? 4 : 2;
                final cell = (width - _gap * (perRow - 1)) / perRow;
                final size = math.min(cell, _maxRing);

                final rings = <Widget>[
                  ui.MacroRing(
                    label: s.calories,
                    value: totals.calories,
                    target: targets.kcal,
                    unit: s.unitKcal,
                    color: c.accent,
                    size: size,
                  ),
                  ui.MacroRing(
                    label: s.protein,
                    value: totals.protein,
                    target: targets.protein,
                    unit: s.unitGrams,
                    color: c.success,
                    size: size,
                  ),
                  ui.MacroRing(
                    label: s.carbs,
                    value: totals.carbs,
                    target: targets.carbs,
                    unit: s.unitGrams,
                    color: c.carbs,
                    size: size,
                  ),
                  ui.MacroRing(
                    label: s.fats,
                    value: totals.fats,
                    target: targets.fats,
                    unit: s.unitGrams,
                    color: c.fats,
                    size: size,
                  ),
                ];

                return Wrap(
                  spacing: _gap,
                  runSpacing: 20,
                  children: [
                    for (final ring in rings)
                      SizedBox(width: cell, child: ring),
                  ],
                );
              },
            ),
    );
  }
}

class _HydrationCard extends StatelessWidget {
  final DateTime day;
  final Profile profile;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _HydrationCard({
    required this.day,
    required this.profile,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final c = context.colors;
    
    final currentMl = LocalStorage.getWaterMl(day);
    final targetMl = (profile.weightKg * (profile.gender == Gender.male ? 35 : 31)).round();
    final progress = targetMl > 0 ? (currentMl / targetMl).clamp(0.0, 1.0) : 0.0;

    return ui.SectionCard(
      title: s.hydrationTitle,
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: c.border,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                Icon(Icons.water_drop, color: Colors.blue, size: 32),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.hydrationLogged(currentMl, targetMl),
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: c.textHi),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add),
                      label: const Text('250 ml'),
                      style: FilledButton.styleFrom(backgroundColor: Colors.blue),
                    ),
                    const SizedBox(width: 8),
                    // Secondary "undo a glass" action. Disabled at 0 so the
                    // button reads as unavailable rather than silently clamping.
                    IconButton.outlined(
                      onPressed: currentMl > 0 ? onRemove : null,
                      icon: const Icon(Icons.remove),
                      tooltip: '-250 ml',
                      color: Colors.blue,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyzeCard extends StatelessWidget {
  const _AnalyzeCard({
    required this.describeCtrl,
    required this.image,
    required this.analyzing,
    required this.analysis,
    required this.onPick,
    required this.onClearImage,
    required this.onAnalyze,
    required this.onManual,
  });

  final TextEditingController describeCtrl;
  final Uint8List? image;
  final bool analyzing;
  final String? analysis;
  final ValueChanged<ImageSource> onPick;
  final VoidCallback onClearImage;
  final VoidCallback? onAnalyze;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.s;

    return ui.SectionCard(
      title: s.analyzeMeal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: describeCtrl,
            maxLines: 3,
            minLines: 2,
            enabled: !analyzing,
            decoration: InputDecoration(
              hintText: s.describeHint,
              hintStyle:
                  TextStyle(color: c.textLow, fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),

          if (image != null) ...[
            Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.control),
                  child: Image.memory(
                    image!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: IconButton.filled(
                    onPressed: analyzing ? null : onClearImage,
                    icon: const Icon(Icons.close, size: 16),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      minimumSize: const Size(30, 30),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      analyzing ? null : () => onPick(ImageSource.gallery),
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: Text(s.upload, overflow: TextOverflow.ellipsis),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    foregroundColor: c.textMid,
                    side: BorderSide(color: c.border),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      analyzing ? null : () => onPick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: Text(s.camera, overflow: TextOverflow.ellipsis),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    foregroundColor: c.textMid,
                    side: BorderSide(color: c.border),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onAnalyze,
              icon: analyzing
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: c.onAccent),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(analyzing ? s.analyzing : s.analyzeFood),
            ),
          ),

          if (analysis != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.bgBase,
                borderRadius: BorderRadius.circular(AppRadii.control),
                border: Border.all(color: c.border),
              ),
              child: SelectableText(
                analysis!,
                style: TextStyle(
                    fontSize: 13, height: 1.5, color: c.textMid),
              ),
            ),
          ],

          const SizedBox(height: 10),
          Center(
            child: TextButton.icon(
              onPressed: analyzing ? null : onManual,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: Text(s.addManually),
              style: TextButton.styleFrom(foregroundColor: c.textMid),
            ),
          ),
        ],
      ),
    );
  }
}

class _MealsCard extends StatelessWidget {
  const _MealsCard({
    required this.meals,
    required this.onClearDay,
    required this.onDelete,
  });

  final List<Meal> meals;
  final VoidCallback? onClearDay;
  final ValueChanged<Meal> onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.s;

    return ui.SectionCard(
      title: s.mealsLogged,
      trailing: onClearDay == null
          ? null
          : TextButton(
              onPressed: onClearDay,
              style: TextButton.styleFrom(
                foregroundColor: c.danger,
                minimumSize: const Size(0, 30),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(s.clearDaysLog,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ),
      child: meals.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(s.nothingLogged,
                  style: TextStyle(color: c.textLow)),
            )
          : Column(
              children: [
                for (var i = 0; i < meals.length; i++) ...[
                  if (i > 0) const Divider(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              meals[i].name,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: c.textHi),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _mealSummary(s, meals[i]),
                              style: TextStyle(
                                  fontSize: 12, color: c.textLow),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => onDelete(meals[i]),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        color: c.textLow,
                        tooltip: s.delete,
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }

  /// e.g. `775 kcal · 77 g protein · 94 C / 9 F`. Built here rather than on the
  /// model: it is display text, and every unit in it is translated.
  static String _mealSummary(AppStrings s, Meal m) =>
      '${m.calories.round()} ${s.unitKcal} · '
      '${m.protein.round()} ${s.gProtein} · '
      '${m.carbs.round()} ${s.carbsInitial} / ${m.fats.round()} ${s.fatsInitial}';
}

/// Manual fallback, for when Gemini is unreachable or its [DATA] block is
/// malformed.
class _ManualMealSheet extends StatefulWidget {
  const _ManualMealSheet({required this.day, required this.onSubmit});

  final DateTime day;
  final ValueChanged<Meal> onSubmit;

  @override
  State<_ManualMealSheet> createState() => _ManualMealSheetState();
}

class _ManualMealSheetState extends State<_ManualMealSheet> {
  final _name = TextEditingController();
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fats = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _kcal.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fats.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final kcal = double.tryParse(_kcal.text.replaceAll(',', '.'));
    final protein = double.tryParse(_protein.text.replaceAll(',', '.'));
    if (name.isEmpty || kcal == null || protein == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.s.mealFieldsRequired),
      ));
      return;
    }
    widget.onSubmit(Meal(
      day: Meal.dayOf(widget.day),
      name: name,
      calories: kcal,
      protein: protein,
      carbs: double.tryParse(_carbs.text.replaceAll(',', '.')) ?? 0,
      fats: double.tryParse(_fats.text.replaceAll(',', '.')) ?? 0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.s;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.addMealOn(
                DateFormat('MMMM d', s.locale.code).format(widget.day)),
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: c.textHi),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: s.mealName),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _num(_kcal, s.calories, s.unitKcal)),
              const SizedBox(width: 10),
              Expanded(child: _num(_protein, s.protein, s.unitGrams)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _num(_carbs, s.carbs, s.unitGrams)),
              const SizedBox(width: 10),
              Expanded(child: _num(_fats, s.fats, s.unitGrams)),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _submit, child: Text(s.addMeal)),
          ),
        ],
      ),
    );
  }

  Widget _num(TextEditingController c, String label, String suffix) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        decoration: InputDecoration(labelText: label, suffixText: suffix),
      );
}
