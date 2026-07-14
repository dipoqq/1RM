/// A single logged meal.
///
/// [day] is a calendar day, not an instant. A meal eaten at 23:30 belongs to
/// that evening, not to the next day in UTC — the diary is organised around
/// the day the lifter actually ate. The `meals.date` column is a SQL DATE for
/// exactly this reason.
class Meal {
  const Meal({
    this.id,
    required this.day,
    required this.name,
    required this.calories,
    required this.protein,
    this.carbs = 0,
    this.fats = 0,
  });

  final String? id;
  final DateTime day;
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fats;

  factory Meal.fromJson(Map<String, dynamic> json) => Meal(
        id: json['id'] as String?,
        day: DateTime.parse(json['date'] as String),
        name: json['name'] as String,
        calories: (json['calories'] as num?)?.toDouble() ?? 0,
        protein: (json['protein'] as num?)?.toDouble() ?? 0,
        carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
        fats: (json['fats'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toInsert() => {
        'date': dateKey(day),
        'name': name,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fats': fats,
      };

  /// The `YYYY-MM-DD` key a DATE column expects. Local components only — using
  /// toUtc() here is the bug this whole class exists to avoid.
  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Strip the time component, keeping the local calendar day.
  static DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
}

/// Running totals for one day.
class MacroTotals {
  const MacroTotals({
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fats = 0,
  });

  final double calories;
  final double protein;
  final double carbs;
  final double fats;

  factory MacroTotals.of(Iterable<Meal> meals) {
    var c = 0.0, p = 0.0, cb = 0.0, f = 0.0;
    for (final m in meals) {
      c += m.calories;
      p += m.protein;
      cb += m.carbs;
      f += m.fats;
    }
    return MacroTotals(calories: c, protein: p, carbs: cb, fats: f);
  }
}
