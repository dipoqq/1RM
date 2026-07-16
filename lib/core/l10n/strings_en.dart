import '../../models/profile.dart';
import '../../models/workout.dart';
import '../password_policy.dart';
import '../progression.dart';
import '../ranks.dart';
import '../theme_mode.dart';
import 'app_locale.dart';
import 'app_strings.dart';

/// English — the reference language. Every other implementation of [AppStrings]
/// is judged against this one.
class EnStrings implements AppStrings {
  const EnStrings();

  @override
  AppLocale get locale => AppLocale.en;

  // -- shell -----------------------------------------------------------------

  @override
  String get appTitle => '1RM';
  @override
  String get tabTraining => 'Training';
  @override
  String get tabNutrition => 'Nutrition';
  @override
  String get signOut => 'Sign out';
  @override
  String get settings => 'Settings';
  @override
  String get cancel => 'Cancel';
  @override
  String get delete => 'Delete';
  @override
  String get retry => 'Retry';
  @override
  String get save => 'Save';

  // -- boot / auth -----------------------------------------------------------

  @override
  String get configMissing => 'Configuration missing';
  @override
  String get signInSubtitle => 'Sign in to sync across your devices.';
  @override
  String get signUpSubtitle => 'Create the account your data syncs to.';
  @override
  String get email => 'Email';
  @override
  String get password => 'Password';
  @override
  String get credentialsRequired => 'Email and password are required.';
  @override
  String get signIn => 'Sign in';
  @override
  String get createAccount => 'Create an account';
  @override
  String get haveAccount => 'I already have an account';

  // -- password reset & policy ----------------------------------------------

  @override
  String get forgotPassword => 'Forgot password?';
  @override
  String get resetPasswordTitle => 'Reset your password';
  @override
  String get resetPasswordSubtitle =>
      'Enter the email you signed up with and we will send you a link to set a '
      'new password.';
  @override
  String get sendResetLink => 'Send reset link';
  @override
  String get backToSignIn => 'Back to sign in';
  @override
  String resetEmailSent(String email) =>
      'If an account exists for $email, a password reset link is on its way. '
      'Check your inbox.';
  @override
  String get passwordRequirements =>
      'At least 8 characters, with upper- and lowercase letters, a digit and a '
      'symbol.';
  @override
  String passwordRuleError(PasswordRule rule) => switch (rule) {
        PasswordRule.minLength => 'Password must be at least 8 characters.',
        PasswordRule.lowercase =>
          'Password must include a lowercase letter.',
        PasswordRule.uppercase =>
          'Password must include an uppercase letter.',
        PasswordRule.digit => 'Password must include a digit.',
        PasswordRule.symbol => 'Password must include a symbol.',
      };

  // -- connectivity / offline sync ------------------------------------------

  @override
  String get offlineMode => 'Offline Mode';
  @override
  String get offlineBanner =>
      "You're offline. Keep logging — your workouts save on this device and "
      'sync automatically when you reconnect.';
  @override
  String pendingSync(int count) =>
      '$count ${count == 1 ? 'workout' : 'workouts'} waiting to sync';
  @override
  String get syncing => 'Syncing…';
  @override
  String get savedOffline => 'Saved offline — will sync when you reconnect.';

  // -- onboarding ------------------------------------------------------------

  @override
  String get onboardingTitle => 'Welcome to 1RM.';
  @override
  String get onboardingSubtitle => "Let's set up your profile.";
  @override
  String get onboardingIntro =>
      'These numbers drive your daily calorie and macro targets, and the bench '
      'press goal every session is measured against. You can change any of '
      'them later in Settings.';
  @override
  String get onboardingBodySection => 'About you';
  @override
  String get onboardingGoalSection => 'Your bench press goal';
  @override
  String get onboardingGoalHint =>
      'The 1RM you are training toward. Clearing it fires the confetti.';
  @override
  String get onboardingFinish => 'Start training';
  @override
  String get loadingProfile => 'Loading your profile…';
  @override
  String heightOutOfRange(double min, double max) =>
      'Enter a height between ${min.round()} and ${max.round()} cm.';
  @override
  String weightOutOfRange(double min, double max) =>
      'Enter a weight between ${min.round()} and ${max.round()} kg.';
  @override
  String ageOutOfRange(int min, int max) =>
      'Enter an age between $min and $max.';

