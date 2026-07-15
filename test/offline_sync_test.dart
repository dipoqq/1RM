import 'dart:async';

import 'package:bench_app/core/constants.dart';
import 'package:bench_app/models/workout.dart';
import 'package:bench_app/services/connectivity_monitor.dart';
import 'package:bench_app/services/offline_sync_backend.dart';
import 'package:bench_app/services/workout_draft_store.dart';
import 'package:bench_app/state/sync_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

/// In-memory drafts queue with the same FIFO contract as the Hive store, so the
/// sync logic can be exercised without a real box.
class MemoryDraftStore implements WorkoutDraftStore {
  final _items = <String, Workout>{};
  int _seq = 0;

  @override
  Future<void> add(Workout workout) async => _items['d${_seq++}'] = workout;
  @override
  Future<List<WorkoutDraft>> pending() async =>
      [for (final e in _items.entries) WorkoutDraft(e.key, e.value)];
  @override
  Future<void> remove(String id) async => _items.remove(id);
  @override
  Future<int> count() async => _items.length;
}

/// A hand-driven connectivity signal.
class FakeConnectivity implements ConnectivityMonitor {
  FakeConnectivity({this.online = true});
  bool online;
  final _c = StreamController<bool>.broadcast();

  void go(bool value) {
    online = value;
    _c.add(value);
  }

  @override
  Future<bool> get isOnline async => online;
  @override
  Stream<bool> get onStatusChange => _c.stream;
  @override
  void dispose() => _c.close();
}

/// A backend whose workout writes fail like a dropped connection, to prove the
/// "online per the OS but the request died" fallback path.
class FlakyRemote extends FakeBackend {
  FlakyRemote();
  bool failWorkouts = false;
  final List<Workout> synced = [];

  @override
  Future<void> addWorkout(Workout w) async {
    if (failWorkouts) {
      throw Exception('SocketException: connection failed');
    }
    synced.add(w);
  }

  @override
  Future<WorkoutHistory> fetchWorkouts() async =>
      WorkoutHistory(synced.reversed.toList());
}

Workout _w({double weight = 100, DateTime? at}) => Workout(
      date: at ?? DateTime.now(),
      workoutType: WorkoutType.heavy,
      weight: weight,
      reps: 5,
      sets: 3,
      completed: true,
    );

void main() {
  late FlakyRemote remote;
  late MemoryDraftStore drafts;
  late FakeConnectivity net;
  late OfflineSyncBackend backend;

  setUp(() {
    remote = FlakyRemote();
    drafts = MemoryDraftStore();
    net = FakeConnectivity();
    backend = OfflineSyncBackend(
      remote: remote,
      drafts: drafts,
      connectivity: net,
    );
  });

  tearDown(() => net.dispose());

  test('online write goes straight to the server, nothing queued', () async {
    await backend.addWorkout(_w());
    expect(remote.synced, hasLength(1));
    expect(await drafts.count(), 0);
    expect(backend.pending.value, 0);
  });

  test('an offline write is queued locally, not lost', () async {
    net.online = false;
    await backend.addWorkout(_w(weight: 90));

    expect(remote.synced, isEmpty);
    expect(await drafts.count(), 1);
    expect(backend.pending.value, 1);
  });

  test('a dropped-connection write while nominally online still queues',
      () async {
    remote.failWorkouts = true; // online, but every write dies
    await backend.addWorkout(_w());
    expect(await drafts.count(), 1);
    expect(backend.pending.value, 1);
  });

  test('fetch merges queued drafts on top of server history, newest first',
      () async {
    // One already on the server (older)…
    await backend.addWorkout(_w(weight: 80, at: DateTime(2026, 7, 1)));
    // …then the connection drops and two are logged offline (newer).
    net.online = false;
    await backend.addWorkout(_w(weight: 100, at: DateTime(2026, 7, 14)));
    await backend.addWorkout(_w(weight: 105, at: DateTime(2026, 7, 15)));

    final history = await backend.fetchWorkouts();
    expect(history.all, hasLength(3));
    // Newest first: the two drafts, then the synced one.
    expect(history.all.map((w) => w.weight).toList(), [105, 100, 80]);
  });

  test('flush drains the queue to the server in order and clears pending',
      () async {
    net.online = false;
    await backend.addWorkout(_w(weight: 90, at: DateTime(2026, 7, 14)));
    await backend.addWorkout(_w(weight: 95, at: DateTime(2026, 7, 15)));
    expect(backend.pending.value, 2);

    // Back online: drain.
    net.online = true;
    await backend.flush();

    expect(await drafts.count(), 0);
    expect(backend.pending.value, 0);
    expect(remote.synced.map((w) => w.weight).toList(), [90, 95]);
  });

  test('flush stops at the first still-offline failure, preserving order',
      () async {
    net.online = false;
    await backend.addWorkout(_w(weight: 90));
    await backend.addWorkout(_w(weight: 95));

    // "Reconnect" but writes still fail — nothing should drain, queue intact.
    net.online = true;
    remote.failWorkouts = true;
    await backend.flush();

    expect(await drafts.count(), 2);
    expect(backend.pending.value, 2);
    expect(remote.synced, isEmpty);
  });

  test('SyncController flushes automatically when connectivity returns',
      () async {
    // This is the "silent sync" contract end-to-end.
    net.online = false;
    await backend.addWorkout(_w(weight: 88));
    expect(backend.pending.value, 1);

    // The controller wires reconnect -> flush. Build it while offline…
    final controller = SyncController(monitor: net, backend: backend);
    addTearDown(controller.dispose);
    await pumpEventQueue();
    expect(controller.online, isFalse);
    expect(remote.synced, isEmpty);

    // …then come back online. The status event drives the drain, no UI needed.
    net.go(true);
    await pumpEventQueue();

    expect(controller.online, isTrue);
    expect(await drafts.count(), 0);
    expect(backend.pending.value, 0);
    expect(remote.synced.map((w) => w.weight).toList(), [88]);
  });
}
