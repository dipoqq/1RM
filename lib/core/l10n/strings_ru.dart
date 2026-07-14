import '../../models/profile.dart';
import '../progression.dart';
import '../theme_mode.dart';
import 'app_locale.dart';
import 'app_strings.dart';

/// Russian.
///
/// Russian has three plural forms, not two, and picking the wrong one reads as
/// broken to a native speaker ("5 недели"). [_plural] implements the rule once
/// and every counted noun goes through it.
class RuStrings implements AppStrings {
  const RuStrings();

  @override
  AppLocale get locale => AppLocale.ru;

  /// one (1, 21, 31…) · few (2-4, 22-24…) · many (0, 5-20, 25-30…)
  static String _plural(int n, String one, String few, String many) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return one;
    if (mod10 >= 2 && mod10 <= 4 && !(mod100 >= 12 && mod100 <= 14)) return few;
    return many;
  }

  // -- shell -----------------------------------------------------------------

  @override
  String get appTitle => '1RM';
  @override
  String get tabTraining => 'Тренировки';
  @override
  String get tabNutrition => 'Питание';
  @override
  String get signOut => 'Выйти';
  @override
  String get settings => 'Настройки';
  @override
  String get cancel => 'Отмена';
  @override
  String get delete => 'Удалить';
  @override
  String get retry => 'Повторить';
  @override
  String get save => 'Сохранить';

  // -- boot / auth -----------------------------------------------------------

  @override
  String get configMissing => 'Отсутствует конфигурация';
  @override
  String get signInSubtitle =>
      'Войдите, чтобы синхронизировать данные между устройствами.';
  @override
  String get signUpSubtitle =>
      'Создайте аккаунт, в котором будут храниться ваши данные.';
  @override
  String get email => 'Эл. почта';
  @override
  String get password => 'Пароль';
  @override
  String get credentialsRequired => 'Введите эл. почту и пароль.';
  @override
  String get signIn => 'Войти';
  @override
  String get createAccount => 'Создать аккаунт';
  @override
  String get haveAccount => 'У меня уже есть аккаунт';

  // -- onboarding ------------------------------------------------------------

  @override
  String get onboardingTitle => 'Добро пожаловать в 1RM.';
  @override
  String get onboardingSubtitle => 'Давайте настроим ваш профиль.';
  @override
  String get onboardingIntro =>
      'По этим данным рассчитываются дневные нормы калорий и макронутриентов, '
      'а также цель в жиме лёжа, с которой сравнивается каждая тренировка. '
      'Всё это можно изменить позже в настройках.';
  @override
  String get onboardingBodySection => 'О себе';
  @override
  String get onboardingGoalSection => 'Ваша цель в жиме лёжа';
  @override
  String get onboardingGoalHint =>
      'Вес, к которому вы идёте. Когда возьмёте его — полетит конфетти.';
  @override
  String get onboardingFinish => 'Начать тренировки';
  @override
  String get loadingProfile => 'Загружаем ваш профиль…';
  @override
  String heightOutOfRange(double min, double max) =>
      'Введите рост от ${min.round()} до ${max.round()} см.';
  @override
  String weightOutOfRange(double min, double max) =>
      'Введите вес от ${min.round()} до ${max.round()} кг.';
  @override
  String ageOutOfRange(int min, int max) =>
      'Введите возраст от $min до $max ${_plural(max, 'года', 'лет', 'лет')}.';

  // -- settings --------------------------------------------------------------

  @override
  String get language => 'Язык';
  @override
  String get languageHint =>
      'Применяется сразу и синхронизируется с другими устройствами.';
  @override
  String get theme => 'Оформление';
  @override
  String get themeHint =>
      'Применяется сразу и синхронизируется с другими устройствами.';
  @override
  String themeLabel(AppThemeMode mode) => switch (mode) {
        AppThemeMode.dark => 'Тёмное',
        AppThemeMode.light => 'Светлое',
      };
  @override
  String get benchGoalSection => 'Цель в жиме лёжа';
  @override
  String get benchGoalLabel => 'Целевой 1ПМ';
  @override
  String get benchGoalHint =>
      'Определяет прогресс-бар, остаток веса и процент выполнения. '
      'Достижение цели запускает конфетти.';
  @override
  String benchGoalOutOfRange(double min, double max) =>
      'Введите цель от ${min.round()} до ${max.round()} кг.';
  @override
  String benchGoalSaved(String kg) => 'Цель в жиме лёжа: $kg кг.';
  @override
  String get settingsSaved => 'Настройки успешно сохранены!';
  @override
  String get profileSection => 'Аккаунт';
  @override
  String get genderHint =>
      'Определяет, по какой формуле Миффлина-Сан Жеора рассчитываются ваши '
      'дневные нормы калорий и макронутриентов.';

  // -- training --------------------------------------------------------------

  @override
  String get estimated1rm => 'Расчётный 1ПМ (Эпли)';
  @override
  String weeksCompleted(int weeks) =>
      '$weeks ${_plural(weeks, 'неделя', 'недели', 'недель')}';
  @override
  String goalCleared(String goalKg) => 'Цель взята — $goalKg кг позади.';
  @override
  String remainingToGoal(String remainingKg, String goalKg) =>
      'До цели в $goalKg кг осталось $remainingKg кг.';
  @override
  String percentOfGoal(int percent) => '$percent% от цели';
  @override
  String get plateauTitle => 'Обнаружено плато — назначен разгрузочный блок';
  @override
  String plateauMessage(int streak, String from, String to) =>
      '$streak ${_plural(streak, 'тяжёлая тренировка', 'тяжёлые тренировки', 'тяжёлых тренировок')} '
      'подряд провалено. Продолжать давить тот же вес — прямой путь к травме, '
      'а не к прогрессу. Сбросьте 10% до $to кг (с $from кг), восстановите '
      'импульс и снова идите вверх.';
  @override
  String loadWeight(String kg) => 'Взять $kg кг';
  @override
  String get logSession => 'Записать тренировку';
  @override
  String get workoutTypeField => 'Тип тренировки';
  @override
  String get weight => 'Вес';
  @override
  String get reps => 'Повт.';
  @override
  String get sets => 'Подх.';
  @override
  String get allSetsCompleted => 'Все подходы выполнены';
  @override
  String get failedReps => 'Провал / недобор повторений';
  @override
  String get failedDrivePlateau =>
      'Проваленные тяжёлые дни запускают детектор плато.';
  @override
  String get logSessionButton => 'Записать';
  @override
  String get sessionLogged => 'Тренировка записана.';
  @override
  String get enterPositiveNumbers =>
      'Введите вес, повторения и подходы больше нуля.';
  @override
  String couldNotSave(String error) => 'Не удалось сохранить: $error';
  @override
  String get warmupRamp => 'Разминочная лестница';
  @override
  String warmupTo(String kg) => 'до $kg кг';
  @override
  String get warmupFootnote =>
      'Каждый вес округлён до реального шага 2,5 кг и не опускается ниже '
      'пустого грифа 20 кг.';
  @override
  String warmupLabel(WarmupStage stage) => switch (stage) {
        WarmupStage.bar => 'Пустой гриф',
        WarmupStage.sixty => '60%',
        WarmupStage.eighty => '80%',
        WarmupStage.ninety => '90%',
      };
  @override
  String warmupPurpose(WarmupStage stage) => switch (stage) {
        WarmupStage.bar => 'Кровоток и смазка суставов',
        WarmupStage.sixty => 'Отработка траектории движения',
        WarmupStage.eighty => 'Активация ЦНС',
        WarmupStage.ninety => 'Тяжёлый одиночный — почувствовать вес, без усталости',
      };
  @override
  String get recentSessions => 'Последние тренировки';
  @override
  String get noSessions => 'Пока нет записанных тренировок.';
  @override
  String get backToWork => 'За работу';
  @override
  String milestoneTitle(String kg) => '$kg КГ!';
  @override
  String milestoneSubtitle(bool isFinal) => isFinal
      ? 'Ваша цель в жиме лёжа взята.'
      : 'Промежуточный рубеж взят.';
  @override
  String milestoneBody(String bestKg) => 'Расчётный 1ПМ: $bestKg кг.';

  @override
  String workoutType(String persisted) => switch (persisted) {
        'Heavy Day (Strength)' => 'Тяжёлый день (сила)',
        'Volume Day (Hypertrophy/Technique)' =>
          'Объёмный день (гипертрофия/техника)',
        'Deload (Recovery)' => 'Разгрузка (восстановление)',
        // A type written by a newer build than this one: show it raw rather
        // than swallow it.
        _ => persisted,
      };

  // -- nutrition -------------------------------------------------------------

  @override
  String get today => 'Сегодня';
  @override
  String get dailyTargets => 'Дневные нормы';
  @override
  String get bodyweight => 'Вес тела';
  @override
  String get height => 'Рост';
  @override
  String get age => 'Возраст';
  @override
  String get unitKg => 'кг';
  @override
  String get unitCm => 'см';
  @override
  String get unitYears => 'л';
  @override
  String get unitGrams => 'г';
  @override
  String get carbsInitial => 'У';
  @override
  String get fatsInitial => 'Ж';
  @override
  String get gender => 'Пол';
  @override
  String get activityLevel => 'Уровень активности';
  @override
  String get goal => 'Цель';
  @override
  String bmrLine(int bmr, double multiplier, String activity, int tdee) =>
      'BMR $bmr ккал  ×$multiplier ($activity)  =  TDEE $tdee ккал';
  @override
  String get unitKcal => 'ккал';
  @override
  String get gProtein => 'г белка';
  @override
  String get gCarbs => 'г углеводов';
  @override
  String get gFats => 'г жиров';
  @override
  String tdeeAnd(String delta) => 'TDEE · $delta';
  @override
  String proteinPerKg(String kg) => '2,0 г × $kg кг';
  @override
  String get remainingCalories => 'оставшиеся калории';
  @override
  String fatsShare(int kcal) => '25% от $kcal ккал';
  @override
  String get calories => 'Калории';
  @override
  String get protein => 'Белки';
  @override
  String get carbs => 'Углеводы';
  @override
  String get fats => 'Жиры';
  @override
  String overBy(String amount, String unit) => '$amount $unit сверх нормы';
  @override
  String leftOf(String amount, String unit) => 'осталось $amount $unit';
  @override
  String get analyzeMeal => 'Анализ приёма пищи';
  @override
  String get describeHint =>
      'напр. 200 г куриной грудки, 150 г риса, оливковое масло…';
  @override
  String get upload => 'Загрузить';
  @override
  String get camera => 'Камера';
  @override
  String get analyzeFood => 'Анализировать';
  @override
  String get analyzing => 'Анализирую…';
  @override
  String get addManually => 'Добавить вручную';
  @override
  String get mealsLogged => 'Записанные приёмы пищи';
  @override
  String get clearDaysLog => 'Очистить день';
  @override
  String get clearDayTitle => 'Очистить записи за этот день?';
  @override
  String clearDayBody(int count, String day) =>
      'Это навсегда удалит все $count '
      '${_plural(count, 'приём пищи', 'приёма пищи', 'приёмов пищи')}, '
      'записанные $day. Другие дни не затрагиваются. Отменить нельзя.';
  @override
  String dayCleared(String day) => 'Очищено: $day.';
  @override
  String get nothingLogged => 'В этот день ничего не записано.';
  @override
  String addMealOn(String day) => 'Добавить приём пищи · $day';
  @override
  String get mealName => 'Название';
  @override
  String get addMeal => 'Добавить';
  @override
  String get mealFieldsRequired => 'Название, калории и белки обязательны.';
  @override
  String get describeOrPhoto =>
      'Опишите приём пищи или прикрепите фото тарелки.';
  @override
  String get geminiNotConfigured =>
      'GEMINI_API_KEY не был передан при сборке. См. README.md.';
  @override
  String get geminiNoDataBlock =>
      'Gemini не вернул корректный блок [DATA] — добавьте вручную.';
  @override
  String mealLogged(String name, int kcal) =>
      'Записано «$name» · $kcal ккал.';
  @override
  String analysisFailed(String error) => 'Анализ не удался: $error';
  @override
  String couldNotLoad(String error) => 'Не удалось загрузить: $error';
  @override
  String couldNotSaveSettings(String error) =>
      'Не удалось сохранить настройки: $error';
  @override
  String couldNotOpenPicker(String error) =>
      'Не удалось открыть выбор файла: $error';
  @override
  String viewingHistory(String date) => 'Просмотр истории: $date';
  @override
  String get viewingHistoryBody =>
      'Всё, что вы запишете сейчас, будет отнесено к этой дате, а не к сегодняшней.';
  @override
  String get backToToday => 'К сегодняшнему дню';

  @override
  String genderLabel(Gender gender) => switch (gender) {
        Gender.male => 'Мужской',
        Gender.female => 'Женский',
      };
  @override
  String goalLabel(Goal goal) => switch (goal) {
        Goal.leanBulk => 'Чистый набор',
        Goal.maintenance => 'Поддержание',
        Goal.cut => 'Сушка',
      };
  @override
  String goalDelta(Goal goal) => goal.kcalDelta == 0
      ? 'поддержание'
      : '${goal.kcalDelta > 0 ? '+' : ''}${goal.kcalDelta} ккал';
  @override
  String activityLabel(ActivityLevel activity) => switch (activity) {
        ActivityLevel.sedentary => 'Малоподвижный',
        ActivityLevel.lightlyActive => 'Низкая активность',
        ActivityLevel.moderatelyActive => 'Средняя активность',
        ActivityLevel.veryActive => 'Высокая активность',
      };
  @override
  String activityDescription(ActivityLevel activity) => switch (activity) {
        ActivityLevel.sedentary => 'Почти без нагрузок',
        ActivityLevel.lightlyActive => 'Лёгкие нагрузки 1-3 раза в неделю',
        ActivityLevel.moderatelyActive => 'Умеренные нагрузки 3-5 раз в неделю',
        ActivityLevel.veryActive => 'Тяжёлые нагрузки 6-7 раз в неделю',
      };

  // -- content ---------------------------------------------------------------

  @override
  List<({String text, String author})> get quotes => const [
        (
          text: 'Последние три-четыре повторения — вот что растит мышцу. Именно '
              'эта зона боли отделяет чемпиона от того, кто им не станет.',
          author: 'Арнольд Шварценеггер'
        ),
        (
          text: 'Все хотят быть бодибилдерами, но никто не хочет тягать '
              'по-настоящему тяжёлое железо.',
          author: 'Ронни Коулман'
        ),
        (
          text: 'Если тренироваться достаточно упорно, достаточно долго и '
              'достаточно тяжело — результат придёт.',
          author: 'Дориан Йейтс'
        ),
        (
          text: 'Боль, которую вы чувствуете сегодня, — это сила, которую вы '
              'почувствуете завтра.',
          author: 'Философия железа'
        ),
        (
          text: 'Незачем жить, если ты не можешь делать становую тягу.',
          author: 'Йон Пал Сигмарссон'
        ),
        (
          text: 'Железо никогда не лжёт. Железо — это великая точка отсчёта.',
          author: 'Генри Роллинз'
        ),
        (
          text: 'Дисциплина — это делать то, что ненавидишь, но делать так, '
              'будто любишь это.',
          author: 'Майк Тайсон'
        ),
        (
          text: 'Провал — не противоположность успеха, а плата за дорогу к нему.',
          author: 'Философия железа'
        ),
        (
          text: 'Силу воли не находят. Её строят — по одному повторению, '
              'которое не хотелось делать.',
          author: 'Философия железа'
        ),
        (
          text: 'Терпи боль дисциплины или терпи боль сожаления.',
          author: 'Джим Рон'
        ),
      ];

  @override
  String get geminiReplyLanguage => 'Reply in Russian (по-русски).';
}