  // -- settings --------------------------------------------------------------

  @override
  String get language => 'Language';
  @override
  String get languageHint =>
      'Applies immediately and syncs to your other devices.';
  @override
  String get theme => 'Appearance';
  @override
  String get themeHint =>
      'Applies immediately and syncs to your other devices.';
  @override
  String themeLabel(AppThemeMode mode) => switch (mode) {
        AppThemeMode.dark => 'Dark',
        AppThemeMode.light => 'Light',
      };
  @override
  String get benchGoalSection => 'Bench press goal';
  @override
  String get benchGoalLabel => 'Target 1RM';
  @override
  String get benchGoalHint =>
      'Drives the progress bar, the weight remaining and the completion '
      'percentage. Clearing this target fires the confetti.';
  @override
  String benchGoalOutOfRange(double min, double max) =>
      'Enter a target between ${min.round()} and ${max.round()} kg.';
  @override
  String benchGoalSaved(String kg) => 'Bench press goal set to $kg kg.';
  @override
  String get squatGoalSection => 'Squat goal';
  @override
  String get squatGoalHint =>
      'Target 1RM for your squat. Drives the progress bar, charts and the '
      'home-screen widget when the squat is selected.';
  @override
  String get squatGoalLabel => 'Squat target 1RM';
  @override
  String get deadliftGoalSection => 'Deadlift goal';
  @override
  String get deadliftGoalHint =>
      'Target 1RM for your deadlift. Drives the progress bar, charts and the '
      'home-screen widget when the deadlift is selected.';
  @override
  String get deadliftGoalLabel => 'Deadlift target 1RM';
  @override
  String goalSaved(Exercise exercise) => switch (exercise) {
        Exercise.benchPress => 'Goal for Bench Press updated.',
        Exercise.squat => 'Goal for Squat updated.',
        Exercise.deadlift => 'Goal for Deadlift updated.',
      };
  @override
  String get settingsSaved => 'Settings saved successfully!';
  @override
  String get widgetSection => 'Home-screen widget';
  @override
  String get widgetExerciseHint =>
      'Which lift the strength widget on your home screen tracks. It updates '
      'the moment you log or delete a session.';
  @override
  String exerciseName(Exercise exercise) => switch (exercise) {
        Exercise.benchPress => 'Bench press',
        Exercise.squat => 'Squat',
        Exercise.deadlift => 'Deadlift',
      };
  @override
  String get widgetNutritionTitle => 'Nutrition · Today';
  @override
  String get profileSection => 'Account';
  @override
  String get genderHint =>
      'Selects the Mifflin-St Jeor equation your daily calorie and macro '
      'targets are built on.';

  // -- training --------------------------------------------------------------

