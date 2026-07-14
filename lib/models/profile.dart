/// Fitness goal → the daily calorie delta applied on top of TDEE.
enum Goal {
  leanBulk('Lean Bulk', 300),
  maintenance('Maintenance', 0),
  cut('Cut', -500);

  const Goal(this.label, this.kcalDelta);

  /// Persisted verbatim in `profiles.goal`; the SQL CHECK constraint depends
  /// on these exact strings.
  final String label;

  /// kcal added to (or taken off) TDEE.
  final int kcalDelta;

  String get deltaLabel =>
      kcalDelta == 0 ? 'maintenance' : '${kcalDelta > 0 ? '+' : ''}$kcalDelta kcal';

  static Goal fromLabel(String? label) =>
      values.firstWhere((g) => g.label == label, orElse: () => leanBulk);
}

/// How much the lifter moves outside the gym → the Mifflin-St Jeor activity
/// multiplier applied to BMR.
enum ActivityLevel {
  sedentary('Sedentary', 1.2, 'Little to no exercise'),
  lightlyActive('Lightly Active', 1.375, 'Light exercise 1-3 days/week'),
  moderatelyActive(
      'Moderately Active', 1.55, 'Moderate exercise 3-5 days/week'),
  veryActive('Very Active', 1.725, 'Heavy exercise 6-7 days/week');

  const ActivityLevel(this.label, this.multiplier, this.description);

  /// Persisted verbatim in `profiles.activity_level`; the SQL CHECK constraint
  /// depends on these exact strings.
  final String label;
  final double multiplier;
  final String description;

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
  required Goal goal,
  required ActivityLevel activity,
}) {
  final bmr = 10 * weightKg + 6.25 * heightCm - 5 * age + 5;
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
    this.goal = Goal.leanBulk,
    this.activity = ActivityLevel.moderatelyActive,
    this.celebratedMilestones = const [],
  });

  final double weightKg;
  final double heightCm;
  final int age;
  final Goal goal;
  final ActivityLevel activity;

  /// Milestone 1RMs whose confetti has already fired. The existing
  /// workout_data.json already contains [80.0] — the 80 kg celebration has
  /// been spent and must never re-fire.
  final List<double> celebratedMilestones;

  Targets get targets => targetsFor(
        weightKg: weightKg,
        heightCm: heightCm,
        age: age,
        goal: goal,
        activity: activity,
      );

  bool hasCelebrated(double kg) =>
      celebratedMilestones.any((m) => (m - kg).abs() < 0.001);

  Profile copyWith({
    double? weightKg,
    double? heightCm,
    int? age,
    Goal? goal,
    ActivityLevel? activity,
    List<double>? celebratedMilestones,
  }) =>
      Profile(
        weightKg: weightKg ?? this.weightKg,
        heightCm: heightCm ?? this.heightCm,
        age: age ?? this.age,
        goal: goal ?? this.goal,
        activity: activity ?? this.activity,
        celebratedMilestones:
            celebratedMilestones ?? this.celebratedMilestones,
      );

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 94,
        heightCm: (json['height_cm'] as num?)?.toDouble() ?? 180,
        age: (json['age'] as num?)?.toInt() ?? 30,
        goal: Goal.fromLabel(json['goal'] as String?),
        activity: ActivityLevel.fromLabel(json['activity_level'] as String?),
        celebratedMilestones: ((json['celebrated_milestones'] as List?) ?? [])
            .map((e) => (e as num).toDouble())
            .toList(),
      );

  Map<String, dynamic> toUpsert(String userId) => {
        'user_id': userId,
        'weight_kg': weightKg,
        'height_cm': heightCm,
        'age': age,
        'goal': goal.label,
        'activity_level': activity.label,
        'celebrated_milestones': celebratedMilestones,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
}
