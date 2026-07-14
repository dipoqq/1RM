import '../core/constants.dart';
import '../core/l10n/app_locale.dart';

/// Fitness goal → the daily calorie delta applied on top of TDEE.
enum Goal {
  leanBulk('Lean Bulk', 300),
  maintenance('Maintenance', 0),
  cut('Cut', -500);

  const Goal(this.label, this.kcalDelta);

  /// Persisted verbatim in `profiles.goal`; the SQL CHECK constraint depends
  /// on these exact strings. This is a storage key, NOT display text — the
  /// screen shows `AppStrings.goalLabel(this)`.
  final String label;

  /// kcal added to (or taken off) TDEE.
  final int kcalDelta;

  static Goal fromLabel(String? label) =>
      values.firstWhere((g) => g.label == label, orElse: () => leanBulk);
}

/// Biological sex → the constant term in the Mifflin-St Jeor BMR equation.
///
/// Mifflin-St Jeor is two equations, not one: the male form ends `+ 5`, the
/// female form ends `- 161`. That 166 kcal gap is carried straight through
/// activity and goal into the calorie and carb targets, so a female lifter
/// scored on the male equation is told to eat several hundred kcal a day too
/// many. This is the input that fixes it.
enum Gender {
  male('Male', 5),
  female('Female', -161);

  const Gender(this.label, this.bmrConstant);

  /// Persisted verbatim in `profiles.gender`; the SQL CHECK constraint depends
  /// on these exact strings. This is a storage key, NOT display text — the
  /// screen shows `AppStrings.genderLabel(this)`.
  final String label;

  /// The constant term added to the Mifflin-St Jeor equation.
  final int bmrConstant;

  static Gender fromLabel(String? label) =>
      values.firstWhere((g) => g.label == label, orElse: () => male);
}

/// How much the lifter moves outside the gym → the Mifflin-St Jeor activity
/// multiplier applied to BMR.
enum ActivityLevel {
  sedentary('Sedentary', 1.2),
  lightlyActive('Lightly Active', 1.375),
  moderatelyActive('Moderately Active', 1.55),
  veryActive('Very Active', 1.725);

  const ActivityLevel(this.label, this.multiplier);

  /// Persisted verbatim in `profiles.activity_level`; the SQL CHECK constraint
  /// depends on these exact strings. Display text comes from
  /// `AppStrings.activityLabel(this)`.
  final String label;
  final double multiplier;

  static ActivityLevel fromLabel(String? label) => values.firstWhere(
        (a) => a.label == label,
        orElse: () => moderatelyActive,
      );
}

/// A full day's macro plan, plus the two intermediate figures the UI shows so
/// the lifter can see where the number came from rather than trusting a box.
typedef Targets = ({
  double bmr,
  double tdee,
  int kcal,
  int protein,
  int carbs,
  int fats,
});

/// Everything the UI needs to render bench press progress against the lifter's
/// own target, derived in one place so the bar, the "kg to go" line and the
/// percentage can never disagree with each other.
typedef BenchProgress = ({
  /// Best estimated 1RM, or null when nothing has been logged yet.
  double? best,
  double goalKg,

  /// 0..1, clamped — safe to hand straight to a progress bar.
  double ratio,

  /// Kilos still to add. Zero once the goal is cleared, never negative.
  double remainingKg,

  /// The same ratio as a whole number, NOT clamped: a 1RM past the goal reads
  /// 104%, because rounding that down to 100% would hide the overshoot.
  int percent,
  bool cleared,
});

/// Mifflin-St Jeor, then activity, then goal, then the macro split.
///
/// Protein is fixed at 2.0 g/kg of bodyweight and fats at 25% of the calorie
/// target; carbs are whatever calories are left. On an aggressive cut for a
/// heavy lifter that remainder can go negative — protein and fats are the
/// floor worth defending, so carbs clamp at zero rather than the split being
/// silently rebalanced.
Targets targetsFor({
  required double weightKg,
  required double heightCm,
  required int age,
  required Gender gender,
  required Goal goal,
  required ActivityLevel activity,
}) {
  final bmr =
      10 * weightKg + 6.25 * heightCm - 5 * age + gender.bmrConstant;
  final tdee = bmr * activity.multiplier;
  final kcal = (tdee + goal.kcalDelta).clamp(0.0, double.infinity);

  final protein = 2.0 * weightKg;
  final fats = kcal * 0.25 / 9;
  final carbs = ((kcal - protein * 4 - fats * 9) / 4).clamp(0.0, double.infinity);

  return (
    bmr: bmr,
    tdee: tdee,
    kcal: kcal.round(),
    protein: protein.round(),
    carbs: carbs.round(),
    fats: fats.round(),
  );
}