  @override
  String get estimated1rm => 'Estimated 1RM (Epley)';
  @override
  String get rankTitle => 'Strength rank';
  @override
  String rankLabel(StrengthRank rank) => switch (rank) {
        StrengthRank.starter => 'Starter',
        StrengthRank.beginner => 'Beginner',
        StrengthRank.intermediate => 'Intermediate',
        StrengthRank.advanced => 'Advanced',
        StrengthRank.elite => 'Elite / Machine',
      };
  @override
  String rankRatio(String multiple) => '×$multiple bodyweight total';
  @override
  String weeksCompleted(int weeks) => '$weeks weeks';
  @override
  String goalCleared(String goalKg) =>
      'Goal cleared — $goalKg kg is behind you.';
  @override
  String remainingToGoal(String remainingKg, String goalKg) =>
      '$remainingKg kg to the $goalKg kg goal.';
  @override
  String percentOfGoal(int percent) => '$percent% of goal';
  @override
  String get plateauTitle => 'Plateau detected — deload block forced';
  @override
  String plateauMessage(int streak, String from, String to) =>
      '$streak consecutive heavy days failed. Grinding the same weight from '
      'here buys nothing but an injury. Drop 10% to $to kg (from $from kg), '
      'rebuild momentum, then climb again.';
  @override
  String loadWeight(String kg) => 'Load $kg kg';
  @override
  String get logSession => 'Log a session';
  @override
  String get workoutTypeField => 'Workout type';
  @override
  String get weight => 'Weight';
  @override
  String get reps => 'Reps';
  @override
  String get sets => 'Sets';
  @override
  String get allSetsCompleted => 'All sets completed';
  @override
  String get failedReps => 'Failed / missed reps';
  @override
  String get failedDrivePlateau =>
      'Failed heavy days drive the plateau detector.';
  @override
  String get logSessionButton => 'Log session';
  @override
  String get sessionLogged => 'Session logged.';
  @override
  String get enterPositiveNumbers =>
      'Enter a weight, reps and sets greater than zero.';
  @override
  String couldNotSave(String error) => 'Could not save: $error';
  @override
  String get warmupRamp => 'Warm-up ramp';
  @override
  String warmupTo(String kg) => 'to $kg kg';
  @override
  String get warmupFootnote =>
      'Every load is snapped to a real 2.5 kg increment and floored at the '
      'empty 20 kg bar.';
  @override
  String warmupLabel(WarmupStage stage) => switch (stage) {
        WarmupStage.bar => 'Empty Bar',
        WarmupStage.sixty => '60%',
        WarmupStage.eighty => '80%',
        WarmupStage.ninety => '90%',
      };
  @override
  String warmupPurpose(WarmupStage stage) => switch (stage) {
        WarmupStage.bar => 'Blood flow & joint lubrication',
        WarmupStage.sixty => 'Grooving the movement pattern',
        WarmupStage.eighty => 'CNS activation',
        WarmupStage.ninety => 'Heavy single - feel the load, no fatigue',
      };
  @override
  String get recentSessions => 'Recent sessions';
  @override
  String get noSessions => 'No sessions logged yet.';
  @override
  String get getProgressionPlan => 'Get progression plan';
  @override
  String get coachTitle => 'Your progression plan';
  @override
  String get coachIntro =>
      'Let the AI coach read your recent sessions, spot plateaus and prescribe '
      'your next weights.';
  @override
  String get coachThinking => 'Building your plan…';
  @override
  String get coachNeedsHistory =>
      'Log a few sessions first so the coach has something to work with.';
  @override
  String coachFailed(String error) => 'Could not build a plan: $error';
  @override
  String get backToWork => 'Back to work';
  @override
  String milestoneTitle(String kg) => '$kg KG!';
  @override
  String milestoneSubtitle(bool isFinal) => isFinal
      ? 'Your bench press goal is smashed.'
      : 'Intermediate milestone cleared.';
  @override
  String milestoneBody(String bestKg) => 'Estimated 1RM: $bestKg kg.';

  @override
  String workoutType(String persisted) => persisted;

  // -- nutrition -------------------------------------------------------------

