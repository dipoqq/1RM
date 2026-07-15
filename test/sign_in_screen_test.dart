import 'package:bench_app/core/l10n/app_locale.dart';
import 'package:bench_app/models/profile.dart';
import 'package:bench_app/state/app_state.dart';
import 'package:bench_app/ui/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'fake_backend.dart';

/// The sign-in screen's new surface: strict sign-up validation and the
/// "Забыл пароль" reset flow.
void main() {
  setUpAll(initializeDateFormatting);

  late FakeBackend backend;
  late AppState state;

  Future<void> pump(WidgetTester tester) async {
    backend = FakeBackend(
      signedIn: false,
      profile: const Profile(locale: AppLocale.en),
    );
    state = AppState(backend);
    addTearDown(state.dispose);
    addTearDown(backend.dispose);
    await tester.pumpWidget(AppScope(
      state: state,
      child: MaterialApp(home: AuthGate(state: state)),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('a weak password is rejected on sign-up, never sent', (t) async {
    await pump(t);

    // Switch to the create-account form.
    await t.tap(find.text('Create an account'));
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextField).at(0), 'lifter@example.com');
    await t.enterText(find.byType(TextField).at(1), 'weak');

    await t.tap(find.byType(FilledButton));
    await t.pumpAndSettle();

    // The first unmet rule is surfaced, and no account was created.
    expect(find.text('Password must be at least 8 characters.'), findsOneWidget);
    expect(backend.signedIn, isFalse);
  });

  testWidgets('a strong password is accepted on sign-up', (t) async {
    await pump(t);
    await t.tap(find.text('Create an account'));
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextField).at(0), 'lifter@example.com');
    await t.enterText(find.byType(TextField).at(1), 'Str0ng!pw');
    await t.tap(find.byType(FilledButton));
    await t.pumpAndSettle();

    expect(backend.signedIn, isTrue);
  });

  testWidgets('forgot-password sends a reset and confirms it', (t) async {
    await pump(t);

    await t.tap(find.text('Forgot password?'));
    await t.pumpAndSettle();

    expect(find.text('Reset your password'), findsWidgets);

    await t.enterText(find.byType(TextField).first, 'forgot@example.com');
    await t.tap(find.widgetWithText(FilledButton, 'Send reset link'));
    await t.pumpAndSettle();

    // The request reached the backend and the user got the neutral confirmation.
    expect(backend.passwordResets, ['forgot@example.com']);
    expect(find.textContaining('forgot@example.com'), findsOneWidget);
  });
}