/// The user's persisted settings and celebration state.
class Profile {
  const Profile({
    this.weightKg = 94,
    this.heightCm = 180,
    this.age = 30,
    this.gender = Gender.male,
    this.goal = Goal.leanBulk,
    this.activity = ActivityLevel.moderatelyActive,
    this.benchGoalKg = kDefaultGoalKg,
    this.locale = AppLocale.en,
    this.celebratedMilestones = const [],
  });

  final double weightKg;
  final double heightCm;
  final int age;

  /// Selects which Mifflin-St Jeor equation the daily targets are built on.
  final Gender gender;

  final Goal goal;
  final ActivityLevel activity;

  /// The lifter's own bench press target 1RM. Every bar, remaining-weight and
  /// percentage figure in the Training tab is measured against this, and it is
  /// the final confetti milestone.
  final double benchGoalKg;

  /// The language the UI renders in. Persisted so the choice follows the user
  /// from the desktop app to the phone rather than being made twice.
  final AppLocale locale;

  /// Milestone 1RMs whose confetti has already fired. The existing
  /// workout_data.json already contains [80.0] — the 80 kg celebration has
  /// been spent and must never re-fire.
  final List<double> celebratedMilestones;

  Targets get targets => targetsFor(
        weightKg: weightKg,
        heightCm: heightCm,
        age: age,
        gender: gender,
        goal: goal,
        activity: activity,
      );

  /// The milestones this lifter's goal implies, ascending.
  List<Milestone> get milestones => milestonesFor(benchGoalKg);

  bool hasCelebrated(double kg) =>
      celebratedMilestones.any((m) => (m - kg).abs() < 0.001);

  /// Bench press progress of [best1rm] toward [benchGoalKg].
  BenchProgress benchProgress(double? best1rm) {
    final best = best1rm ?? 0;
    // benchGoalKg is floored at the bar by [clampGoal] on the way in, so this
    // cannot divide by zero — the guard is belt-and-braces against a row
    // written by some future migration.
    final ratio = benchGoalKg <= 0 ? 0.0 : best / benchGoalKg;
    return (
      best: best1rm,
      goalKg: benchGoalKg,
      ratio: ratio.clamp(0.0, 1.0),
      remainingKg: (benchGoalKg - best).clamp(0.0, double.infinity),
      percent: (ratio * 100).round(),
      cleared: best >= benchGoalKg,
    );
  }

  /// Hold a goal inside the loadable, sane range. Applied on every read from
  /// the database and every write from the settings screen, so no code path
  /// downstream has to wonder whether the goal is usable.
  static double clampGoal(double kg) => kg.clamp(kMinGoalKg, kMaxGoalKg);

  static bool isValidGoal(double kg) => kg >= kMinGoalKg && kg <= kMaxGoalKg;

  Profile copyWith({
    double? weightKg,
    double? heightCm,
    int? age,
    Gender? gender,
    Goal? goal,
    ActivityLevel? activity,
    double? benchGoalKg,
    AppLocale? locale,
    List<double>? celebratedMilestones,
  }) =>
      Profile(
        weightKg: weightKg ?? this.weightKg,
        heightCm: heightCm ?? this.heightCm,
        age: age ?? this.age,
        gender: gender ?? this.gender,
        goal: goal ?? this.goal,
        activity: activity ?? this.activity,
        benchGoalKg:
            benchGoalKg == null ? this.benchGoalKg : clampGoal(benchGoalKg),
        locale: locale ?? this.locale,
        celebratedMilestones:
            celebratedMilestones ?? this.celebratedMilestones,
      );

  /// Every field falls back to the same default the SQL column does, so a row
  /// written before migration 004 and one written after behave identically.
  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 94,
        heightCm: (json['height_cm'] as num?)?.toDouble() ?? 180,
        age: (json['age'] as num?)?.toInt() ?? 30,
        gender: Gender.fromLabel(json['gender'] as String?),
        goal: Goal.fromLabel(json['goal'] as String?),
        activity: ActivityLevel.fromLabel(json['activity_level'] as String?),
        benchGoalKg: clampGoal(
            (json['bench_goal_kg'] as num?)?.toDouble() ?? kDefaultGoalKg),
        locale: AppLocale.fromCode(json['language'] as String?),
        celebratedMilestones: ((json['celebrated_milestones'] as List?) ?? [])
            .map((e) => (e as num).toDouble())
            .toList(),
      );

  Map<String, dynamic> toUpsert(String userId) => {
        'user_id': userId,
        'weight_kg': weightKg,
        'height_cm': heightCm,
        'age': age,
        'gender': gender.label,
        'goal': goal.label,
        'activity_level': activity.label,
        'bench_goal_kg': benchGoalKg,
        'language': locale.code,
        'celebrated_milestones': celebratedMilestones,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
}