  @override
  String get today => 'Today';
  @override
  String get dailyTargets => 'Daily targets';
  @override
  String get bodyweight => 'Bodyweight';
  @override
  String get height => 'Height';
  @override
  String get age => 'Age';
  @override
  String get unitKg => 'kg';
  @override
  String get unitCm => 'cm';
  @override
  String get unitYears => 'y';
  @override
  String get unitGrams => 'g';
  @override
  String get carbsInitial => 'C';
  @override
  String get fatsInitial => 'F';
  @override
  String get proteinInitial => 'P';
  @override
  String get gender => 'Gender';
  @override
  String get activityLevel => 'Activity level';
  @override
  String get goal => 'Goal';
  @override
  String bmrLine(int bmr, double multiplier, String activity, int tdee) =>
      'BMR $bmr kcal  ×$multiplier ($activity)  =  TDEE $tdee kcal';
  @override
  String get unitKcal => 'kcal';
  @override
  String get gProtein => 'g protein';
  @override
  String get gCarbs => 'g carbs';
  @override
  String get gFats => 'g fats';
  @override
  String tdeeAnd(String delta) => 'TDEE · $delta';
  @override
  String proteinPerKg(String kg) => '2.0 g × $kg kg';
  @override
  String get remainingCalories => 'remaining calories';
  @override
  String fatsShare(int kcal) => '25% of $kcal kcal';
  @override
  String get calories => 'Calories';
  @override
  String get protein => 'Protein';
  @override
  String get carbs => 'Carbs';
  @override
  String get fats => 'Fats';
  @override
  String overBy(String amount, String unit) => '$amount $unit over';
  @override
  String leftOf(String amount, String unit) => '$amount $unit left';
  @override
  String get analyzeMeal => 'Analyze a meal';
  @override
  String get describeHint => 'e.g. 200 g chicken breast, 150 g rice, olive oil…';
  @override
  String get upload => 'Upload';
  @override
  String get camera => 'Camera';
  @override
  String get analyzeFood => 'Analyze food';
  @override
  String get analyzing => 'Analyzing…';
  @override
  String get addManually => 'Add manually instead';
  @override
  String get mealsLogged => 'Meals logged';
  @override
  String get clearDaysLog => "Clear day's log";
  @override
  String get clearDayTitle => "Clear this day's log?";
  @override
  String clearDayBody(int count, String day) =>
      'This permanently deletes all $count meals logged on $day. Other days '
      'are untouched. This cannot be undone.';
  @override
  String dayCleared(String day) => 'Cleared $day.';
  @override
  String get nothingLogged => 'Nothing logged on this day.';
  @override
  String addMealOn(String day) => 'Add meal · $day';
  @override
  String get mealName => 'Meal name';
  @override
  String get addMeal => 'Add meal';
  @override
  String get mealFieldsRequired => 'Name, calories and protein are required.';
  @override
  String get describeOrPhoto =>
      'Describe your meal or attach a photo of your plate.';
  @override
  String get geminiNotConfigured =>
      'GEMINI_API_KEY was not passed at build time. See README.md.';
  @override
  String get geminiNoDataBlock =>
      'Gemini did not return usable macros — add the meal manually.';
  @override
  String mealLogged(String name, int kcal) => 'Logged "$name" · $kcal kcal.';
  @override
  String analysisFailed(String error) => 'Analysis failed: $error';
  @override
  String couldNotLoad(String error) => 'Could not load: $error';
  @override
  String couldNotSaveSettings(String error) =>
      'Could not save settings: $error';
  @override
  String couldNotOpenPicker(String error) =>
      'Could not open the picker: $error';
  @override
  String viewingHistory(String date) => 'Viewing History: $date';
  @override
  String get viewingHistoryBody =>
      'Anything you log now is recorded against this date, not today.';
  @override
  String get backToToday => 'Back to today';

  @override
  String genderLabel(Gender gender) => switch (gender) {
        Gender.male => 'Male',
        Gender.female => 'Female',
      };
  @override
  String goalLabel(Goal goal) => switch (goal) {
        Goal.leanBulk => 'Lean Bulk',
        Goal.maintenance => 'Maintenance',
        Goal.cut => 'Cut',
      };
  @override
  String goalDelta(Goal goal) => goal.kcalDelta == 0
      ? 'maintenance'
      : '${goal.kcalDelta > 0 ? '+' : ''}${goal.kcalDelta} kcal';
  @override
  String activityLabel(ActivityLevel activity) => switch (activity) {
        ActivityLevel.sedentary => 'Sedentary',
        ActivityLevel.lightlyActive => 'Lightly Active',
        ActivityLevel.moderatelyActive => 'Moderately Active',
        ActivityLevel.veryActive => 'Very Active',
      };
  @override
  String activityDescription(ActivityLevel activity) => switch (activity) {
        ActivityLevel.sedentary => 'Little to no exercise',
        ActivityLevel.lightlyActive => 'Light exercise 1-3 days/week',
        ActivityLevel.moderatelyActive => 'Moderate exercise 3-5 days/week',
        ActivityLevel.veryActive => 'Heavy exercise 6-7 days/week',
      };

  // -- content ---------------------------------------------------------------

