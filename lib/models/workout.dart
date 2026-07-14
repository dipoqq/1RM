import '../core/constants.dart';
import '../core/progression.dart';

/// A single logged bench press session.
class Workout {
  const Workout({
    this.id,
    required this.date,
    required this.workoutType,
    required this.weight,
    required this.reps,
    required this.sets,
    required this.completed,
    this.note = '',
  });

  final String? id; // null until Supabase assigns one
  final DateTime date;
  final String workoutType;
  final double weight; // kg
  final int reps;
  final int sets;
  final bool completed; // were all sets completed as prescribed?
  final String note;

  bool get isHeavy => workoutType == WorkoutType.heavy;

  /// Total tonnage moved in the session (kg).
  double get volume => weight * reps * sets;

  /// Epley estimate. Only meaningful for a completed set.
  double get estimated1rm => Progression.estimated1rm(weight, reps);

  String get summary => '${_g(weight)} kg x $reps x $sets';

  factory Workout.fromJson(Map<String, dynamic> json) => Workout(
        id: json['id'] as String?,
        date: DateTime.parse(json['date'] as String).toLocal(),
        workoutType: json['workout_type'] as String,
        weight: (json['weight'] as num).toDouble(),
        reps: (json['reps'] as num).toInt(),
        sets: (json['sets'] as num).toInt(),
        completed: json['completed'] as bool? ?? true,
        note: json['note'] as String? ?? '',
      );

  /// `id` and `user_id` are omitted: the database defaults the former and
  /// SupabaseService injects the latter.
  Map<String, dynamic> toInsert() => {
        'date': date.toUtc().toIso8601String(),
        'workout_type': workoutType,
        'weight': weight,
        'reps': reps,
        'sets': sets,
        'completed': completed,
        'note': note,
      };

  static String _g(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

/// Read-model over a user's workout history. Everything the dashboard needs to
/// know is derived here, so the widgets stay dumb.
///
/// Invariant: [all] is sorted newest-first. SupabaseService guarantees this by
/// ordering on `date desc`.
class WorkoutHistory {
  const WorkoutHistory(this.all);

  final List<Workout> all;

  List<Workout> get heavy => all.where((w) => w.isHeavy).toList();

  /// Weight of the most recent heavy day, else the most recent session at all.
  double? get currentWorkingWeight {
    final h = heavy;
    if (h.isNotEmpty) return h.first.weight;
    return all.isEmpty ? null : all.first.weight;
  }

  /// Best 1RM estimate across *completed* sessions. A failed set proves
  /// nothing, so it cannot set a record.
  double? get bestEstimated1rm {
    final done = all.where((w) => w.completed).map((w) => w.estimated1rm);
    if (done.isEmpty) return null;
    return done.reduce((a, b) => a > b ? a : b);
  }

  /// How many consecutive heavy days have been failed, most recent first.
  int get failedHeavyStreak {
    var streak = 0;
    for (final w in heavy) {
      if (w.completed) break;
      streak++;
    }
    return streak;
  }

  /// True when the last [kPlateauThreshold] heavy days were all failures.
  ///
  /// Volume and deload sessions are ignored entirely — only heavy days test
  /// whether the working weight is still moving. A single successful heavy day
  /// anywhere in that window clears the plateau.
  bool get plateauDetected {
    final h = heavy;
    if (h.length < kPlateauThreshold) return false;
    return h.take(kPlateauThreshold).every((w) => !w.completed);
  }

  /// Working weight to start the next block from — deloaded 10% if a plateau
  /// is active, so the lifter rebuilds momentum instead of grinding the same
  /// failed weight into an injury.
  double? get recommendedWorkingWeight {
    final current = currentWorkingWeight;
    if (current == null) return null;
    return plateauDetected ? Progression.deloaded(current) : current;
  }

  /// Distinct ISO weeks in which at least one session was logged.
  int get weeksCompleted =>
      all.map((w) => '${w.date.year}-${_isoWeek(w.date)}').toSet().length;

  static int _isoWeek(DateTime d) {
    final thursday = d.add(Duration(days: 4 - (d.weekday)));
    final firstJan = DateTime(thursday.year, 1, 1);
    return ((thursday.difference(firstJan).inDays) / 7).floor() + 1;
  }
}
