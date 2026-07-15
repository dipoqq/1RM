import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/meal.dart';
import '../models/profile.dart';
import '../models/workout.dart';
import 'backend.dart';
import 'connectivity_monitor.dart';
import 'workout_draft_store.dart';

/// Offline-first decorator over a real [Backend].
///
/// Training logs are the one thing a lifter must be able to record with no
/// signal — mid-set, in a basement gym. So workout writes go through here:
///
///  * [addWorkout] tries the server, but the moment the device is offline (or
///    the request fails like a dropped connection) it drops the workout into a
///    durable local queue and returns success. The set is logged, full stop.
///  * [fetchWorkouts] merges the queued drafts on top of the server's history,
///    so an offline-logged session shows up in the list immediately — and stays
///    visible after a restart, because the queue is on disk.
///  * [flush] drains the queue to the server, oldest first. It is safe to call
///    repeatedly; a [SyncController] calls it the instant connectivity returns.
///
/// Everything that is not a workout write (auth, meals, profile, achievements)
/// is passed straight through — those are not part of the offline story and
/// carry their own failure handling upstream.
class OfflineSyncBackend implements Backend {
  OfflineSyncBackend({
    required this.remote,
    required this.drafts,
    required this.connectivity,
  });

  final Backend remote;
  final WorkoutDraftStore drafts;
  final ConnectivityMonitor connectivity;

  /// The number of workouts waiting to sync. The badge and the sync banner both
  /// listen to this, so the UI reflects the queue without polling it.
  final ValueNotifier<int> pending = ValueNotifier<int>(0);

  /// The last history the server returned, kept so that going offline does not
  /// blank out the sessions already synced — the merge below layers drafts on
  /// top of this rather than on nothing.
  List<Workout> _lastRemote = const [];

  /// Prime [pending] from the on-disk queue. Call once at startup.
  Future<void> init() => _refreshPending();

  Future<void> _refreshPending() async => pending.value = await drafts.count();

  /// Whether [e] is the kind of failure that means "no connection", as opposed
  /// to a real error (a bad row, an auth problem) that queuing would only hide.
  static bool _looksOffline(Object e) {
    if (e is TimeoutException) return true;
    final s = e.toString().toLowerCase();
    return s.contains('socket') ||
        s.contains('failed host lookup') ||
        s.contains('network') ||
        s.contains('connection') ||
        s.contains('clientexception') ||
        s.contains('xmlhttprequest') ||
        s.contains('unreachable');
  }

  Future<void> _queue(Workout w) async {
    await drafts.add(w);
    await _refreshPending();
  }

  // -- workouts: the offline-first surface -----------------------------------

  @override
  Future<void> addWorkout(Workout w) async {
    // Known offline: skip the doomed request (and its long timeout) entirely.
    if (!await connectivity.isOnline) {
      await _queue(w);
      return;
    }
    try {
      await remote.addWorkout(w);
    } catch (e) {
      // Online per the OS but the write still failed like a dropped connection:
      // queue it. A genuine error (rejected row) is not ours to swallow.
      if (_looksOffline(e)) {
        await _queue(w);
        return;
      }
      rethrow;
    }
  }

  @override
  Future<WorkoutHistory> fetchWorkouts() async {
    final draftWorkouts = [for (final d in await drafts.pending()) d.workout];
    try {
      _lastRemote = (await remote.fetchWorkouts()).all;
    } catch (e) {
      if (!_looksOffline(e)) rethrow;
      // Offline: fall back to the last known server history.
    }
    // Drafts are the newest sessions (just logged), so they sort to the top by
    // date. WorkoutHistory requires newest-first; the sort guarantees it.
    final merged = <Workout>[...draftWorkouts, ..._lastRemote]
      ..sort((a, b) => b.date.compareTo(a.date));
    return WorkoutHistory(merged);
  }

  /// Push every queued draft to the server, oldest first, stopping at the first
  /// still-offline failure so ordering is preserved for the next attempt.
  Future<void> flush() async {
    if (await drafts.count() == 0) return;
    for (final draft in await drafts.pending()) {
      try {
        await remote.addWorkout(draft.workout);
        await drafts.remove(draft.id);
      } catch (e) {
        if (_looksOffline(e)) break; // still down — retry on the next reconnect
        // A permanent rejection (e.g. a row the server refuses) would wedge the
        // whole queue behind it forever. Drop it so the rest can drain.
        await drafts.remove(draft.id);
      }
    }
    await _refreshPending();
  }

  @override
  Future<void> deleteWorkout(String id) => remote.deleteWorkout(id);

  // -- everything else: straight passthrough ---------------------------------

  @override
  String? get userId => remote.userId;
  @override
  bool get isSignedIn => remote.isSignedIn;
  @override
  Stream<AuthStatus> get authStatus => remote.authStatus;
  @override
  Future<void> signIn(String email, String password) =>
      remote.signIn(email, password);
  @override
  Future<void> signUp(String email, String password) =>
      remote.signUp(email, password);
  @override
  Future<void> signOut() => remote.signOut();
  @override
  Future<void> sendPasswordReset(String email) =>
      remote.sendPasswordReset(email);
  @override
  Future<List<Meal>> fetchMeals(DateTime day) => remote.fetchMeals(day);
  @override
  Future<void> addMeal(Meal m) => remote.addMeal(m);
  @override
  Future<void> deleteMeal(String id) => remote.deleteMeal(id);
  @override
  Future<void> clearDay(DateTime day) => remote.clearDay(day);
  @override
  Future<Profile> fetchProfile() => remote.fetchProfile();
  @override
  Future<void> saveProfile(Profile p) => remote.saveProfile(p);
  @override
  Future<bool> claimMilestone(double kg) => remote.claimMilestone(kg);
  @override
  Future<Set<String>> fetchUnlockedAchievements() =>
      remote.fetchUnlockedAchievements();
  @override
  Future<bool> recordAchievement(String id) => remote.recordAchievement(id);
}
