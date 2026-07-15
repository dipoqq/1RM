import 'dart:async';

import 'package:bench_app/models/workout.dart';
import 'package:bench_app/services/connectivity_monitor.dart';
import 'package:bench_app/services/offline_sync_backend.dart';
import 'package:bench_app/services/workout_draft_store.dart';
import 'package:bench_app/state/app_state.dart';
import 'package:bench_app/state/sync_controller.dart';
import 'package:bench_app/ui/widgets/sync_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

class _MemStore implements WorkoutDraftStore {
  final _items = <String, Workout>{};
  int _seq = 0;
  @override
  Future<void> add(Workout w) async => _items['d${_seq++}'] = w;
  @override
  Future<List<WorkoutDraft>> pending() async =>
      [for (final e in _items.entries) WorkoutDraft(e.key, e.value)];
  @override
  Future<void> remove(String id) async => _items.remove(id);
  @override
  Future<int> count() async => _items.length;
}

class _Net implements ConnectivityMonitor {
  _Net(this.online);
  bool online;
  final _c = StreamController<bool>.broadcast();
  void go(bool v) {
    online = v;
    _c.add(v);
  }

  @override
  Future<bool> get isOnline async => online;
  @override
  Stream<bool> get onStatusChange => _c.stream;
  @override
  void dispose() => _c.close();
}

void main() {
  testWidgets('the badge is invisible while online and synced', (t) async {
    final r = await _mount(t, online: true);
    expect(find.byType(SizedBox), findsWidgets); // it collapsed to shrink
    expect(find.text('Offline Mode'), findsNothing);
    r();
  });

  testWidgets('the badge announces Offline Mode when the connection drops',
      (t) async {
    final net = _Net(false);
    final dispose = await _mount(t, net: net);
    expect(find.text('Offline Mode'), findsOneWidget);
    dispose();
  });

  testWidgets('without a SyncScope the badge renders nothing', (t) async {
    final state = AppState(FakeBackend());
    addTearDown(state.dispose);
    await t.pumpWidget(AppScope(
      state: state,
      child: const MaterialApp(home: Scaffold(body: SyncStatusBadge())),
    ));
    // No scope, no crash, no visible label.
    expect(find.text('Offline Mode'), findsNothing);
  });
}

/// Mounts the badge under a real SyncController + AppScope. Returns a disposer.
Future<VoidCallback> _mount(
  WidgetTester t, {
  bool online = false,
  _Net? net,
}) async {
  final connectivity = net ?? _Net(online);
  final backend = OfflineSyncBackend(
    remote: FakeBackend(),
    drafts: _MemStore(),
    connectivity: connectivity,
  );
  final controller = SyncController(monitor: connectivity, backend: backend);
  final state = AppState(FakeBackend());

  await t.pumpWidget(AppScope(
    state: state,
    child: MaterialApp(
      home: SyncScope(
        controller: controller,
        child: const Scaffold(body: Center(child: SyncStatusBadge())),
      ),
    ),
  ));
  await t.pumpAndSettle();

  return () {
    controller.dispose();
    state.dispose();
    connectivity.dispose();
  };
}