  @override
  List<({String text, String author})> get quotes => const [
        (
          text: 'The last three or four reps is what makes the muscle grow. '
              'This area of pain divides a champion from someone who is not a '
              'champion.',
          author: 'Arnold Schwarzenegger'
        ),
        (
          text: "Everybody wants to be a bodybuilder, but don't nobody want to "
              'lift no heavy-ass weights.',
          author: 'Ronnie Coleman'
        ),
        (
          text: 'If you train hard enough, long enough, and heavy enough, the '
              'results will come.',
          author: 'Dorian Yates'
        ),
        (
          text: 'The pain you feel today will be the strength you feel tomorrow.',
          author: 'Iron Philosophy'
        ),
        (
          text: "There is no reason to be alive if you can't do the deadlift.",
          author: 'Jon Pall Sigmarsson'
        ),
        (
          text: 'The iron never lies to you. The iron is the great reference '
              'point.',
          author: 'Henry Rollins'
        ),
        (
          text: 'Discipline is doing what you hate to do, but doing it like you '
              'love it.',
          author: 'Mike Tyson'
        ),
        (
          text: "Failure is not the opposite of success - it's the toll you pay "
              'on the way there.',
          author: 'Iron Philosophy'
        ),
        (
          text: "You don't find willpower. You build it, one rep you didn't "
              'want to do at a time.',
          author: 'Iron Philosophy'
        ),
        (
          text: 'Suffer the pain of discipline or suffer the pain of regret.',
          author: 'Jim Rohn'
        ),
        (
          text: 'Everybody wanna be a bodybuilder, but nobody wanna do no '
              'heavy-ass squats.',
          author: 'Gym Wisdom'
        ),
        (
          text: 'The squat is the king of all exercises. The deadlift is the '
              'king of all kings.',
          author: 'Iron Philosophy'
        ),
        (
          text: 'If the bar ain\'t bending, you\'re just pretending.',
          author: 'Gym Wisdom'
        ),
        (
          text: 'Light weight, baby! Nothing but a peanut.',
          author: 'Ronnie Coleman'
        ),
        (
          text: 'Somewhere someone is training when you are not. When you race '
              'him, he will win.',
          author: 'Tom Fleming'
        ),
        (
          text: 'The worst thing I can be is the same as everybody else. I hate '
              'that.',
          author: 'Arnold Schwarzenegger'
        ),
        (
          text: 'Rest day? I don\'t even rest between sets, brother.',
          author: 'Gym Wisdom'
        ),
        (
          text: 'Motivation gets you started. Habit is what keeps the bar '
              'moving.',
          author: 'Iron Philosophy'
        ),
        (
          text: 'My protein shake brings the whole gym to the yard.',
          author: 'Gym Humor'
        ),
        (
          text: 'A one-hour workout is 4% of your day. No excuses.',
          author: 'Iron Philosophy'
        ),
        (
          text: 'Do not count the reps. Make the reps count.',
          author: 'Gym Wisdom'
        ),
        (
          text: 'Sleep is my secret pre-workout. And my secret post-workout.',
          author: 'Gym Humor'
        ),
        (
          text: 'The pump is temporary. The glory of the logbook is forever.',
          author: 'Iron Philosophy'
        ),
        (
          text: 'Strong people are harder to kill, and more useful in general.',
          author: 'Mark Rippetoe'
        ),
        (
          text: 'You against you. That is the only rivalry that ever mattered '
              'under the bar.',
          author: 'Iron Philosophy'
        ),
      ];

  @override
  String get geminiReplyLanguage => 'Reply in English.';

  // -- hydration -------------------------------------------------------------
  @override
  String get hydrationTitle => 'Hydration';
  @override
  String hydrationLogged(int current, int target) => '$current / $target ml';

  // -- reminders -------------------------------------------------------------
  @override
  String get remindersTitle => 'Reminders';
  @override
  String get reminderTakeCreatine => 'Take Creatine';
  @override
  String get reminderEatMeal => 'Eat Meal';
  @override
  String get reminderHydrate => 'Hydrate';
  @override
  String get reminderWorkoutTime => 'Workout Time';
  @override
  String get reminderNoTime => 'No time set';
  @override
  String get reminderTapToSchedule => 'Tap to schedule';
  @override
  String get reminderAddTime => 'Add time';
  @override
  String get reminderNotificationBody =>
      'Time for this habit — keep the streak alive.';
  @override
  String get notificationsDenied =>
      'Notifications are disabled, so reminders will stay silent. Enable them '
      'for 1RM in system settings.';

