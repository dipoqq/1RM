import 'dart:convert';
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../core/constants.dart';
import '../core/l10n/app_strings.dart';
import '../models/meal.dart';
import '../models/profile.dart';
import '../models/workout.dart';
import 'timeout_http_client.dart';

/// Gemini's reply: the prose to show, plus the meal it parsed (null if the
/// model failed to emit well-formed macros).
typedef Analysis = ({String prose, Meal? meal});

/// Wraps the multimodal Gemini call. No Flutter imports — pure IO.
class GeminiService {
  const GeminiService();

  /// Injected at build time:
  ///   flutter run --dart-define=GEMINI_API_KEY=...
  ///
  /// NOTE: a key compiled into a client binary is extractable by anyone holding
  /// the app. It is not a secret. For anything beyond personal use, proxy this
  /// call through a Supabase Edge Function and keep the key server-side.
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  static bool get isConfigured => _apiKey.isNotEmpty;

  /// One shared HTTP client with a 30-second receive deadline, so a stalled
  /// mobile connection times out cleanly instead of hanging the Analyze button
  /// forever. Static so [GeminiService] stays `const` and every call reuses the
  /// same connection pool.
  static final _httpClient =
      TimeoutHttpClient(timeout: const Duration(seconds: 30));

  /// Model chain, tried in order.
  ///
  /// `gemini-3.5-flash` failed with regional 503/404 and SDK mismatches, so the
  /// app moved to the stable, JSON-Mode-friendly `gemini-3.1-flash-lite`, with
  /// `gemini-2.5-flash` behind it. A 404/503 means "try the next"; anything else
  /// (bad key, no network, quota) is a real failure and is rethrown immediately.
  static const _models = <String>[
    'gemini-3.1-flash-lite',
    'gemini-2.5-flash',
  ];

  /// Strict JSON mode: the model must return a single object matching this
  /// schema and nothing else — no prose wrapper, no markdown fence — so the
  /// reply parses deterministically instead of depending on a hand-written
  /// `[DATA]` block the model could format three different ways.
  static final _schema = Schema.object(
    properties: {
      'name': Schema.string(description: 'Short name of the meal.'),
      'advice': Schema.string(
        description: 'Concise, practical assessment of how the meal fits the '
            "user's remaining targets, in the requested language.",
      ),
      'calories': Schema.number(description: 'Total calories (kcal).'),
      'proteins': Schema.number(description: 'Total protein (grams).'),
      'carbs': Schema.number(description: 'Total carbohydrates (grams).'),
      'fats': Schema.number(description: 'Total fats (grams).'),
    },
    requiredProperties: ['name', 'calories', 'proteins', 'carbs', 'fats'],
  );

  static bool _retryable(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('404') ||
        s.contains('503') ||
        s.contains('not_found') ||
        s.contains('not found') ||
        s.contains('unavailable') ||
        s.contains('overloaded');
  }

  /// Generate against the model chain, falling through on a 404/503 to the next
  /// model and rethrowing anything else. Shared by [analyze] (JSON mode) and
  /// [coach] (plain text), which differ only in their generation config.
  Future<GenerateContentResponse> _run({
    required Content systemInstruction,
    required List<Content> content,
    GenerationConfig? generationConfig,
  }) async {
    Object? lastError;
    for (final name in _models) {
      try {
        return await GenerativeModel(
          model: name,
          apiKey: _apiKey,
          httpClient: _httpClient,
          generationConfig: generationConfig,
          systemInstruction: systemInstruction,
        ).generateContent(content);
      } catch (e) {
        if (!_retryable(e)) rethrow;
        lastError = e; // model retired or overloaded — fall through to the next
      }
    }
    throw StateError('No Gemini model available. Last error: $lastError');
  }

  /// One body metric, rendered for the prompt.
  ///
  /// Returns [kUnknownMetric] rather than a number when the profile has not
  /// loaded yet or holds a value no body has (zero height, a negative age, a
  /// NaN out of a bad row). The AI is told below to treat that as unknown and
  /// ask, because substituting a stand-in body is precisely the bug this
  /// method exists to prevent.
  static String _metric(num value, String unit) =>
      value.isFinite && value > 0 ? '${value.round()} $unit' : kUnknownMetric;

