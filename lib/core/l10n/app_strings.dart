import '../../models/profile.dart';
import '../password_policy.dart';
import '../progression.dart';
import '../ranks.dart';
import '../theme_mode.dart';
import 'app_locale.dart';
import 'strings_en.dart';
import 'strings_ru.dart';

/// Every user-visible string in the app, as typed members.
///
/// An interface rather than a `Map<String, String>` on purpose: a missing
/// Russian translation is then a compile error, not a runtime `null` that ships
/// to a phone and renders as a blank label. Parameterised strings are methods,
/// so the argument order cannot drift between languages either.
///
/// What is deliberately NOT in here: the values persisted in Supabase
/// (`WorkoutType.heavy`, `Goal.leanBulk.label`, `ActivityLevel.*.label`). Those
/// are stored verbatim and guarded by SQL CHECK constraints, so they stay
/// English in the database and are translated only on the way to the screen —
/// see [workoutType], [goalLabel] and [activityLabel].
abstract interface class AppStrings {
  /// The strings for [locale]. The one lookup in the app.
  static AppStrings of(AppLocale locale) => switch (locale) {
        AppLocale.en => const EnStrings(),
        AppLocale.ru => const RuStrings(),
      };

  AppLocale get locale;

  // -- shell -----------------------------------------------------------------

  String get appTitle;
  String get tabTraining;
  String get tabNutrition;
  String get signOut;
  String get settings;
  String get cancel;
  String get delete;
  String get retry;
  String get save;

  // -- boot / auth -----------------------------------------------------------

  String get configMissing;
  String get signInSubtitle;
  String get signUpSubtitle;
  String get email;
  String get password;
  String get credentialsRequired;
  String get signIn;
  String get createAccount;
  String get haveAccount;

  // -- password reset & policy ----------------------------------------------

  /// The "Забыл пароль" link on the sign-in screen.
  String get forgotPassword;
  String get resetPasswordTitle;
  String get resetPasswordSubtitle;
  String get sendResetLink;
  String get backToSignIn;

  /// Shown after a reset request. Deliberately does not confirm whether the
  /// address has an account — that would leak which emails are registered.
  String resetEmailSent(String email);

  /// One line listing every password rule, shown under the field on sign-up.
  String get passwordRequirements;

  /// The message for the first rule a candidate password fails.
  String passwordRuleError(PasswordRule rule);

  // -- connectivity / offline sync ------------------------------------------

  /// The small badge shown while the device is offline.
  String get offlineMode;

  /// The non-blocking banner explaining that logging still works offline.
  String get offlineBanner;

  /// "N workouts waiting to sync" — the pending draft count.
  String pendingSync(int count);

  /// Shown briefly while queued drafts are being flushed on reconnect.
  String get syncing;

  /// Snackbar when a workout is saved to the local queue instead of the server.
  String get savedOffline;

  // -- onboarding ------------------------------------------------------------

  /// "Welcome to 1RM." — the header on first run.
  String get onboardingTitle;

  /// "Let's set up your profile."
  String get onboardingSubtitle;
  String get onboardingIntro;
  String get onboardingBodySection;
  String get onboardingGoalSection;
  String get onboardingGoalHint;
  String get onboardingFinish;

  /// The gate's spinner, while the profile is being pulled.
  String get loadingProfile;

  String heightOutOfRange(double min, double max);
  String weightOutOfRange(double min, double max);
  String ageOutOfRange(int min, int max);

  // -- settings --------------------------------------------------------------

  String get language;
  String get languageHint;
  String get theme;
  String get themeHint;
  String themeLabel(AppThemeMode mode);
  String get benchGoalSection;
  String get benchGoalLabel;
  String get benchGoalHint;
  String benchGoalOutOfRange(double min, double max);
  String benchGoalSaved(String kg);

  /// The Squat & Deadlift target-1RM card and its two fields.
  String get strengthGoalsSection;
  String get strengthGoalsHint;
  String get squatGoalLabel;
  String get deadliftGoalLabel;

  /// Shown when Save succeeds, whatever was changed.
  String get settingsSaved;
  String get profileSection;
  String get genderHint;

  // -- training --------------------------------------------------------------

  String get estimated1rm;

  /// The strength-rank ("Звание") badge: its heading, the localized rank name,
  /// and the relative-strength caption ("×4.2 bodyweight").
  String get rankTitle;
  String rankLabel(StrengthRank rank);
  String rankRatio(String multiple);

