import 'package:bench_app/core/l10n/app_locale.dart';
import 'package:bench_app/models/profile.dart';
import 'package:bench_app/services/backend.dart';
import 'package:bench_app/state/app_state.dart';
import 'package:bench_app/ui/auth_gate.dart';
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

  Future<void> launch(WidgetTester tester, {bool signedIn = true}) async {
    backend = FakeBackend(
      signedIn: signedIn,
      profile: const Profile(benchGoalKg: 90, locale: AppLocale.en),
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
}
