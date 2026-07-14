import '../models/meal.dart';
import '../models/profile.dart';
import '../models/workout.dart';

/// Whether there is a signed-in user. Mapped from the provider's own auth
/// events so nothing above this layer has to know what a `Session` is.
enum AuthStatus { signedIn, signedOut }

/// A failure the user can be shown: a wrong password, a dropped connection.
/// The provider's exception types stop here.
class BackendException implements Exception {
  const BackendException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Everything the app needs from a server, and nothing about which server.
///
/// [SupabaseService] is the one implementation; the point of the seam is not
/// swapping databases, it is that the state layer and the widgets can be tested
/// against an in-memory fake instead of a live project — a real SupabaseClient
/// starts auth-refresh timers the moment it is constructed, which a widget test
/// cannot pump away.
abstract interface class Backend {
  String? get userId;
  bool get isSignedIn;

  /// Emits on every sign-in and sign-out, including a session restored at boot.
  Stream<AuthStatus> get authStatus;

  Future<void> signIn(String email, String password);
  Future<void> signUp(String email, String password);
  Future<void> signOut();

  /// Newest first — WorkoutHistory's plateau logic depends on that ordering.
  Future<WorkoutHistory> fetchWorkouts();
  Future<void> addWorkout(Workout w);
  Future<void> deleteWorkout(String id);

  /// One calendar day's meals, oldest first (the order they were eaten).
  Future<List<Meal>> fetchMeals(DateTime day);
  Future<void> addMeal(Meal m);
  Future<void> deleteMeal(String id);
  Future<void> clearDay(DateTime day);

  Future<Profile> fetchProfile();
  Future<void> saveProfile(Profile p);

  /// Atomically claim a milestone celebration. True only if THIS call claimed
  /// it — the caller may then fire the confetti.
  Future<bool> claimMilestone(double kg);
}