  /// The system prompt for [profile] — the *active* user, whoever that is.
  ///
  /// Every body metric here is read from the live profile. Nothing about the
  /// user's body may be hardcoded in this file: a constant here is a constant
  /// for every user of the app, which is how a single developer's height and
  /// weight ended up sizing other people's meals.
  ///
  /// The payload is kept deliberately lean — the profile, today's targets and
  /// what is left, and nothing else. The full meal history is *not* sent: it
  /// would bloat the prompt (and the token bill) on every call without changing
  /// the estimate, which depends only on the meal in front of the model.
  ///
  /// Exposed (and not private) so the metrics it injects can be unit-tested
  /// without a network call, exactly as [parse] is.
  static String systemPrompt(
    Profile profile,
    MacroTotals eaten,
    AppStrings strings,
  ) {
    final targets = profile.targets;
    final kcalLeft = (targets.kcal - eaten.calories).round();
    final proteinLeft = (targets.protein - eaten.protein).round();
    final carbsLeft = (targets.carbs - eaten.carbs).round();
    final fatsLeft = (targets.fats - eaten.fats).round();

    final gender = profile.gender.label;
    final height = _metric(profile.heightCm, 'cm');
    final weight = _metric(profile.weightKg, 'kg');
    final age = _metric(profile.age, 'years');

    return '''
You are an expert sports nutritionist.

Analyze the nutrition for a user with the following metrics: Gender: $gender,
Height: $height, Weight: $weight, Age: $age.

Any metric given as "$kUnknownMetric" is genuinely unknown. Do not guess a value
for it, do not assume a typical one, and do not give advice that depends on it —
say what you would need to know instead.

Their targets today are ${targets.kcal} kcal, ${targets.protein} g protein,
${targets.carbs} g carbs and ${targets.fats} g fats.

So far they have eaten ${eaten.calories.round()} kcal, ${eaten.protein.round()} g
protein, ${eaten.carbs.round()} g carbs and ${eaten.fats.round()} g fats —
leaving $kcalLeft kcal, $proteinLeft g protein, $carbsLeft g carbs and
$fatsLeft g fats.

Assess the meal they describe or photograph. Estimate all four macros and put a
concise, practical "advice" note — how the meal fits what they have left today,
and one specific adjustment if it does not.

Return your answer as a single JSON object with exactly these keys:
  "name"     — a short name for the meal (in the user's language),
  "advice"   — your assessment prose (in the user's language),
  "calories" — total kcal, a plain number,
  "proteins" — total protein in grams, a plain number,
  "carbs"    — total carbs in grams, a plain number,
  "fats"     — total fats in grams, a plain number.
Use plain numbers with no units. Do not wrap the JSON in markdown or any prose.

${strings.geminiReplyLanguage}''';
  }

  /// Analyse a meal from text and/or a photo.
  ///
  /// [profile] is the *active* user's profile — the body the advice is sized
  /// against, and the source of the daily targets. It is passed whole rather
  /// than pre-reduced to [Targets] so the metrics in the prompt and the targets
  /// in the prompt cannot describe two different people.
  ///
  /// [day] is the calendar date the resulting meal is logged against — the date
  /// currently selected on the calendar strip, NOT necessarily today.
  Future<Analysis> analyze({
    String text = '',
    Uint8List? image,
    String imageMime = 'image/jpeg',
    required Profile profile,
    required MacroTotals eaten,
    required DateTime day,
    required AppStrings strings,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && image == null) {
      throw ArgumentError('Describe your meal or attach a photo of your plate.');
    }

    final parts = <Part>[
      if (trimmed.isNotEmpty) TextPart('Here is what I ate: $trimmed'),
      if (image != null) DataPart(imageMime, image),
    ];

    final response = await _run(
      systemInstruction: Content.system(systemPrompt(profile, eaten, strings)),
      content: [Content.multi(parts)],
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: _schema,
      ),
    );

