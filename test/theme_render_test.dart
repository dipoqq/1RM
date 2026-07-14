import 'package:bench_app/core/l10n/app_locale.dart';
import 'package:bench_app/core/theme.dart';
import 'package:bench_app/models/profile.dart';
import 'package:bench_app/state/app_state.dart';
import 'package:bench_app/ui/onboarding_screen.dart';
import 'package:bench_app/ui/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

/// The palette went from compile-time `static const` to a runtime
/// [ThemeExtension], and every screen now reads it through `context.colors`.
/// This exercises that path under a real [buildTheme] — both themes — so a
/// screen that forgot to read the extension (and fell back to the default)
/// or a `context.colors` with no theme above it would surface here as an
/// exception rather than a wrong colour nobody notices.
void main() {
  Widget host(AppState state, AppThemeMode mode, Widget child) => AppScope(
        state: state,
        child: MaterialApp(
          theme: buildTheme(mode),
          home: AppScope(state: state, child: child),
        ),
      );

  for (final mode in AppThemeMode.values) {
    testWidgets('onboarding paints under the ${mode.code} theme', (tester) async {
      final backend = FakeBackend(profile: Profile(themeMode: mode));
      final state = AppState(backend, initial: Profile(themeMode: mode));
      addTearDown(state.dispose);
      addTearDown(backend.dispose);

      await tester.pumpWidget(host(state, mode, OnboardingScreen(state: state)));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Welcome to 1RM.'), findsOneWidget);

      // The scaffold background is the theme's page colour, proving the
      // ThemeData actually carries this palette rather than the default.
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, isNull); // uses theme's scaffoldBackground
      expect(
        Theme.of(tester.element(find.byType(OnboardingScreen)))
            .scaffoldBackgroundColor,
        paletteFor(mode).bgSurface,
      );
    });

    testWidgets('settings paints under the ${mode.code} theme', (tester) async {
      final profile = Profile(themeMode: mode, locale: AppLocale.en);
      final backend = FakeBackend(profile: profile);
      final state = AppState(backend, initial: profile);
      addTearDown(state.dispose);
      addTearDown(backend.dispose);

      await tester.pumpWidget(host(state, mode, const SettingsScreen()));
      await tester.pump();

      expect(tester.takeException(), isNull);
      // The appearance switch itself is on screen.
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
    });
  }
}
