import 'package:bench_app/core/achievements.dart';
import 'package:bench_app/ui/widgets/achievements_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

Achievement _a(String id, {bool unlocked = false, DateTime? at}) => Achievement(
      id: id,
      category: AchievementCategory.benchPress,
      unlocked: unlocked,
      unlockedAt: at,
    );

void main() {
  group('sortedForDisplay', () {
    test('unlocked rise above locked', () {
      final out = sortedForDisplay([
        _a('locked_1'),
        _a('unlocked_1', unlocked: true, at: DateTime(2026, 7, 1)),
        _a('locked_2'),
      ]);
      expect(out.first.id, 'unlocked_1');
      expect(out.map((a) => a.unlocked).toList(), [true, false, false]);
    });

    test('unlocked are ordered most-recent first', () {
      final out = sortedForDisplay([
        _a('older', unlocked: true, at: DateTime(2026, 5, 1)),
        _a('newest', unlocked: true, at: DateTime(2026, 7, 10)),
        _a('middle', unlocked: true, at: DateTime(2026, 6, 15)),
      ]);
      expect(out.map((a) => a.id).toList(), ['newest', 'middle', 'older']);
    });

    test('an unlocked achievement with no date still sorts after dated ones',
        () {
      final out = sortedForDisplay([
        _a('dated', unlocked: true, at: DateTime(2026, 7, 1)),
        _a('undated', unlocked: true),
      ]);
      expect(out.map((a) => a.id).toList(), ['dated', 'undated']);
    });

    test('does not drop or duplicate anything', () {
      final input = [
        _a('a', unlocked: true, at: DateTime(2026, 1, 1)),
        _a('b'),
        _a('c', unlocked: true, at: DateTime(2026, 2, 1)),
        _a('d'),
      ];
      final out = sortedForDisplay(input);
      expect(out.map((a) => a.id).toSet(), {'a', 'b', 'c', 'd'});
      expect(out, hasLength(4));
    });
  });
}
