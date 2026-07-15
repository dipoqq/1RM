import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/meal.dart';
import '../models/profile.dart';
import '../models/workout.dart';
import 'backend.dart';

/// Everything that touches the database. Supabase types do not leak past this
/// class — callers get models back, never a PostgrestResponse, and never an
/// AuthException.
class SupabaseService implements Backend {
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

  @override
  String? get userId => _client.auth.currentUser?.id;

  @override
  bool get isSignedIn => _client.auth.currentSession != null;

  @override
  Stream<AuthStatus> get authStatus => _client.auth.onAuthStateChange.map(
        (state) => state.session == null
            ? AuthStatus.signedOut
            : AuthStatus.signedIn,
      );

  String get _uid {
    final id = userId;
    if (id == null) throw const BackendException('Not signed in.');
    return id;
  }

  // -- auth ------------------------------------------------------------------

  /// Auth failures are the one kind the user is expected to hit routinely (a
  /// mistyped password), so they are translated into the app's own exception
  /// rather than handed up as a Supabase type.
  Future<T> _auth<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on AuthException catch (e) {
      throw BackendException(e.message);
    }
  }

  @override
  Future<void> signIn(String email, String password) => _auth(
        () => _client.auth.signInWithPassword(email: email, password: password),
      );

  @override
  Future<void> signUp(String email, String password) =>
      _auth(() => _client.auth.signUp(email: email, password: password));

  @override
  Future<void> signOut() => _auth(() => _client.auth.signOut());

  // -- workouts --------------------------------------------------------------

  @override
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

  @override
  Future<void> addWorkout(Workout w) async {
    await _client.from('workouts').insert({...w.toInsert(), 'user_id': _uid});
  }

  @override
  Future<void> deleteWorkout(String id) async {
    await _client.from('workouts').delete().eq('id', id).eq('user_id', _uid);
  }

  // -- meals -----------------------------------------------------------------

  @override
  Future<List<Meal>> fetchMeals(DateTime day) async {
    final rows = await _client
        .from('meals')
        .select()
        .eq('user_id', _uid)
        .eq('date', Meal.dateKey(day))
        .order('created_at', ascending: true);
    return (rows as List).map((r) => Meal.fromJson(r)).toList();
  }

  @override
  Future<void> addMeal(Meal m) async {
    await _client.from('meals').insert({...m.toInsert(), 'user_id': _uid});
  }

  @override
  Future<void> deleteMeal(String id) async {
    await _client.from('meals').delete().eq('id', id).eq('user_id', _uid);
  }

  /// Wipe one day's log. Scoped to a single date so history is never touched.
  @override
  Future<void> clearDay(DateTime day) async {
    await _client
        .from('meals')
        .delete()
        .eq('user_id', _uid)
        .eq('date', Meal.dateKey(day));
  }

  // -- profile ---------------------------------------------------------------

  @override
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

  /// Writes the whole profile, language and bench goal included — which is what
  /// makes both preferences show up on the other device.
  @override
  Future<void> saveProfile(Profile p) async {
    await _client.from('profiles').upsert(p.toUpsert(_uid));
  }

  /// Claim a milestone celebration atomically, server-side.
  ///
  /// Delegates to the `claim_milestone` Postgres function (migration 008), which
  /// folds the "not already celebrated" check and the array append into one
  /// locked UPDATE. That is what makes "for the first time" actually hold when
  /// two devices cross the same milestone at once — the old fetch-then-save here
  /// had a read-modify-write race that let both of them fire the confetti.
  ///
  /// Returns true only if THIS call is the one that claimed it.
  @override
  Future<bool> claimMilestone(double kg) async {
    final claimed =
        await _client.rpc('claim_milestone', params: {'p_kg': kg});
    return claimed as bool;
  }

  // -- achievement ledger ----------------------------------------------------

  @override
  Future<Set<String>> fetchUnlockedAchievements() async {
    final rows = await _client
        .from('unlocked_achievements')
        .select('achievement_id')
        .eq('user_id', _uid);
    return (rows as List)
        .map((r) => r['achievement_id'] as String)
        .toSet();
  }

  /// Insert with `on conflict do nothing` (ignoreDuplicates), then `select()`
  /// the RETURNING rows. A first-time insert returns the row; a duplicate
  /// returns nothing — so a non-empty result means THIS call claimed it. This is
  /// what keeps a delete-and-re-add from re-firing the celebration.
  @override
  Future<bool> recordAchievement(String id) async {
    final rows = await _client
        .from('unlocked_achievements')
        .upsert(
          {'user_id': _uid, 'achievement_id': id},
          ignoreDuplicates: true,
        )
        .select('achievement_id');
    return (rows as List).isNotEmpty;
  }
}
