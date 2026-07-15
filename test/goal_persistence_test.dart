import 'package:bench_app/models/profile.dart';
import 'package:bench_app/services/local_storage.dart';
import 'package:bench_app/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  test('LocalStorage round-trips the three target 1RMs', () async {
    await LocalStorage.setGoals(benchKg: 100, squatKg: 150, deadliftKg: 200);

    expect(LocalStorage.getBenchGoal(), 100);
    expect(LocalStorage.getSquatGoal(), 150);
    expect(LocalStorage.getDeadliftGoal(), 200);
  });

  test('updating a goal in AppState mirrors it to SharedPreferences', () async {
    final backend = FakeBackend(profile: const Profile());
    final state = AppState(backend);
    addTearDown(state.dispose);

    await state.update(squatGoalKg: 165);
    // The local write is fire-and-forget; let its microtask complete.
    await Future<void>.delayed(Duration.zero);

    expect(LocalStorage.getSquatGoal(), 165);
    // The other two are written alongside it, from the current profile.
    expect(LocalStorage.getBenchGoal(), state.profile.benchGoalKg);
    expect(LocalStorage.getDeadliftGoal(), state.profile.deadliftGoalKg);
    // And it still reached the remote profile.
    expect(backend.saves.single.squatGoalKg, 165);
  });

  test('a non-goal update does not touch the goal cache', () async {
    await LocalStorage.setGoals(benchKg: 90, squatKg: 90, deadliftKg: 90);
    final state = AppState(FakeBackend(profile: const Profile()));
    addTearDown(state.dispose);

    await state.update(weightKg: 88);
    await Future<void>.delayed(Duration.zero);

    // Untouched by a weight-only change.
    expect(LocalStorage.getSquatGoal(), 90);
  });
}