    final reply = response.text;
    if (reply == null || reply.isEmpty) {
      throw StateError('Gemini returned an empty response.');
    }
    return parse(reply, day);
  }

  /// Ask the model for a progression plan from the lifter's recent training.
  ///
  /// Plain text, not JSON: the reply is a motivating coaching block shown as-is.
  /// The prompt is built by [coachPrompt] and is deliberately compact — a capped
  /// window of recent sessions per lift, not the whole history.
  Future<String> coach({
    required WorkoutHistory history,
    required Profile profile,
    required AppStrings strings,
  }) async {
    final response = await _run(
      systemInstruction: Content.system(coachPrompt(history, profile, strings)),
      content: [
        Content.text(
          'Analyse my recent training above and give me my progression plan.',
        ),
      ],
    );
    final reply = response.text;
    if (reply == null || reply.trim().isEmpty) {
      throw StateError('Gemini returned an empty response.');
    }
    return reply.trim();
  }

  /// The coaching system prompt: the lifter's bodyweight, and for each lift the
  /// goal, best estimated 1RM, an explicit plateau flag, and a short window of
  /// recent sessions. Exposed (not private) so it can be unit-tested without a
  /// network call — the same pattern as [systemPrompt].
  ///
  /// Only the most recent [_coachWindow] sessions per lift are included: the
  /// coach needs the current trend, not a data dump, and a lean prompt keeps the
  /// call fast and cheap on a phone.
  static const _coachWindow = 6;

  static String coachPrompt(
    WorkoutHistory history,
    Profile profile,
    AppStrings strings,
  ) {
    double goalOf(Exercise e) => switch (e) {
          Exercise.benchPress => profile.benchGoalKg,
          Exercise.squat => profile.squatGoalKg,
          Exercise.deadlift => profile.deadliftGoalKg,
        };

    final buf = StringBuffer()
      ..writeln('You are an elite, old-school strength and powerlifting coach.')
      ..writeln(
          'Lifter bodyweight: ${_metric(profile.weightKg, 'kg')}.')
      ..writeln();

    for (final ex in Exercise.values) {
      final h = history.forExercise(ex);
      final recent = h.all.take(_coachWindow).toList(); // newest first
      if (recent.isEmpty) continue;

      final best = h.bestEstimated1rm;
      buf
        ..writeln('${ex.label} — goal ${goalOf(ex).round()} kg, '
            'best est. 1RM ${best == null ? 'n/a' : '${best.toStringAsFixed(1)} kg'}'
            '${h.plateauDetected ? '  [PLATEAU: recent heavy days failed]' : ''}')
        ..writeln('  recent sessions (oldest→newest):');
      for (final w in recent.reversed) {
        buf.writeln('    ${Meal.dateKey(w.date)}: '
            '${w.weight}kg × ${w.reps} × ${w.sets} '
            '${w.completed ? 'completed' : 'FAILED'} '
            '(~${w.estimated1rm.toStringAsFixed(1)} kg 1RM)');
      }
      buf.writeln();
    }

    buf
      ..writeln(strings.geminiReplyLanguage)
      ..writeln('Give a concise, highly personalised progression plan: name any '
          'plateau you see, prescribe concrete next weights/sets/reps per lift, '
          'and finish with one punchy line of old-school gym motivation. Plain '
          'text, no markdown headers.');

    return buf.toString();
  }

  /// Turn a model reply into (prose, Meal).
  ///
  /// Strict JSON mode means [reply] is normally the JSON object described by
  /// [_schema]; [_fromJson] reads it. As a safety net for a fallback model that
  /// ignored the mime type (or a rare markdown-fenced reply), it degrades to the
  /// legacy `[DATA]`-block parser rather than dropping the meal.
  ///
  /// Exposed (and not private) so it can be unit-tested without a network call.
  static Analysis parse(String reply, DateTime day) {
    final json = _tryDecode(reply);
    if (json != null) return _fromJson(json, day);
    return parseReply(reply, day);
  }

  /// Decode [reply] as a JSON object, tolerating a stray markdown ```json fence
  /// or leading/trailing prose. Returns null when there is no object to read.
  static Map<String, dynamic>? _tryDecode(String reply) {
    final start = reply.indexOf('{');
    final end = reply.lastIndexOf('}');
    if (start == -1 || end <= start) return null;
    try {
      final decoded = jsonDecode(reply.substring(start, end + 1));
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static Analysis _fromJson(Map<String, dynamic> json, DateTime day) {
    final prose = (json['advice'] as String?)?.trim() ?? '';
    final name = (json['name'] as String?)?.trim() ?? '';

    double? num_(Object? v) => switch (v) {
          num n when n.isFinite => n.toDouble(),
          String s => double.tryParse(s.replaceAll(RegExp(r'[^0-9.\-]'), '')),
          _ => null,
        };

    final calories = num_(json['calories']);
    // Accept the schema's "proteins" and a plain "protein" alike.
    final protein = num_(json['proteins'] ?? json['protein']);
    if (name.isEmpty || calories == null || protein == null) {
      return (prose: prose, meal: null);
    }

    return (
      prose: prose,
      meal: Meal(
        day: Meal.dayOf(day),
        name: name,
        calories: calories,
        protein: protein,
        carbs: num_(json['carbs']) ?? 0,
        fats: num_(json['fats']) ?? 0,
      ),
    );
  }

  // -- legacy [DATA]-block fallback ------------------------------------------

  static const _dataOpen = '[DATA]';
  static const _dataClose = '[/DATA]';

  /// Split a legacy reply into (prose, Meal) on the `[DATA]` block.
  ///
  /// Only reached when strict JSON mode did not produce a JSON object. Returns a
  /// null Meal if the block is missing or malformed, which pushes the UI to the
  /// manual Quick Add fallback rather than silently logging garbage.
  static Analysis parseReply(String reply, DateTime day) {
    final start = reply.indexOf(_dataOpen);
    final end = start == -1 ? -1 : reply.indexOf(_dataClose, start + 1);
    if (start == -1 || end == -1) return (prose: reply.trim(), meal: null);

    final prose =
        (reply.substring(0, start) + reply.substring(end + _dataClose.length))
            .trim();
    final block = reply.substring(start + _dataOpen.length, end).trim();

    final fields = <String, String>{};
    for (final part in block.split('|')) {
      final i = part.indexOf(':');
      if (i == -1) continue;
      fields[part.substring(0, i).trim().toLowerCase()] =
          part.substring(i + 1).trim();
    }

    /// Pull the first number out of a value like '~550 kcal' or '32.5 g'.
    double? number(String key) {
      final raw = fields[key];
      if (raw == null) return null;
      final m = RegExp(r'\d+(?:\.\d+)?').firstMatch(raw);
      return m == null ? null : double.tryParse(m.group(0)!);
    }

    final name = fields['name']?.trim() ?? '';
    final calories = number('calories');
    final protein = number('protein');
    if (name.isEmpty || calories == null || protein == null) {
      return (prose: prose, meal: null);
    }

    return (
      prose: prose,
      meal: Meal(
        day: Meal.dayOf(day),
        name: name,
        calories: calories,
        protein: protein,
        carbs: number('carbs') ?? 0,
        fats: number('fats') ?? 0,
      ),
    );
  }
}
