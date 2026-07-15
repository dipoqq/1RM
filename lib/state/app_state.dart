import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../core/l10n/app_locale.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme_mode.dart';
import '../models/profile.dart';
import '../models/workout.dart';
import '../services/backend.dart';
import '../services/local_storage.dart';

/// The single source of truth for everything that must stay in step across the
/// whole app: the language, the bench press goal, the body metrics and the
/// milestones already celebrated. All of it is the [Profile], so all of it is
/// one row in Supabase and one notifier here.
///
/// Reactivity, without a package: widgets subscribe through [AppScope] (an
/// [InheritedNotifier]), so changing the language or the bench goal rebuilds
/// every listener — both tabs, the app bar, the settings screen — in the same
/// frame, and no screen keeps a private copy of the profile that could drift.
class AppState extends ChangeNotifier {
  AppState(this.service, {Profile? initial})
      : _profile = initial ??
            // Before sign-in there is no stored preference to read, so the
            // sign-in screen opens in the device's language rather than
            // stubbornly in English.
            Profile(locale: AppLocale.fromSystem());

  final Backend service;

  Profile _profile;
  Profile get profile => _profile;

  Exercise _activeExercise = Exercise.benchPress;
  Exercise get activeExercise => _activeExercise;

  void setActiveExercise(Exercise exercise) {
    if (_activeExercise != exercise) {
      _activeExercise = exercise;
      _notify();
    }
  }

  bool _loading = false;
  bool get loading => _loading;

  /// Whether [load] has finished at least once for the current session.
  ///
  /// Until it has, [profile] is a placeholder built from defaults — and a
  /// default profile has a null `onboardedAt`, so it reports [needsOnboarding].
  /// Routing on that would flash the setup screen at every returning user for
  /// the frames between sign-in and the profile landing. AuthGate waits on this
  /// instead.
  bool _loaded = false;
  bool get loaded => _loaded;

  /// Whether this lifter must be sent through setup before the tabs open.
  /// Only meaningful once [loaded] is true.
  bool get needsOnboarding => _profile.needsOnboarding;

  AppLocale get locale => _profile.locale;

  /// The palette in force. `main` feeds this straight into the MaterialApp's
  /// theme, so flipping it repaints the whole app, not just the screen that
  /// toggled it.
  AppThemeMode get themeMode => _profile.themeMode;

  /// The strings for the current language. `context.s` is the shorthand.
  AppStrings get s => AppStrings.of(_profile.locale);

  /// The permanent ledger of achievement ids already celebrated, loaded from
  /// Supabase at sign-in. Anything in here has fired its toast/confetti once and
  /// must never fire again — the guard that stops a deleted-then-re-added
  /// workout from re-celebrating. Milestone kg thresholds live on the profile
  /// (`celebratedMilestones`); the named achievements and the 50/100% progress
  /// bursts live here.
  final Set<String> _claimedAchievements = {};
  bool hasClaimedAchievement(String id) => _claimedAchievements.contains(id);

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Notify, but never in the middle of a build.
  ///
  /// [load] is called from `initState` — by AuthGate on a restored session and
  /// by the Nutrition tab on first show — and `initState` runs *during* the
  /// build phase. Notifying there marks AppScope's dependents dirty while they
  /// are being built, which trips `!_dirty` in the framework.
  ///
  /// So: if a frame is in flight, the notification rides out to just after it.
  /// Outside a build (a language switch, a goal saved, a network reply landing)
  /// it dispatches immediately, which is what keeps the UI feeling instant.
  /// Every mutation below goes through this rather than notifyListeners(), so a
  /// future caller cannot reintroduce the crash by loading from initState.
  void _notify() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    final building = phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks;

