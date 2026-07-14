import 'package:bench_app/core/constants.dart';
import 'package:bench_app/core/l10n/app_locale.dart';
import 'package:bench_app/core/l10n/app_strings.dart';
import 'package:bench_app/core/progression.dart';
import 'package:bench_app/core/theme_mode.dart';
import 'package:bench_app/models/profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// Everything that must hold for EVERY language, run against every language —
/// so adding a third one cannot half-land.
void main() {
  group('every locale', () {
    for (final locale in AppLocale.values) {
      final s = AppStrings.of(locale);

      group(locale.code, () {
        test('resolves to itself', () {
          expect(s.locale, locale);
          expect(AppLocale.fromCode(locale.code), locale);
        });

        test('has no blank strings', () {
          // A missing translation is a compile error (AppStrings is an
          // interface); this catches the other half — one typed in as ''.
          final strings = <String, String>{
            'appTitle': s.appTitle,
            'tabTraining': s.tabTraining,
            'tabNutrition': s.tabNutrition,
            'settings': s.settings,
            'signOut': s.signOut,
            'signIn': s.signIn,
            'createAccount': s.createAccount,
            'language': s.language,
            'benchGoalSection': s.benchGoalSection,
            'benchGoalLabel': s.benchGoalLabel,
            'benchGoalHint': s.benchGoalHint,
            'onboardingTitle': s.onboardingTitle,
            'onboardingSubtitle': s.onboardingSubtitle,
            'onboardingIntro': s.onboardingIntro,
            'onboardingBodySection': s.onboardingBodySection,
            'onboardingGoalSection': s.onboardingGoalSection,
            'onboardingGoalHint': s.onboardingGoalHint,
            'onboardingFinish': s.onboardingFinish,
            'loadingProfile': s.loadingProfile,
            'theme': s.theme,
            'themeHint': s.themeHint,
            'estimated1rm': s.estimated1rm,
            'logSession': s.logSession,
            'warmupRamp': s.warmupRamp,
            'recentSessions': s.recentSessions,
            'dailyTargets': s.dailyTargets,
            'analyzeMeal': s.analyzeMeal,
            'mealsLogged': s.mealsLogged,
            'unitKg': s.unitKg,
            'unitKcal': s.unitKcal,
            'save': s.save,
            'delete': s.delete,
            'cancel': s.cancel,
            'retry': s.retry,
          };
          strings.forEach((name, value) {
            expect(value.trim(), isNotEmpty, reason: '$name is blank in $locale');
          });
        });

        test('translates every persisted workout type', () {
          for (final t in WorkoutType.all) {
            expect(s.workoutType(t).trim(), isNotEmpty);
          }
        });

        test('translates every persisted goal and activity level', () {
          for (final g in Goal.values) {
            expect(s.goalLabel(g).trim(), isNotEmpty);
            expect(s.goalDelta(g).trim(), isNotEmpty);
          }
          for (final a in ActivityLevel.values) {
            expect(s.activityLabel(a).trim(), isNotEmpty);
            expect(s.activityDescription(a).trim(), isNotEmpty);
          }
        });

        test('names every warm-up stage', () {
          for (final stage in WarmupStage.values) {
            expect(s.warmupLabel(stage).trim(), isNotEmpty);
            expect(s.warmupPurpose(stage).trim(), isNotEmpty);
          }
        });

        test('names both themes', () {
          for (final mode in AppThemeMode.values) {
            expect(s.themeLabel(mode).trim(), isNotEmpty);
          }
        });

        test('interpolates the metric range errors', () {
          expect(s.heightOutOfRange(100, 250),
              allOf(contains('100'), contains('250')));
          expect(s.weightOutOfRange(30, 300),
              allOf(contains('30'), contains('300')));
          expect(s.ageOutOfRange(13, 100),
              allOf(contains('13'), contains('100')));
        });

        test('interpolates its arguments rather than dropping them', () {
          expect(s.remainingToGoal('12.5', '95'), allOf(contains('12.5'), contains('95')));
          expect(s.percentOfGoal(87), contains('87'));
          expect(s.benchGoalSaved('90'), contains('90'));
          expect(s.plateauMessage(3, '70', '62.5'),
              allOf(contains('3'), contains('70'), contains('62.5')));
          expect(s.mealLogged('Oats', 550),
              allOf(contains('Oats'), contains('550')));
          expect(s.leftOf('40', s.unitGrams), contains('40'));
        });

        test('ships the same number of quotes as English', () {
          // QuoteCard picks by fraction of the list length; a short list in one
          // language would quietly make some quotes unreachable in it.
          expect(s.quotes, hasLength(AppStrings.of(AppLocale.en).quotes.length));
          for (final q in s.quotes) {
            expect(q.text.trim(), isNotEmpty);
            expect(q.author.trim(), isNotEmpty);
          }
        });
      });
    }
  });

  group('persisted values stay English', () {
    test('translating a workout type never changes what is stored', () {
      // The SQL CHECK constraint on workouts.workout_type accepts these three
      // strings and nothing else. If a translation ever leaked into the value
      // rather than the label, every insert in Russian would fail.
      expect(WorkoutType.heavy, 'Heavy Day (Strength)');
      expect(Goal.leanBulk.label, 'Lean Bulk');
      expect(ActivityLevel.veryActive.label, 'Very Active');

      const p = Profile(locale: AppLocale.ru, goal: Goal.cut);
      final row = p.toUpsert('u1');
      expect(row['goal'], 'Cut');
      expect(row['activity_level'], 'Moderately Active');
      expect(row['language'], 'ru');
    });

    test('the theme is stored as its code, matching the SQL CHECK', () {
      expect(AppThemeMode.dark.code, 'dark');
      expect(AppThemeMode.light.code, 'light');
      final row = const Profile(themeMode: AppThemeMode.light).toUpsert('u1');
      expect(row['theme'], 'light');
      expect(AppThemeMode.fromCode('nonsense'), AppThemeMode.dark);
    });
  });

  group('Russian plurals', () {
    final ru = AppStrings.of(AppLocale.ru);

    test('picks one / few / many, not a blanket plural', () {
      expect(ru.weeksCompleted(1), '1 неделя');
      expect(ru.weeksCompleted(3), '3 недели');
      expect(ru.weeksCompleted(5), '5 недель');
      expect(ru.weeksCompleted(11), '11 недель'); // the 11-14 exception
      expect(ru.weeksCompleted(21), '21 неделя');
      expect(ru.weeksCompleted(22), '22 недели');
      expect(ru.weeksCompleted(0), '0 недель');
    });
  });

  group('AppLocale', () {
    test('an unknown or missing code does not explode', () {
      expect(AppLocale.fromCode('de'), isA<AppLocale>());
      expect(AppLocale.fromCode(null), isA<AppLocale>());
    });

    test('the code is what the database stores', () {
      expect(AppLocale.en.code, 'en');
      expect(AppLocale.ru.code, 'ru');
    });
  });

  test('the default goal is the one the SQL column defaults to', () {
    expect(kDefaultGoalKg, 95.0);
    expect(const Profile().benchGoalKg, kDefaultGoalKg);
  });
}