  // -- history / progress ----------------------------------------------------
  @override
  String get historyTitle => 'Progress';
  @override
  String get historyChartTitle => 'Estimated 1RM over time';
  @override
  String get historyPersonalRecords => 'Personal records';
  @override
  String get historyNoData => 'Log a session to see your progress here.';
  @override
  String historySinceStart(String kg) => '+$kg kg since start';

  // -- achievements ----------------------------------------------------------
  @override
  String get achievementsTitle => 'Achievements';
  @override
  String get achievementsBenchPress => 'Bench Press';
  @override
  String get achievementsSquats => 'Squats';
  @override
  String get achievementsDeadlift => 'Deadlift';
  @override
  String get achievementsEasterEggs => 'Fun & Easter Eggs';
  @override
  String get achievementNotUnlocked => 'This achievement is not unlocked yet';
  @override
  String achievementUnlockedToast(String title) => 'Achievement unlocked: $title';
  @override
  String achievementUnlockedAt(String date) => 'Unlocked: $date';

  @override
  String achievementTitle(String id) => switch (id) {
        'bench_50' => 'Bar and two cookies',
        'bench_80' => 'No longer embarrassing',
        'bench_100' => 'Who do you think you are?',
        'bench_120' => 'The gym boss',
        'bench_150' => 'Human jack',
        'squat_60' => 'Leg day? Never heard of it',
        'squat_100' => 'Knees have left the chat',
        'squat_140' => 'Jeans tore',
        'squat_180' => 'Quads like bazookas',
        'squat_200' => 'Gravity is a myth',
        'deadlift_100' => 'Back is still there',
        'deadlift_150' => 'Osteopath sponsor',
        'deadlift_200' => 'Mini tractor',
        'deadlift_250' => 'Level 80 loader',
        'deadlift_300' => 'Lifted the couch with dad',
        'fun_bar_won' => 'The bar won',
        'fun_step_back' => 'Step back, two forward',
        'fun_early_bird' => 'Early bird psycho',
        'fun_night_owl' => 'Gym is closed, go to sleep!',
        _ => 'Unknown Achievement',
      };

  @override
  String achievementDesc(String id) => switch (id) {
        'bench_50' => 'Benched 50 kg! A good start, you earned those cookies.',
        'bench_80' => 'Benched 80 kg! They don\'t look at you with pity anymore.',
        'bench_100' => 'Benched 100 kg! Officially a respectable human.',
        'bench_120' => 'Benched 120 kg! In spring, all equipment is yours by right.',
        'bench_150' => 'Benched 150 kg! Physics left the chat, you are a machine.',
        'squat_60' => 'Squatted 60 kg! At least your legs are present.',
        'squat_100' => 'Squatted 100 kg! Hear that crunch? That\'s respect.',
        'squat_140' => 'Squatted 140 kg! Gotta buy new jeans, quads don\'t fit.',
        'squat_180' => 'Squatted 180 kg! Your legs can shift tectonic plates.',
        'squat_200' => 'Squatted 200 kg! Earth tries to pull you, but you\'re stronger.',
        'deadlift_100' => 'Pulled 100 kg! Hello protrusions.',
        'deadlift_150' => 'Pulled 150 kg! Your chiropractor is buying a new car.',
        'deadlift_200' => 'Pulled 200 kg! Can tow a car without a cable.',
        'deadlift_250' => 'Pulled 250 kg! You can unload a truck with a glare.',
        'deadlift_300' => 'Pulled 300 kg! Legendary strength, dad is proud.',
        'fun_bar_won' => 'Not your day. The bar was stronger today, but you\'ll be back.',
        'fun_step_back' => 'A smart athlete knows when to step back to shoot forward.',
        'fun_early_bird' => 'Training at dawn? You are either a genius or a madman.',
        'fun_night_owl' => 'Midnight snack or midnight bench? Go to bed, muscles grow in your sleep!',
        _ => '',
      };
}