    if (!building) {
      notifyListeners();
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      // The tab that asked may have been disposed in between (sign-out during
      // a fetch); notifying a disposed ChangeNotifier throws.
      if (!_disposed) notifyListeners();
    });
  }

  /// Pull the profile for the signed-in user. Called once the session exists.
  Future<void> load() async {
    if (service.userId == null) return;
    _loading = true;
    _notify();
    try {
      _profile = await service.fetchProfile();
      // Load the celebration ledger alongside the profile. A failure here must
      // not strand the user, so it is swallowed to an empty set — the worst case
      // is one extra toast, never a blocked sign-in.
      try {
        final claimed = await service.fetchUnlockedAchievements();
        _claimedAchievements
          ..clear()
          ..addAll(claimed);
      } catch (_) {
        _claimedAchievements.clear();
      }
    } finally {
      _loading = false;
      // Set even when the fetch threw. A failed load must not strand the user
      // on AuthGate's spinner forever; they fall through to onboarding, which
      // is recoverable, rather than to a screen with no way out.
      _loaded = true;
      _notify();
    }
  }

  /// Reset to a signed-out state, keeping the language and the theme the user
  /// was reading in — being thrown back into English, or into a white flash,
  /// at the sign-in screen because you signed out would be a bug, not a
  /// feature.
  void clear() {
    _profile = Profile(locale: _profile.locale, themeMode: _profile.themeMode);
    // The next account gets its own profile, and until that lands nothing may
    // be concluded about whether it has been onboarded.
    _loaded = false;
    // The ledger is per-account; the next sign-in reloads its own.
    _claimedAchievements.clear();
    _notify();
  }

  /// Apply a change, then persist it.
  ///
  /// Optimistic: the UI moves on the current frame, because a language switch
  /// that waits for a network round-trip feels broken. If the write fails the
  /// profile is rolled back to exactly what it was and the error is rethrown
  /// for the caller to surface — the screen never keeps a value the database
  /// rejected.
  Future<void> update({
    double? weightKg,
    double? heightCm,
    int? age,
    Gender? gender,
    Goal? goal,
    ActivityLevel? activity,
    double? benchGoalKg,
    double? squatGoalKg,
    double? deadliftGoalKg,
    AppLocale? locale,
    AppThemeMode? themeMode,
  }) async {
    final previous = _profile;
    _profile = _profile.copyWith(
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
      gender: gender,
      goal: goal,
      activity: activity,
      benchGoalKg: benchGoalKg,
      squatGoalKg: squatGoalKg,
      deadliftGoalKg: deadliftGoalKg,
      locale: locale,
      themeMode: themeMode,
    );
    _notify();

    // Mirror any goal change into the local cache (SharedPreferences) so the
    // three target 1RMs persist on-device independently of the network write
    // below. A no-op before LocalStorage.init(), e.g. in unit tests.
    if (benchGoalKg != null || squatGoalKg != null || deadliftGoalKg != null) {
      _persistGoalsLocally();
    }

    // Signed out (the language switch on the sign-in screen): there is no row
    // to write to yet. The choice still applies, and load() will overwrite it
    // with whatever this account saved last time.
    if (service.userId == null) return;

    try {
      await service.saveProfile(_profile);
    } catch (e) {
      _profile = previous;
      _notify();
      rethrow;
    }
  }

  /// Finish onboarding: the lifter's own metrics, saved, and the gate opened.
  ///
  /// The one write in this class that is deliberately NOT optimistic. Everywhere
  /// else the UI moves first and rolls back on failure, because a language
  /// switch that waits for the network feels broken. Here the requirement runs
  /// the other way: the tabs may not open until the profile is actually in
  /// Supabase. Moving first would let a lifter whose save silently failed spend
  /// the session training against a goal — and eating against calorie targets —
  /// that exist only on their screen, and be asked to set it all up again on
  /// the next launch with no idea why.
  ///
  /// So: write, and only then flip [needsOnboarding]. On failure the profile is
  /// untouched and the error is rethrown for the screen to surface — the gate
  /// stays shut, which is the honest outcome.
  Future<void> completeOnboarding({
    required Gender gender,
    required double heightCm,
    required double weightKg,
    required int age,
    required double benchGoalKg,
  }) async {
    if (service.userId == null) {
      throw const BackendException('Not signed in.');
    }

    final next = _profile.copyWith(
      gender: gender,
      heightCm: heightCm,
      weightKg: weightKg,
      age: age,
      benchGoalKg: benchGoalKg,
      // The stamp that says "this lifter has been asked". Nothing else in the
      // app sets it, and nothing can unset it.
      onboardedAt: DateTime.now(),
    );

    await service.saveProfile(next);
    _profile = next;
    _persistGoalsLocally();
    _notify();
  }

  /// Write the three current target 1RMs to the on-device cache. Fire-and-forget:
  /// the local mirror must never block or fail a profile update.
  void _persistGoalsLocally() {
    unawaited(LocalStorage.setGoals(
      benchKg: _profile.benchGoalKg,
      squatKg: _profile.squatGoalKg,
      deadliftKg: _profile.deadliftGoalKg,
    ));
  }

  /// Claim a milestone celebration, atomically against the database.
  ///
  /// Returns true only if this call is the one that claimed it — the caller may
  /// then fire the confetti. The local profile is refreshed from the row that
  /// was written, so a milestone claimed here is not re-claimed on the next
  /// save from this device either.
  Future<bool> claimMilestone(double kg) async {
    final claimed = await service.claimMilestone(kg);
    if (claimed) {
      _profile = _profile.copyWith(
        celebratedMilestones: [..._profile.celebratedMilestones, kg],
      );
      _notify();
    }
    return claimed;
  }

  /// Claim an achievement celebration, against the permanent ledger.
  ///
  /// Returns true only if this call is the one that first recorded it — the
  /// caller may then fire the toast/confetti. A no-op returning false if the id
  /// is already known locally (the fast path that stops a re-added workout from
  /// re-celebrating) or already in the ledger server-side.
  Future<bool> claimAchievement(String id) async {
    if (_claimedAchievements.contains(id)) return false;
    final claimed = await service.recordAchievement(id);
    if (claimed) _claimedAchievements.add(id);
    return claimed;
  }
}

/// Puts [AppState] in the tree and rebuilds dependents when it notifies.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope?.notifier != null, 'No AppScope above this widget.');
    return scope!.notifier!;
  }
}

extension AppStateContext on BuildContext {
  /// The app state, subscribing this widget to its changes.
  AppState get app => AppScope.of(this);

  /// The strings for the current language, subscribing this widget to language
  /// changes. Every localized widget reads `context.s`.
  AppStrings get s => AppScope.of(this).s;
}
