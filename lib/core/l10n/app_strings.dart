import '../../models/profile.dart';
import '../progression.dart';
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

  // -- settings --------------------------------------------------------------

  String get language;
  String get languageHint;
  String get benchGoalSection;
  String get benchGoalLabel;
  String get benchGoalHint;
  String benchGoalOutOfRange(double min, double max);
  String benchGoalSaved(String kg);

  /// Shown when Save succeeds, whatever was changed.
  String get settingsSaved;
  String get profileSection;
  String get genderHint;

  // -- training --------------------------------------------------------------

  String get estimated1rm;
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
}
