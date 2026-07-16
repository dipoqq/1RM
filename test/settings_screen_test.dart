import 'package:bench_app/core/l10n/app_locale.dart';
import 'package:bench_app/models/profile.dart';
import 'package:bench_app/state/app_state.dart';
import 'package:bench_app/ui/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

/// The real screen, driven the way a user drives it.
void main() {
  late FakeBackend backend;
  late AppState state;

  Future<void> open(WidgetTester tester, {Profile? profile}) async {
    backend = FakeBackend(profile: profile);
    state = AppState(backend, initial: profile);
    addTearDown(state.dispose);
    addTearDown(backend.dispose);

    await tester.pumpWidget(AppScope(
      state: state,
      child: MaterialApp(
        home: AppScope(state: state, child: const SettingsScreen()),
      ),
    ));
  }

  /// Save sits below the fold on the 800×600 test surface now that the screen
  /// carries language, theme and gender cards above the bench goal — scroll to
  /// it the way a thumb would.
  ///
  /// Every lift's goal card now carries its own identical Save button, and any
  /// of them commits all three fields — so tapping whichever one is built
  /// nearest (`.first`) is exactly what a user would do.
  Future<void> tapSave(WidgetTester tester, {String label = 'Save'}) async {
    final save = find.widgetWithText(FilledButton, label).first;
    await tester.ensureVisible(save);
    // Settle rather than pump once: the focused goal field schedules its own
    // keep-visible scroll, and while that programmatic scroll activity runs
    // the ListView ignores pointers — a tap mid-flight would hit nothing.
    await tester.pumpAndSettle();
    await tester.tap(save);
  }

  /// The bench goal field is below the fold for the same reason. A lazy
  /// ListView does not even build off-screen children, so scroll it into
  /// existence before typing — otherwise its editable state does not exist yet.
  ///
  /// The screen now carries three goal fields (bench, squat, deadlift), so the
  /// bench field is addressed by its key rather than by TextField type.
  Future<Finder> revealGoalField(WidgetTester tester) async {
    final field = find.byKey(const Key('benchGoalField'));
    // The screen's own ListView is the outermost Scrollable; the SegmentedButtons
    // above bring their own, so pin the scroll to the first one.
    await tester.scrollUntilVisible(field, 120,
        scrollable: find.byType(Scrollable).first);
    await tester.pump();
    return field;
  }

  testWidgets('typing a custom bench goal saves it and updates the app',
      (tester) async {
    await open(tester, profile: const Profile(benchGoalKg: 95));

    final field = await revealGoalField(tester);
    // The field opens on the goal in force.
    expect(find.widgetWithText(TextField, '95'), findsOneWidget);

    await tester.enterText(field, '90');
    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(state.profile.benchGoalKg, 90);
    expect(backend.saves.single.benchGoalKg, 90);
    // And the bench press metrics everywhere else now measure against 90.
    expect(state.profile.benchProgress(45).percent, 50);
  });

  testWidgets('a successful save is confirmed to the user', (tester) async {
    await open(tester, profile: const Profile(benchGoalKg: 95));

    await tester.enterText(await revealGoalField(tester), '100');
    await tapSave(tester);
    await tester.pump(); // let the SnackBar in

    // The confirmation names the lift that changed, not a generic "saved".
    expect(find.text('Goal for Bench Press updated.'), findsOneWidget);
  });

  testWidgets('the success message is localized', (tester) async {
    await open(tester, profile: const Profile(locale: AppLocale.ru));

    await tester.enterText(await revealGoalField(tester), '100');
    await tapSave(tester, label: 'Сохранить');
    await tester.pump();

    expect(find.text('Цель в жиме лёжа обновлена.'), findsOneWidget);
  });

  testWidgets('a typo is rejected instead of being persisted', (tester) async {
    await open(tester, profile: const Profile(benchGoalKg: 95));

    await tester.enterText(await revealGoalField(tester), '950'); // meant 95
    await tapSave(tester);
    await tester.pump();

    expect(find.text('Enter a target between 20 and 500 kg.'), findsOneWidget);
    expect(backend.saves, isEmpty);
    expect(state.profile.benchGoalKg, 95);
    // And a rejected goal is never dressed up as a success.
    expect(find.text('Settings saved successfully!'), findsNothing);
  });

  testWidgets('typing a squat goal saves it and syncs it', (tester) async {
    await open(tester, profile: const Profile(squatGoalKg: 140));

    final squat = find.byKey(const Key('squatGoalField'));
    await tester.scrollUntilVisible(squat, 120,
        scrollable: find.byType(Scrollable).first);
    await tester.pump();

    await tester.enterText(squat, '160');
    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(state.profile.squatGoalKg, 160);
    expect(backend.saves.single.squatGoalKg, 160);
    // Bench and deadlift were untouched, so only one write reached the backend.
    expect(backend.saves.single.benchGoalKg, state.profile.benchGoalKg);
    // And the confirmation names the squat — not the bench press.
    expect(find.text('Goal for Squat updated.'), findsOneWidget);
    expect(find.text('Goal for Bench Press updated.'), findsNothing);
  });

  testWidgets('a deadlift typo is rejected, not persisted', (tester) async {
    await open(tester, profile: const Profile(deadliftGoalKg: 200));

    final dl = find.byKey(const Key('deadliftGoalField'));
    await tester.scrollUntilVisible(dl, 120,
        scrollable: find.byType(Scrollable).first);
    await tester.pump();

    await tester.enterText(dl, '2000'); // meant 200
    await tapSave(tester);
    await tester.pump();

    expect(find.text('Enter a target between 20 and 500 kg.'), findsOneWidget);
    expect(backend.saves, isEmpty);
    expect(state.profile.deadliftGoalKg, 200);
  });

  testWidgets('picking a gender persists it and re-scores the targets',
      (tester) async {
    await open(tester, profile: const Profile()); // male by default

    final before = state.profile.targets.bmr;

    await tester.tap(find.text('Female'));
    await tester.pumpAndSettle();

    expect(state.profile.gender, Gender.female);
    expect(backend.saves.single.gender, Gender.female);
    // The whole point of the field: the daily targets move with it.
    expect(state.profile.targets.bmr, closeTo(before - 166, 0.01));
  });

  testWidgets('the language toggle switches the whole screen', (tester) async {
    await open(tester, profile: const Profile(locale: AppLocale.en));

    expect(find.text('Settings'), findsOneWidget); // the AppBar
    // SectionCard upper-cases its title, so this is the card heading. Scroll it
    // into view first: with language, theme and gender cards above it, the
    // bench card sits below the fold of the test surface.
    await tester.scrollUntilVisible(find.text('BENCH PRESS GOAL'), 120,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('BENCH PRESS GOAL'), findsOneWidget);

    await tester.tap(find.text('Русский'));
    await tester.pumpAndSettle();

    expect(find.text('Настройки'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('ЦЕЛЬ В ЖИМЕ ЛЁЖА'), 120,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('ЦЕЛЬ В ЖИМЕ ЛЁЖА'), findsOneWidget);
    expect(state.profile.locale, AppLocale.ru);
    expect(backend.saves.single.locale, AppLocale.ru);
  });
}
