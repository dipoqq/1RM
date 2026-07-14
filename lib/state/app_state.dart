import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../core/l10n/app_locale.dart';
import '../core/l10n/app_strings.dart';
import '../models/profile.dart';
import '../services/backend.dart';

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

  bool _loading = false;
  bool get loading => _loading;

  AppLocale get locale => _profile.locale;

  /// The strings for the current language. `context.s` is the shorthand.
  AppStrings get s => AppStrings.of(_profile.locale);

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
    } finally {
      _loading = false;
      _notify();
    }
  }

  /// Reset to a signed-out state, keeping the language the user was reading in
  /// — being thrown back into English at the sign-in screen because you signed
  /// out would be a bug, not a feature.
  void clear() {
    _profile = Profile(locale: _profile.locale);
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
    AppLocale? locale,
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
      locale: locale,
    );
    _notify();

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