  String weeksCompleted(int weeks);
  String goalCleared(String goalKg);
  String remainingToGoal(String remainingKg, String goalKg);
  String percentOfGoal(int percent);
  String get plateauTitle;
  String plateauMessage(int streak, String from, String to);
  String loadWeight(String kg);
  String get logSession;
  String get workoutTypeField;
  String get weight;
  String get reps;
  String get sets;
  String get allSetsCompleted;
  String get failedReps;
  String get failedDrivePlateau;
  String get logSessionButton;
  String get sessionLogged;
  String get enterPositiveNumbers;
  String couldNotSave(String error);
  String get warmupRamp;
  String warmupTo(String kg);
  String get warmupFootnote;
  String warmupLabel(WarmupStage stage);
  String warmupPurpose(WarmupStage stage);
  String get recentSessions;
  String get noSessions;

  // -- progression coach -----------------------------------------------------

  /// The "Получить план прогрессии" button and its surrounding card.
  String get getProgressionPlan;
  String get coachTitle;
  String get coachIntro;
  String get coachThinking;
  String get coachNeedsHistory;
  String coachFailed(String error);
  String get backToWork;
  String milestoneTitle(String kg);
  String milestoneSubtitle(bool isFinal);
  String milestoneBody(String bestKg);

  /// Translates a `workouts.workout_type` value for display. The argument is
  /// the English string persisted in the database.
  String workoutType(String persisted);

  // -- nutrition -------------------------------------------------------------

  String get today;
  String get dailyTargets;
  String get bodyweight;
  String get height;
  String get age;
  String get unitKg;
  String get unitCm;
  String get unitYears;
  String get unitGrams;

  /// Single-letter macro tags in the meal list ("94 C / 9 F").
  String get carbsInitial;
  String get fatsInitial;
  String get gender;
  String get activityLevel;
  String get goal;
  String bmrLine(int bmr, double multiplier, String activity, int tdee);
  String get unitKcal;
  String get gProtein;
  String get gCarbs;
  String get gFats;
  String tdeeAnd(String delta);
  String proteinPerKg(String kg);
  String get remainingCalories;
  String fatsShare(int kcal);
  String get calories;
  String get protein;
  String get carbs;
  String get fats;
  String overBy(String amount, String unit);
  String leftOf(String amount, String unit);
  String get analyzeMeal;
  String get describeHint;
  String get upload;
  String get camera;
  String get analyzeFood;
  String get analyzing;
  String get addManually;
  String get mealsLogged;
  String get clearDaysLog;
  String get clearDayTitle;
  String clearDayBody(int count, String day);
  String dayCleared(String day);
  String get nothingLogged;
  String addMealOn(String day);
  String get mealName;
  String get addMeal;
  String get mealFieldsRequired;
  String get describeOrPhoto;
  String get geminiNotConfigured;
  String get geminiNoDataBlock;
  String mealLogged(String name, int kcal);
  String analysisFailed(String error);
  String couldNotLoad(String error);
  String couldNotSaveSettings(String error);
  String couldNotOpenPicker(String error);
  String viewingHistory(String date);
  String get viewingHistoryBody;
  String get backToToday;

  /// Translates a `profiles.gender` / `profiles.goal` / `profiles.activity_level`
  /// value for display. The enum carries the persisted English label; these
  /// render it.
  String genderLabel(Gender gender);
  String goalLabel(Goal goal);
  String goalDelta(Goal goal);
  String activityLabel(ActivityLevel activity);
  String activityDescription(ActivityLevel activity);

  // -- content ---------------------------------------------------------------

  /// The iron/discipline quotes, translated. Author names stay in their own
  /// script per language (Cyrillic transliteration in Russian).
  List<({String text, String author})> get quotes;

  /// Instruction appended to the Gemini system prompt so the nutritionist
  /// answers in the language the user is reading the app in.
  String get geminiReplyLanguage;

  // -- hydration -------------------------------------------------------------
  String get hydrationTitle;
  String hydrationLogged(int current, int target);

  // -- reminders -------------------------------------------------------------
  String get remindersTitle;
  String get reminderTakeCreatine;
  String get reminderEatMeal;
  String get reminderHydrate;
  String get reminderWorkoutTime;
  String get reminderNoTime;
  String get reminderTapToSchedule;
  String get reminderAddTime;

  // -- history / progress ----------------------------------------------------
  String get historyTitle;
  String get historyChartTitle;
  String get historyPersonalRecords;
  String get historyNoData;

  /// e.g. "+15 kg since start".
  String historySinceStart(String kg);

  // -- achievements ----------------------------------------------------------
  String get achievementsTitle;
  String get achievementsBenchPress;
  String get achievementsSquats;
  String get achievementsDeadlift;
  String get achievementsEasterEggs;
  String get achievementNotUnlocked;
  String achievementUnlockedToast(String title);
  String achievementUnlockedAt(String date);

  String achievementTitle(String id);
  String achievementDesc(String id);
}
