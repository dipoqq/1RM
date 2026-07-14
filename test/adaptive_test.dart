import 'package:bench_app/ui/widgets/adaptive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Size size) => MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox.fromSize(
            size: size,
            child: const AdaptiveColumns(
              header: Text('header'),
              primary: [Text('p1'), Text('p2')],
              secondary: [Text('s1')],
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('narrow: one column, everything stacked', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(const Size(400, 900)));

    expect(find.byType(ListView), findsOneWidget);
    // Primary and secondary both live in that single column.
    expect(find.text('p1'), findsOneWidget);
    expect(find.text('s1'), findsOneWidget);
    expect(find.text('header'), findsOneWidget);
  });

  testWidgets('wide: two independently-scrolling columns', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(const Size(1400, 900)));

    expect(find.byType(ListView), findsNWidgets(2));
    expect(find.text('p1'), findsOneWidget);
    expect(find.text('s1'), findsOneWidget);
    expect(find.text('header'), findsOneWidget);
  });

  testWidgets('wide: content is width-capped, not stretched to the window',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(const Size(1920, 900)));

    // On a 1920px monitor the columns must not span the whole width — that is
    // the whole point of the max-width cap.
    final row = tester.getSize(find.byType(Row).first);
    expect(row.width, lessThan(1920));
    expect(row.width, lessThanOrEqualTo(1180));
  });

  testWidgets('breakpoint flips exactly at kWideBreakpoint', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(const Size(kWideBreakpoint - 1, 900)));
    expect(find.byType(ListView), findsOneWidget);

    await tester.pumpWidget(host(const Size(kWideBreakpoint, 900)));
    expect(find.byType(ListView), findsNWidgets(2));
  });
}
