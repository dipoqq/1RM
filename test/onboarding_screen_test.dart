import 'package:bench_app/core/l10n/app_locale.dart';
import 'package:bench_app/models/profile.dart';
import 'package:bench_app/state/app_state.dart';
import 'package:bench_app/ui/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

/// The onboarding form, driven the way a new user drives it.
void main() {
  late FakeBackend backend;
  late AppState state;

  Future<void> open(WidgetTester tester, {AppLocale locale = AppLocale.en}) async {
    backend = FakeBackend(profile: Profile(locale: locale));
    state = AppState(backend, initial: Profile(locale: locale));
    addTearDown(state.dispose);
    addTearDown(backend.dispose);

    await tester.pumpWidget(AppScope(
      state: state,
      child: MaterialApp(
        home: AppScope(state: state, child: OnboardingScreen(state: state)),
      ),
    ));
  }

  /// Type into the field whose label starts with [labelPrefix]. The fields are
  /// numeric and unlabelled to the finder except by their decoration.
  Future<void> type(
      WidgetTester tester, String labelPrefix, String value) async {
    final field = find.ancestor(
      of: find.text(labelPrefix),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, value);
  }

  Future<void> finish(WidgetTester tester) async {
    final btn = find.widgetWithText(FilledButton, 'Start training');
    await tester.ensureVisible(btn);
    await tester.tap(btn);
  }

  testWidgets('the welcome header is shown, localized', (tester) async {
    await open(tester, locale: AppLocale.ru);
    expect(find.text('Добро пожаловать в 1RM.'), findsOneWidget);
    expect(find.text('Давайте настроим ваш профиль.'), findsOneWidget);
  });

  testWidgets('a complete form saves the metrics and stamps onboarding',
      (tester) async {
    await open(tester);

    await tester.tap(find.text('Female'));
    await type(tester, 'Height', '165');
    await type(tester, 'Bodyweight', '61');
    await type(tester, 'Age', '27');
    await type(tester, 'Target 1RM', '60');
    await finish(tester);
    // Not pumpAndSettle: on success the button holds its spinner, because the
    // real app swaps this screen out from AuthGate rather than resetting it —
    // the spinner would never settle. A couple of pumps lets the save land.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final saved = backend.saves.single;
    expect(saved.gender, Gender.female);
    expect(saved.heightCm, 165);
    expect(saved.weightKg, 61);
    expect(saved.age, 27);
    expect(saved.benchGoalKg, 60);
    expect(saved.onboardedAt, isNotNull);
    expect(state.needsOnboarding, isFalse);
  });

  testWidgets('nonsense metrics are rejected and nothing is saved',
      (tester) async {
    await open(tester);

    // Height left blank, a wildly wrong weight, a decimal age, a typo goal.
    await type(tester, 'Bodyweight', '2000');
    await type(tester, 'Age', '30.5');
    await type(tester, 'Target 1RM', '950');
    await finish(tester);
    await tester.pumpAndSettle();

    expect(backend.saves, isEmpty);
    expect(state.needsOnboarding, isTrue);
    // Every bad field is flagged at once, not one at a time.
    expect(find.text('Enter a height between 100 and 250 cm.'), findsOneWidget);
    expect(find.text('Enter a weight between 30 and 300 kg.'), findsOneWidget);
    expect(find.text('Enter an age between 13 and 100.'), findsOneWidget);
    expect(find.text('Enter a target between 20 and 500 kg.'), findsOneWidget);
  });

  testWidgets('a failed save keeps the user on the form', (tester) async {
    await open(tester);
    backend.failNextSave = Exception('network down');

    await type(tester, 'Height', '180');
    await type(tester, 'Bodyweight', '82');
    await type(tester, 'Age', '28');
    await type(tester, 'Target 1RM', '100');
    await finish(tester);
    await tester.pumpAndSettle();

    expect(state.needsOnboarding, isTrue);
    // The screen is still up and the button is usable again for a retry.
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Start training'), findsOneWidget);
  });
}
