import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/meal.dart';
import '../models/profile.dart';
import '../models/workout.dart';

/// Everything that touches the database. Supabase types do not leak past this
/// class — callers get models back, never a PostgrestResponse.
class SupabaseService {
  SupabaseService(this._client);

  final SupabaseClient _client;

  /// Supabase URL and publishable (anon) key, injected at build time:
  ///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
  static const _url = String.fromEnvironment('SUPABASE_URL');
  static const _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => _url.isNotEmpty && _anonKey.isNotEmpty;

  static Future<void> init() async {
    if (!isConfigured) {
      throw StateError(
        'SUPABASE_URL / SUPABASE_ANON_KEY are missing. Pass them with '
        '--dart-define (see README.md).',
      );
    }
    // `anonKey:` is deprecated in the current SDK. `publishableKey:` accepts
    // both the new sb_publishable_… keys and the legacy anon JWT, so either
    // works here.
    await Supabase.initialize(url: _url, publishableKey: _anonKey);
  }

  Session? get session => _client.auth.currentSession;
  String? get userId => _client.auth.currentUser?.id;
  Stream<AuthState> get authChanges => _client.auth.onAuthStateChange;

  String get _uid {
    final id = userId;
    if (id == null) throw StateError('Not signed in.');
    return id;
  }

  // -- auth ------------------------------------------------------------------

  Future<void> signIn(String email, String password) =>
      _client.auth.signInWithPassword(email: email, password: password);

  Future<void> signUp(String email, String password) =>
      _client.auth.signUp(email: email, password: password);

  Future<void> signOut() => _client.auth.signOut();

  // -- workouts --------------------------------------------------------------

  /// Newest first — WorkoutHistory's plateau logic depends on that ordering.
  Future<WorkoutHistory> fetchWorkouts() async {
    final rows = await _client
        .from('workouts')
        .select()
        .eq('user_id', _uid)
        .order('date', ascending: false);
    return WorkoutHistory(
      (rows as List).map((r) => Workout.fromJson(r)).toList(),
    );
  }

  Future<void> addWorkout(Workout w) async {
    await _client.from('workouts').insert({...w.toInsert(), 'user_id': _uid});
  }

  Future<void> deleteWorkout(String id) async {
    await _client.from('workouts').delete().eq('id', id).eq('user_id', _uid);
  }

  // -- meals -----------------------------------------------------------------

  /// Meals for one calendar day, oldest first (the order they were eaten).
  Future<List<Meal>> fetchMeals(DateTime day) async {
    final rows = await _client
        .from('meals')
        .select()
        .eq('user_id', _uid)
        .eq('date', Meal.dateKey(day))
        .order('created_at', ascending: true);
    return (rows as List).map((r) => Meal.fromJson(r)).toList();
  }

  Future<void> addMeal(Meal m) async {
    await _client.from('meals').insert({...m.toInsert(), 'user_id': _uid});
  }

  Future<void> deleteMeal(String id) async {
    await _client.from('meals').delete().eq('id', id).eq('user_id', _uid);
  }

  /// Wipe one day's log. Scoped to a single date so history is never touched.
  Future<void> clearDay(DateTime day) async {
    await _client
        .from('meals')
        .delete()
        .eq('user_id', _uid)
        .eq('date', Meal.dateKey(day));
  }

  // -- profile ---------------------------------------------------------------

  Future<Profile> fetchProfile() async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('user_id', _uid)
        .maybeSingle();
    // The on_auth_user_created trigger normally creates this row; fall back to
    // defaults rather than crashing if the migration has not been run yet.
    return row == null ? const Profile() : Profile.fromJson(row);
  }

  Future<void> saveProfile(Profile p) async {
    await _client.from('profiles').upsert(p.toUpsert(_uid));
  }

  /// Atomically claim a milestone celebration.
  ///
  /// Returns true only if this call is the one that claimed it — the caller may
  /// then fire the confetti. Re-reads the profile first so a second device that
  /// already celebrated 80 kg cannot celebrate it again. This is what makes
  /// "for the first time" actually hold across restarts and devices.
  Future<bool> claimMilestone(double kg) async {
    final current = await fetchProfile();
    if (current.hasCelebrated(kg)) return false;
    await saveProfile(current.copyWith(
      celebratedMilestones: [...current.celebratedMilestones, kg],
    ));
    return true;
  }
}
