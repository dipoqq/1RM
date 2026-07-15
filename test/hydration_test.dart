import 'package:bench_app/core/hydration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WaterMath.dailyTargetMl', () {
    test('is 35 ml per kg on a rest day', () {
      expect(WaterMath.dailyTargetMl(80), 2800); // 80 * 35
      expect(WaterMath.dailyTargetMl(94), 3290); // 94 * 35
    });

    test('adds the 600 ml training-day bonus', () {
      expect(WaterMath.dailyTargetMl(80, trainedOnDay: true), 3400);
      // The bonus is exactly the difference between the two.
      expect(
        WaterMath.dailyTargetMl(80, trainedOnDay: true) -
            WaterMath.dailyTargetMl(80),
        WaterMath.trainingDayBonusMl,
      );
    });

    test('scales with the live bodyweight', () {
      expect(WaterMath.dailyTargetMl(60), lessThan(WaterMath.dailyTargetMl(90)));
    });

    test('rounds to a whole millilitre', () {
      // 71.3 * 35 = 2495.5 -> 2496
      expect(WaterMath.dailyTargetMl(71.3), 2496);
    });

    test('an unusable weight yields no target rather than a made-up one', () {
      expect(WaterMath.dailyTargetMl(0), 0);
      expect(WaterMath.dailyTargetMl(-10), 0);
      expect(WaterMath.dailyTargetMl(double.nan), 0);
      expect(WaterMath.dailyTargetMl(0, trainedOnDay: true), 0);
    });
  });
}
