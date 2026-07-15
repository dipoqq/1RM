import 'dart:convert';

import 'package:hive/hive.dart';

import '../models/workout.dart';

/// A workout logged offline, waiting to be pushed to the server, paired with
/// the local key that identifies it in the queue so it can be removed once sync
/// succeeds.
class WorkoutDraft {
  const WorkoutDraft(this.id, this.workout);

  /// The local queue key — NOT a server id. A draft's [Workout.id] is null
  /// until the server assigns one on sync.
  final String id;
  final Workout workout;
}

/// A durable, FIFO queue of workouts logged while offline.
///
/// A seam so the sync backend can be tested against an in-memory queue; the
/// production implementation persists to Hive so a draft survives the app being
/// killed before it ever reaches the network.
abstract interface class WorkoutDraftStore {
  /// Append a workout to the back of the queue.
  Future<void> add(Workout workout);

  /// Every queued draft, oldest first — the order they must sync in.
  Future<List<WorkoutDraft>> pending();

  /// Drop a draft once it has synced (or is permanently unsyncable).
  Future<void> remove(String id);

  /// How many drafts are waiting.
  Future<int> count();
}

/// [WorkoutDraftStore] persisted in a Hive box of JSON strings.
///
/// Each draft is stored as the same insert payload the server would receive
/// ([Workout.toInsert]), keyed by a monotonic local id. Serialising to the
/// insert shape means a drained draft is byte-for-byte the workout a live insert
/// would have written — no separate "draft" schema to drift out of sync.
class HiveWorkoutDraftStore implements WorkoutDraftStore {
  HiveWorkoutDraftStore(this._box);

  final Box<String> _box;

  static const boxName = 'workout_drafts';

  /// Open (or create) the drafts box. Call once, after `Hive.initFlutter()`.
  static Future<HiveWorkoutDraftStore> open() async =>
      HiveWorkoutDraftStore(await Hive.openBox<String>(boxName));

  @override
  Future<void> add(Workout workout) async {
    // Microsecond key doubles as a sortable timestamp, so keys() is already in
    // insertion order.
    final id = 'd_${DateTime.now().microsecondsSinceEpoch}';
    await _box.put(id, jsonEncode(workout.toInsert()));
  }

  @override
  Future<List<WorkoutDraft>> pending() async {
    final drafts = <WorkoutDraft>[];
    for (final key in _box.keys) {
      final raw = _box.get(key);
      if (raw == null) continue;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      drafts.add(WorkoutDraft('$key', Workout.fromJson(json)));
    }
    return drafts;
  }

  @override
  Future<void> remove(String id) => _box.delete(id);

  @override
  Future<int> count() async => _box.length;
}
