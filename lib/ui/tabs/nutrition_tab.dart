import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../models/meal.dart';
import '../../models/profile.dart';
import '../../services/gemini_service.dart';
import '../../services/supabase_service.dart';
import '../widgets/adaptive.dart';
import '../widgets/calendar_strip.dart';
import '../widgets/common.dart' as ui;

class NutritionTab extends StatefulWidget {
  const NutritionTab({super.key, required this.service});

  final SupabaseService service;

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

  Profile _profile = const Profile();
  List<Meal> _meals = const [];
  bool _loading = true;
  bool _analyzing = false;

  Uint8List? _image;
  String _imageMime = 'image/jpeg';
  String? _analysis;

  DateTime get _today => Meal.dayOf(DateTime.now());
  bool get _isToday => _selected == _today;

  @override
  void initState() {
    super.initState();
    _load();
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
      final profile = await widget.service.fetchProfile();
      final meals = await widget.service.fetchMeals(_selected);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _meals = meals;
        _loading = false;
      });
      // Only seed the fields on first load; refilling them on every refresh
      // would fight the user while they are typing.
      if (_weightCtrl.text.isEmpty) {
        _weightCtrl.text = _fmt(profile.weightKg);
      }
      if (_heightCtrl.text.isEmpty) {
        _heightCtrl.text = _fmt(profile.heightCm);
      }
      if (_ageCtrl.text.isEmpty) {
        _ageCtrl.text = profile.age.toString();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Could not load: $e');
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
    final meals = await widget.service.fetchMeals(_selected);
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
    Goal? goal,
    ActivityLevel? activity,
  }) async {
    final next = _profile.copyWith(
      weightKg: weight,
      heightCm: height,
      age: age,
      goal: goal,
      activity: activity,
    );
    setState(() => _profile = next);
    try {
      await widget.service.saveProfile(next);
    } catch (e) {
      if (mounted) _snack('Could not save settings: $e');
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
      if (mounted) _snack('Could not open the picker: $e');
    }
  }

  /// Run the Gemini call off the UI thread; the button spins and is disabled
  /// throughout, so the rest of the tab stays interactive.
  Future<void> _analyze() async {
    if (!GeminiService.isConfigured) {
      _snack('GEMINI_API_KEY was not passed at build time. See README.md.');
      return;
    }
    if (_describeCtrl.text.trim().isEmpty && _image == null) {
      _snack('Describe your meal or attach a photo of your plate.');
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
        targets: _profile.targets,
        eaten: MacroTotals.of(_meals),
        day: day,
      );

      if (!mounted) return;
      setState(() => _analysis = result.prose);

      final meal = result.meal;
      if (meal == null) {
        setState(() => _analyzing = false);
        _snack('Gemini did not return a parsable [DATA] block — add it manually.');
        return;
      }

      await widget.service.addMeal(meal);
      final meals = await widget.service.fetchMeals(day);
      if (!mounted) return;
      setState(() {
        // Guard against the user having switched days mid-flight.
        if (day == _selected) _meals = meals;
        _analyzing = false;
        _describeCtrl.clear();
        _image = null;
      });
      _snack('Logged "${meal.name}" · ${meal.calories.round()} kcal.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _analyzing = false);
      _snack('Analysis failed: $e');
    }
  }

  Future<void> _addManual(Meal meal) async {
    await widget.service.addMeal(meal);
    final meals = await widget.service.fetchMeals(_selected);
    if (!mounted) return;
    setState(() => _meals = meals);
  }

  Future<void> _clearDay() async {
    final label = DateFormat('MMMM d').format(_selected);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgBase,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        title: const Text("Clear this day's log?"),
        content: Text(
          'This permanently deletes all ${_meals.length} meals logged on '
          '$label. Other days are untouched. This cannot be undone.',
          style: const TextStyle(color: AppColors.textMid, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await widget.service.clearDay(_selected);
    if (!mounted) return;
    setState(() => _meals = const []);
    _snack('Cleared $label.');
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
    final totals = MacroTotals.of(_meals);
    final targets = _profile.targets;

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
            title:
                'Viewing History: ${DateFormat('MMMM d, y').format(_selected)}',
            message:
                'Anything you log now is recorded against this date, not today.',
            color: AppColors.warning,
            tint: AppColors.warningTint,
            action: FilledButton.tonal(
              onPressed: () => _selectDay(_today),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: AppColors.onAccent,
                minimumSize: const Size(0, 40),
              ),
              child: const Text('Back to today'),
            ),
          ),
        _GoalsCard(
          weightCtrl: _weightCtrl,
          heightCtrl: _heightCtrl,
          ageCtrl: _ageCtrl,
          profile: _profile,
          onWeight: (w) => _saveProfile(weight: w),
          onHeight: (h) => _saveProfile(height: h),
          onAge: (a) => _saveProfile(age: a),
          onGoal: (g) => _saveProfile(goal: g),
          onActivity: (a) => _saveProfile(activity: a),
        ),
        _RingsCard(
          title:
              _isToday ? 'Today' : DateFormat('EEEE, MMM d').format(_selected),
          loading: _loading,
          totals: totals,
          targets: targets,
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
            await widget.service.deleteMeal(m.id!);
            final meals = await widget.service.fetchMeals(_selected);
            if (!mounted) return;
            setState(() => _meals = meals);
          },
        ),
      ],
    );
  }

  void _openManualSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ManualMealSheet(
        day: _selected,
        onSubmit: (meal) async {
          Navigator.pop(context);
          await _addManual(meal);
        },
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
  final ValueChanged<Goal> onGoal;
  final ValueChanged<ActivityLevel> onActivity;

  @override
  Widget build(BuildContext context) {
    final t = profile.targets;

    return ui.SectionCard(
      title: 'Daily targets',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _MeasureField(
                  controller: weightCtrl,
                  label: 'Bodyweight',
                  suffix: 'kg',
                  current: profile.weightKg,
                  onCommit: onWeight,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MeasureField(
                  controller: heightCtrl,
                  label: 'Height',
                  suffix: 'cm',
                  current: profile.heightCm,
                  onCommit: onHeight,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MeasureField(
                  controller: ageCtrl,
                  label: 'Age',
                  suffix: 'y',
                  decimal: false,
                  current: profile.age.toDouble(),
                  onCommit: (v) => onAge(v.round()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ActivityLevel>(
            initialValue: profile.activity,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Activity level'),
            items: [
              for (final a in ActivityLevel.values)
                DropdownMenuItem(
                  value: a,
                  child: Text(
                    '${a.label} · ${a.description}',
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
            decoration: const InputDecoration(labelText: 'Goal'),
            items: [
              for (final g in Goal.values)
                DropdownMenuItem(
                  value: g,
                  child: Text('${g.label} · ${g.deltaLabel}'),
                ),
            ],
            onChanged: (g) => g == null ? null : onGoal(g),
          ),

          // The arithmetic, shown rather than hidden: the lifter can see that a
          // target moved because his weight moved, not because the app guessed.
          const SizedBox(height: 14),
          Text(
            'BMR ${t.bmr.round()} kcal  ×${profile.activity.multiplier} '
            '(${profile.activity.label})  =  TDEE ${t.tdee.round()} kcal',
            style: const TextStyle(fontSize: 11, color: AppColors.textLow),
          ),

          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _TargetTile(
                  value: '${t.kcal}',
                  unit: 'kcal',
                  detail: 'TDEE · ${profile.goal.deltaLabel}',
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TargetTile(
                  value: '${t.protein}',
                  unit: 'g protein',
                  detail: '2.0 g × ${_fmt(profile.weightKg)} kg',
                  color: AppColors.success,
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
                  unit: 'g carbs',
                  detail: 'remaining calories',
                  color: AppColors.carbs,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TargetTile(
                  value: '${t.fats}',
                  unit: 'g fats',
                  detail: '25% of ${t.kcal} kcal',
                  color: AppColors.fats,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
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
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgBase,
          borderRadius: BorderRadius.circular(AppRadii.control),
          border: Border.all(color: AppColors.border),
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
                Text(unit,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textLow)),
              ],
            ),
            const SizedBox(height: 4),
            Text(detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textLow)),
          ],
        ),
      );
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
                    label: 'Calories',
                    value: totals.calories,
                    target: targets.kcal,
                    unit: 'kcal',
                    color: AppColors.accent,
                    size: size,
                  ),
                  ui.MacroRing(
                    label: 'Protein',
                    value: totals.protein,
                    target: targets.protein,
                    unit: 'g',
                    color: AppColors.success,
                    size: size,
                  ),
                  ui.MacroRing(
                    label: 'Carbs',
                    value: totals.carbs,
                    target: targets.carbs,
                    unit: 'g',
                    color: AppColors.carbs,
                    size: size,
                  ),
                  ui.MacroRing(
                    label: 'Fats',
                    value: totals.fats,
                    target: targets.fats,
                    unit: 'g',
                    color: AppColors.fats,
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
    return ui.SectionCard(
      title: 'Analyze a meal',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: describeCtrl,
            maxLines: 3,
            minLines: 2,
            enabled: !analyzing,
            decoration: const InputDecoration(
              hintText: 'e.g. 200 g chicken breast, 150 g rice, olive oil…',
              hintStyle: TextStyle(color: AppColors.textLow, fontSize: 13),
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
                  label: const Text('Upload'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    foregroundColor: AppColors.textMid,
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      analyzing ? null : () => onPick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Camera'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    foregroundColor: AppColors.textMid,
                    side: const BorderSide(color: AppColors.border),
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
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.onAccent),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(analyzing ? 'Analyzing…' : 'Analyze food'),
            ),
          ),

          if (analysis != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bgBase,
                borderRadius: BorderRadius.circular(AppRadii.control),
                border: Border.all(color: AppColors.border),
              ),
              child: SelectableText(
                analysis!,
                style: const TextStyle(
                    fontSize: 13, height: 1.5, color: AppColors.textMid),
              ),
            ),
          ],

          const SizedBox(height: 10),
          Center(
            child: TextButton.icon(
              onPressed: analyzing ? null : onManual,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Add manually instead'),
              style: TextButton.styleFrom(foregroundColor: AppColors.textMid),
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
    return ui.SectionCard(
      title: 'Meals logged',
      trailing: onClearDay == null
          ? null
          : TextButton(
              onPressed: onClearDay,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.danger,
                minimumSize: const Size(0, 30),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text("Clear day's log",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
      child: meals.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Nothing logged on this day.',
                  style: TextStyle(color: AppColors.textLow)),
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
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textHi),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${meals[i].summary} · '
                              '${meals[i].carbs.round()} C / ${meals[i].fats.round()} F',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textLow),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => onDelete(meals[i]),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        color: AppColors.textLow,
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Name, calories and protein are required.'),
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
            'Add meal · ${DateFormat('MMMM d').format(widget.day)}',
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textHi),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Meal name'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _num(_kcal, 'Calories', 'kcal')),
              const SizedBox(width: 10),
              Expanded(child: _num(_protein, 'Protein', 'g')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _num(_carbs, 'Carbs', 'g')),
              const SizedBox(width: 10),
              Expanded(child: _num(_fats, 'Fats', 'g')),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _submit, child: const Text('Add meal')),
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
