import 'package:bench_app/core/l10n/app_locale.dart';
import 'package:bench_app/core/theme_mode.dart';
import 'package:bench_app/models/profile.dart';
import 'package:bench_app/models/workout.dart';
import 'package:bench_app/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

/// The two things the whole feature rests on, in one widget: does changing the
/// profile rebuild a screen that reads it — with no setState of its own?
Widget host(AppState state) => AppScope(
      state: state,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                Text(context.s.settings),
                Text(context.s.percentOfGoal(
                  context.app.profile.benchProgress(47.5).percent,
                )),
              ],
            ),
          ),
        ),
      ),
    );

/// A screen that fetches the profile in initState, as AuthGate and the
/// Nutrition tab both do.
class _LoadsOnInit extends StatefulWidget {
  const _LoadsOnInit({required this.state});

  final AppState state;

  @override
  State<_LoadsOnInit> createState() => _LoadsOnInitState();
}

class _LoadsOnInitState extends State<_LoadsOnInit> {
  @override
  void initState() {
    super.initState();
    widget.state.load();
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Text(context.s.settings));
}

void main() {
  late FakeBackend backend;
  late AppState state;

  void build({Profile? profile}) {
    backend = FakeBackend(profile: profile);
    state = AppState(backend, initial: profile);
    addTearDown(state.dispose);
    addTearDown(backend.dispose);
  }

  group('reactivity', () {
    testWidgets('switching the language re-renders the UI', (tester) async {
      build(profile: const Profile(locale: AppLocale.en));

      await tester.pumpWidget(host(state));
      expect(find.text('Settings'), findsOneWidget);

      await state.update(locale: AppLocale.ru);
      await tester.pump();

      expect(find.text('Настройки'), findsOneWidget);
      expect(find.text('Settings'), findsNothing);
    });

    testWidgets('changing the bench goal re-renders every metric that reads it',
        (tester) async {
      build(profile: const Profile(benchGoalKg: 95, locale: AppLocale.en));

      await tester.pumpWidget(host(state));
      expect(find.text('50% of goal'), findsOneWidget); // 47.5 of 95

      await state.update(benchGoalKg: 47.5);
      await tester.pump();

      // The same 1RM, a new goal, a new percentage — with no refetch and no
      // setState in the widget that displays it.
      expect(find.text('100% of goal'), findsOneWidget);
    });

    testWidgets('changing active exercise updates the state', (tester) async {
      build();
      expect(state.activeExercise, Exercise.benchPress);
      state.setActiveExercise(Exercise.squat);
      expect(state.activeExercise, Exercise.squat);
      
      // Update squat goal and check
      await state.update(squatGoalKg: 105);
      expect(state.profile.squatGoalKg, 105);
    });
  });

  group('notifying during a build', () {
    testWidgets('load() from initState does not trip !_dirty', (tester) async {
      // AuthGate does exactly this on a restored session, and the Nutrition tab
      // does it on first show: initState runs DURING the build phase, so a
      // synchronous notifyListeners() there marks AppScope's dependents dirty
      // mid-build and the framework asserts. This is the crash on launch.
      backend = FakeBackend(
          profile: const Profile(benchGoalKg: 90, locale: AppLocale.ru));
      state = AppState(backend);
      addTearDown(state.dispose);
      addTearDown(backend.dispose);

      await tester.pumpWidget(AppScope(
        state: state,
        child: MaterialApp(home: _LoadsOnInit(state: state)),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // And the deferred notification still lands: the profile the account
      // saved is on screen, in its own language.
      expect(state.profile.benchGoalKg, 90);
      expect(find.text('Настройки'), findsOneWidget);
    });
  });

  group('no rebuild storm', () {
    testWidgets('the tree settles instead of rebuilding forever',
        (tester) async {
      // The launch bug: AuthGate fired load() from its StreamBuilder's builder,
      // load() notified, the notify rebuilt the tree, the rebuild fired load()
      // again… The tell was the quote card dealing a new quote every frame.
      backend = FakeBackend(profile: const Profile(benchGoalKg: 90));
      state = AppState(backend);
      addTearDown(state.dispose);
      addTearDown(backend.dispose);

      var builds = 0;
      await tester.pumpWidget(AppScope(
        state: state,
        child: MaterialApp(
          home: Builder(builder: (context) {
            builds++;
            // Depend on the state, as every real screen does.
            return Scaffold(body: Text(context.s.appTitle));
          }),
        ),
      ));

      await tester.pumpAndSettle(); // would time out if the loop were still live
      final settled = builds;

      // Nothing is asking for anything: further frames must not rebuild.
      await tester.pump(const Duration(seconds: 1));
      expect(builds, settled);
      expect(settled, lessThan(5));
    });
  });

  group('persistence', () {
    test('a language switch is written to the profile row', () async {
      build(profile: const Profile(locale: AppLocale.en));

      await state.update(locale: AppLocale.ru);

      // This row is what the Android app reads back: the sync contract.
      expect(backend.saves.single.toUpsert('u')['language'], 'ru');
    });

    test('a bench goal is written to the profile row', () async {
      build();

      await state.update(benchGoalKg: 90);

      expect(backend.saves.single.toUpsert('u')['bench_goal_kg'], 90.0);
    });

    test('a failed write rolls the UI back rather than lying about it',
        () async {
      build(profile: const Profile(benchGoalKg: 95));
      backend.failNextSave = Exception('network down');

      await expectLater(
        state.update(benchGoalKg: 90),
        throwsA(isA<Exception>()),
      );

      // The screen must not keep showing a goal the database never accepted.
      expect(state.profile.benchGoalKg, 95);
    });

    test('load() pulls the language and goal the account saved', () async {
      build();
      backend.saveProfile(
          const Profile(benchGoalKg: 92.5, locale: AppLocale.ru));

      await state.load();

      expect(state.locale, AppLocale.ru);
      expect(state.profile.benchGoalKg, 92.5);
      expect(state.s.settings, 'Настройки');
    });

    test('signed out, a language choice applies but writes nothing', () async {
      build();
      backend.signedIn = false;

      await state.update(locale: AppLocale.ru);

      // The sign-in screen's toggle: there is no row to write to yet.
      expect(state.locale, AppLocale.ru);
      expect(backend.saves, isEmpty);
    });
  });

  group('onboarding', () {
    test('a fresh profile needs onboarding; a stamped one does not', () {
      build(profile: const Profile());
      expect(state.needsOnboarding, isTrue);

      build(profile: Profile(onboardedAt: DateTime.utc(2026, 1, 1)));
      expect(state.needsOnboarding, isFalse);
    });

    test('completing it writes the metrics AND stamps onboardedAt', () async {
      build(profile: const Profile());

      await state.completeOnboarding(
        gender: Gender.female,
        heightCm: 165,
        weightKg: 61,
        age: 27,
        benchGoalKg: 60,
      );

      expect(state.needsOnboarding, isFalse);
      final saved = backend.saves.single;
      expect(saved.gender, Gender.female);
      expect(saved.heightCm, 165);
      expect(saved.weightKg, 61);
      expect(saved.age, 27);
      expect(saved.benchGoalKg, 60);
      expect(saved.onboardedAt, isNotNull);
      // The row the phone reads back carries the stamp too.
      expect(saved.toUpsert('u')['onboarded_at'], isNotNull);
    });

    test('a failed save leaves the gate shut, not falsely open', () async {
      build(profile: const Profile());
      backend.failNextSave = Exception('network down');

      await expectLater(
        state.completeOnboarding(
          gender: Gender.male,
          heightCm: 180,
          weightKg: 80,
          age: 30,
          benchGoalKg: 100,
        ),
        throwsA(isA<Exception>()),
      );

      // Nothing was flipped locally: the user is still held at onboarding and
      // can try again, rather than being dropped onto the tabs with a profile
      // that only exists on their screen.
      expect(state.needsOnboarding, isTrue);
      expect(backend.saves, isEmpty);
    });

    test('the loaded flag gates the flash of onboarding at launch', () async {
      build(profile: Profile(onboardedAt: DateTime.utc(2026, 1, 1)));
      // Before load(), nothing may be concluded.
      expect(state.loaded, isFalse);

      await state.load();
      expect(state.loaded, isTrue);
      expect(state.needsOnboarding, isFalse);
    });
  });

  group('theme', () {
    test('a theme switch is written to the profile row', () async {
      build(profile: const Profile(themeMode: AppThemeMode.dark));

      await state.update(themeMode: AppThemeMode.light);

      expect(state.themeMode, AppThemeMode.light);
      expect(backend.saves.single.toUpsert('u')['theme'], 'light');
    });

    test('signing out keeps the theme the user was looking at', () {
      build(profile: const Profile(themeMode: AppThemeMode.light));
      state.clear();
      expect(state.themeMode, AppThemeMode.light);
    });
  });

  group('milestones', () {
    test('a milestone is claimed once, then never again', () async {
      build(profile: const Profile(benchGoalKg: 90));

      expect(await state.claimMilestone(90), isTrue);
      expect(state.profile.hasCelebrated(90), isTrue);

      // Second call — e.g. the next session logged, still above the goal.
      expect(await state.claimMilestone(90), isFalse);
    });

    test('a milestone already banked on another device does not re-fire',
        () async {
      build(profile: const Profile(celebratedMilestones: [80.0]));

      expect(await state.claimMilestone(80), isFalse);
    });
  });

  test('signing out keeps the language but drops the account data', () {
    build(
      profile: const Profile(
        locale: AppLocale.ru,
        benchGoalKg: 90,
        weightKg: 101,
      ),
    );

    state.clear();

    // Being thrown back into English at the sign-in screen because you signed
    // out would be a bug, not a feature.
    expect(state.locale, AppLocale.ru);
    expect(state.profile.weightKg, 94); // back to defaults
    expect(state.profile.benchGoalKg, 95);
  });

  test('an out-of-range goal is clamped before it can reach the database',
      () async {
    build();

    await state.update(benchGoalKg: 10000);

    expect(state.profile.benchGoalKg, 500);
    expect(backend.saves.single.benchGoalKg, 500);
  });
}
