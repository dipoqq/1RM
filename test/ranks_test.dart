import 'package:bench_app/core/ranks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Ranks.ratio', () {
    test('is the big-three total divided by bodyweight', () {
      // 100 + 140 + 180 = 420 over 80 kg = 5.25×
      expect(Ranks.ratio(totalKg: 420, bodyweightKg: 80), closeTo(5.25, 1e-9));
    });

    test('a lighter lifter earns a higher ratio for the same total', () {
      final heavy = Ranks.ratio(totalKg: 400, bodyweightKg: 100)!;
      final light = Ranks.ratio(totalKg: 400, bodyweightKg: 70)!;
      expect(light, greaterThan(heavy));
    });

    test('an unusable bodyweight yields null, not a divide-by-zero', () {
      expect(Ranks.ratio(totalKg: 300, bodyweightKg: 0), isNull);
      expect(Ranks.ratio(totalKg: 300, bodyweightKg: -5), isNull);
      expect(Ranks.ratio(totalKg: 300, bodyweightKg: double.nan), isNull);
    });

    test('no lifts logged is a valid zero ratio', () {
      expect(Ranks.ratio(totalKg: 0, bodyweightKg: 80), 0);
    });
  });

  group('Ranks.forRatio boundaries', () {
    test('each threshold is inclusive at its lower bound', () {
      expect(Ranks.forRatio(0), StrengthRank.starter);
      expect(Ranks.forRatio(1.99), StrengthRank.starter);
      expect(Ranks.forRatio(2.0), StrengthRank.beginner);
      expect(Ranks.forRatio(3.49), StrengthRank.beginner);
      expect(Ranks.forRatio(3.5), StrengthRank.intermediate);
      expect(Ranks.forRatio(4.99), StrengthRank.intermediate);
      expect(Ranks.forRatio(5.0), StrengthRank.advanced);
      expect(Ranks.forRatio(6.99), StrengthRank.advanced);
      expect(Ranks.forRatio(7.0), StrengthRank.elite);
      expect(Ranks.forRatio(12), StrengthRank.elite);
    });
  });

  group('Ranks.forLifts', () {
    test('ranks a real intermediate lifter from their three bests', () {
      // 100/140/180 total 420 at 85 kg = 4.94× -> intermediate.
      final rank = Ranks.forLifts(
        benchKg: 100,
        squatKg: 140,
        deadliftKg: 180,
        bodyweightKg: 85,
      );
      expect(rank, StrengthRank.intermediate);
    });

    test('the SAME lifts against a lighter body can rank higher', () {
      final at100 = Ranks.forLifts(
          benchKg: 100, squatKg: 140, deadliftKg: 180, bodyweightKg: 100);
      final at70 = Ranks.forLifts(
          benchKg: 100, squatKg: 140, deadliftKg: 180, bodyweightKg: 70);
      // 420/100 = 4.2 (intermediate) vs 420/70 = 6.0 (advanced).
      expect(at100, StrengthRank.intermediate);
      expect(at70, StrengthRank.advanced);
    });

    test('a missing lift is a zero contribution, not a crash', () {
      final rank = Ranks.forLifts(
          benchKg: 60, squatKg: 0, deadliftKg: 0, bodyweightKg: 80);
      expect(rank, StrengthRank.starter);
    });

    test('an unusable bodyweight falls back to the lowest rank', () {
      final rank = Ranks.forLifts(
          benchKg: 200, squatKg: 300, deadliftKg: 400, bodyweightKg: 0);
      expect(rank, StrengthRank.starter);
    });
  });
}
