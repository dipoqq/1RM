import 'package:bench_app/models/profile.dart';
import 'package:bench_app/state/app_state.dart';
import 'package:bench_app/ui/tabs/nutrition_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'fake_backend.dart';

/// The gender field where it earns its keep: the Nutrition tab, where picking
/// it visibly re-scores the day's calories and macros.
void main() {
  late FakeBackend backend;
  late AppState state;

  // The calendar strip formats weekday names; without this it throws the same
  // LocaleDataException it would in a real app that forgot main()'s call.
  setUpAll(initializeDateFormatting);

  Future<void> open(WidgetTester tester, {Profile? profile}) async {
    backend = FakeBackend(profile: profile);
    state = AppState(backend, initial: profile);
    addTearDown(state.dispose);
    addTearDown(backend.dispose);

    await tester.pumpWidget(AppScope(
      state: state,
      child: MaterialApp(
        home: Scaffold(
          body: AppScope(state: state, child: NutritionTab(state: state)),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('the tab offers Male / Female and opens on the stored value',
      (tester) async {
    await open(tester, profile: const Profile(gender: Gender.female));

    expect(find.text('Gender'), findsOneWidget);
    expect(find.text('Male'), findsOneWidget);
    expect(find.text('Female'), findsOneWidget);

    // The control reflects the profile rather than defaulting to Male.
    final toggle = tester.widget<SegmentedButton<Gender>>(
      find.byType(SegmentedButton<Gender>),
    );
    expect(toggle.selected, {Gender.female});
  });

  testWidgets('switching gender rewrites the BMR line and the targets',
      (tester) async {
    // The reference lifter: 94 kg, 180 cm, 30 y, moderately active.
    //   male   BMR = 1920 → TDEE 2976 → +300 lean bulk = 3276 kcal
    //   female BMR = 1754 → TDEE 2719 → +300 lean bulk = 3019 kcal
    await open(tester, profile: const Profile());

    expect(find.textContaining('BMR 1920 kcal'), findsOneWidget);
    expect(find.text('3276'), findsOneWidget);

    await tester.tap(find.text('Female'));
    await tester.pumpAndSettle();

    // The arithmetic on screen moved…
    expect(find.textContaining('BMR 1754 kcal'), findsOneWidget);
    expect(find.text('3019'), findsOneWidget);
    expect(find.text('3276'), findsNothing);

    // …and the choice reached the database, not just the widget.
    expect(backend.saves.single.gender, Gender.female);
    expect(state.profile.gender, Gender.female);
  });
}
