import 'package:bench_app/core/l10n/app_locale.dart';
import 'package:bench_app/models/profile.dart';
import 'package:bench_app/services/backend.dart';
import 'package:bench_app/state/app_state.dart';
import 'package:bench_app/ui/auth_gate.dart';
import 'package:bench_app/ui/home_shell.dart';
import 'package:bench_app/ui/onboarding_screen.dart';
import 'package:bench_app/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'fake_backend.dart';

/// The launch path, end to end: AuthGate → HomeShell → the tabs.
///
/// This is the test the rebuild storm slipped past. The loop only forms when
/// AuthGate is in the tree, because AuthGate was the thing firing load() on
/// every rebuild — testing AppState alone could never have caught it.
void main() {
  late FakeBackend backend;
  late AppState state;

  // The calendar strip formats weekday names per locale; without this the very
  // first frame throws LocaleDataException. main() does the same thing at boot.
  setUpAll(initializeDateFormatting);

  Future<void> launch(
    WidgetTester tester, {
    bool signedIn = true,
    Profile? profile,
  }) async {
    backend = FakeBackend(
      signedIn: signedIn,
      // Onboarded by default: these tests are about the launch path THROUGH to
      // the tabs, so the profile has to be one that reaches HomeShell rather
      // than being held at onboarding. Tests that want the gate pass their own.
      profile: profile ??
          Profile(
            benchGoalKg: 90,
            locale: AppLocale.en,
            onboardedAt: DateTime.utc(2026, 1, 1),
          ),
    );
    state = AppState(backend);
    addTearDown(state.dispose);
    addTearDown(backend.dispose);

    await tester.pumpWidget(AppScope(
      state: state,
      child: MaterialApp(home: AuthGate(state: state)),
    ));
  }

  testWidgets('a signed-in launch settles instead of rebuilding forever',
      (tester) async {
    await launch(tester);

    // pumpAndSettle times out if frames never stop being scheduled — which is
    // exactly what the storm did.
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The profile landed: the app is running against the account's own goal.
    expect(state.profile.benchGoalKg, 90);
  });

  testWidgets('the quote does not change on an unrelated rebuild',
      (tester) async {
    await launch(tester);
    await tester.pumpAndSettle();

    String currentQuote() => tester
        .widget<Text>(find.descendant(
          of: find.byType(QuoteCard),
          matching: find.byType(Text).first,
        ))
        .data!;

    final before = currentQuote();

    // A language switch is an unrelated rebuild. The quote must be the SAME
    // quote, translated — not a new roll of the dice. Flickering quotes were
    // the visible symptom of the storm.
    await state.update(locale: AppLocale.ru);
    await tester.pumpAndSettle();

    expect(currentQuote(), isNot(before)); // it is in Russian now…
    final ru = currentQuote();

    await state.update(benchGoalKg: 92.5); // …and a further rebuild
    await tester.pumpAndSettle();

    expect(currentQuote(), ru); // …does not re-roll it
  });

  testWidgets('a token refresh does not re-fetch the profile', (tester) async {
    await launch(tester);
    await tester.pumpAndSettle();

    final atLaunch = backend.profileFetches;

    // Supabase emits signedIn on every token refresh. That is not a transition,
    // so it must do no work — and above all must not start the load/notify/
    // rebuild cycle again.
    backend.emit(AuthStatus.signedIn);
    await tester.pumpAndSettle();

    expect(backend.profileFetches, atLaunch);
  });

  testWidgets('signing out returns to the sign-in screen', (tester) async {
    await launch(tester);
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsNothing);

    backend.signedIn = false;
    backend.emit(AuthStatus.signedOut);
    await tester.pumpAndSettle();

    expect(find.byType(SignInScreen), findsOneWidget);
  });

  testWidgets('a never-onboarded account is held at onboarding, not the tabs',
      (tester) async {
    // onboardedAt null: the whole point of the milestone — a brand-new account
    // must not land on the tabs against the 180/94 defaults.
    await launch(tester,
        profile: const Profile(benchGoalKg: 90, locale: AppLocale.en));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(HomeShell), findsNothing);
  });

  testWidgets('an onboarded account goes straight to the tabs', (tester) async {
    await launch(tester); // fixture is onboarded
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(HomeShell), findsOneWidget);
  });

  testWidgets('completing onboarding swaps the screen for the tabs',
      (tester) async {
    await launch(tester,
        profile: const Profile(benchGoalKg: 90, locale: AppLocale.en));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);

    // The gate is driven entirely by the profile: the moment onboarding is
    // saved, AuthGate re-runs its branch and shows HomeShell — no navigation.
    await state.completeOnboarding(
      gender: Gender.male,
      heightCm: 178,
      weightKg: 82,
      age: 28,
      benchGoalKg: 100,
    );
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(HomeShell), findsOneWidget);
    // And what the tabs run against is what the lifter actually entered.
    expect(state.profile.weightKg, 82);
    expect(state.profile.needsOnboarding, isFalse);
  });
}
