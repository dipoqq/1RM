import 'dart:async';

import 'package:bench_app/models/meal.dart';
import 'package:bench_app/models/profile.dart';
import 'package:bench_app/models/workout.dart';
import 'package:bench_app/services/backend.dart';

/// An in-memory Backend.
///
/// A real SupabaseClient starts auth-refresh timers the moment it is
/// constructed, which a widget test cannot pump away — and none of the state
/// logic worth testing is about the wire format anyway.
class FakeBackend implements Backend {
  FakeBackend({this.signedIn = true, Profile? profile})
      : _profile = profile ?? const Profile();

  bool signedIn;
  Profile _profile;

  /// Every profile write this backend has accepted, in order — so a test can
  /// assert what would actually reach the database, not just what the UI shows.
  final List<Profile> saves = [];

  /// Set to make the next write fail, the way a dropped connection would.
  Object? failNextSave;

  final _auth = StreamController<AuthStatus>.broadcast();

  /// How many times the profile has been read. A rebuild storm shows up here as
  /// a number that keeps climbing.
  int profileFetches = 0;

  @override
  String? get userId => signedIn ? 'test-user' : null;

  @override
  bool get isSignedIn => signedIn;

  @override
  Stream<AuthStatus> get authStatus => _auth.stream;

  /// Push an auth event, as Supabase does on sign-in, sign-out and every token
  /// refresh.
  void emit(AuthStatus status) => _auth.add(status);

  void dispose() => _auth.close();

  @override
  Future<Profile> fetchProfile() async {
    profileFetches++;
    return _profile;
  }

  @override
  Future<void> saveProfile(Profile p) async {
    final failure = failNextSave;
    if (failure != null) {
      failNextSave = null;
      throw failure;
    }
    _profile = p;
    saves.add(p);
  }

  @override
  Future<bool> claimMilestone(double kg) async {
    if (_profile.hasCelebrated(kg)) return false;
    await saveProfile(_profile.copyWith(
      celebratedMilestones: [..._profile.celebratedMilestones, kg],
    ));
    return true;
  }

  /// In-memory mirror of the unlocked_achievements ledger, with the same
  /// idempotent "true only the first time" contract as the real backend.
  final Set<String> unlockedAchievements = {};

  @override
  Future<Set<String>> fetchUnlockedAchievements() async =>
      {...unlockedAchievements};

  @override
  Future<bool> recordAchievement(String id) async =>
      unlockedAchievements.add(id); // Set.add returns false if already present

  /// Every address a reset was requested for, in order, so a test can assert
  /// the forgot-password flow reached the backend.
  final List<String> passwordResets = [];

  // The rest of the surface is not what these tests are about.
  @override
  Future<void> signIn(String email, String password) async => signedIn = true;
  @override
  Future<void> signUp(String email, String password) async => signedIn = true;
  @override
  Future<void> signOut() async => signedIn = false;
  @override
  Future<void> sendPasswordReset(String email) async =>
      passwordResets.add(email);
  @override
  Future<WorkoutHistory> fetchWorkouts() async => const WorkoutHistory([]);
  @override
  Future<void> addWorkout(Workout w) async {}
  @override
  Future<void> deleteWorkout(String id) async {}
  @override
  Future<List<Meal>> fetchMeals(DateTime day) async => const [];
  @override
  Future<void> addMeal(Meal m) async {}
  @override
  Future<void> deleteMeal(String id) async {}
  @override
  Future<void> clearDay(DateTime day) async {}
}
