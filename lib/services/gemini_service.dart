import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../core/constants.dart';
import '../models/meal.dart';
import '../models/profile.dart';

const _dataOpen = '[DATA]';
const _dataClose = '[/DATA]';

/// Gemini's reply: the prose to show, plus the meal it parsed (null if the
/// model failed to emit a well-formed [DATA] block).
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

  /// Model chain, tried in order.
  ///
  /// gemini-3-flash-preview leads: gemini-2.5-flash 404s for newly-created API
  /// keys ("no longer available to new users"), which is exactly what happened
  /// here after the key rotation — and the same trap bench_tracker.py documents
  /// at its GEMINI_MODEL constant. It stays at the back of the chain rather than
  /// being deleted, so an older key that still has access can use it.
  ///
  /// A 404 or 503 means "try the next model"; anything else (bad key, no
  /// network, quota) is a real failure and is rethrown immediately rather than
  /// silently retried.
  static const _models = <String>[
    'gemini-3-flash-preview',
    'gemini-flash-latest',
    'gemini-2.5-flash',
    'gemini-2.0-flash',
  ];

  GenerativeModel _model(
    String name,
    Targets targets,
    MacroTotals eaten,
  ) =>
      GenerativeModel(
        model: name,
        apiKey: _apiKey,
        systemInstruction: Content.system(_systemPrompt(targets, eaten)),
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

  static String _systemPrompt(Targets targets, MacroTotals eaten) {
    final kcalLeft = (targets.kcal - eaten.calories).round();
    final proteinLeft = (targets.protein - eaten.protein).round();
    final carbsLeft = (targets.carbs - eaten.carbs).round();
    final fatsLeft = (targets.fats - eaten.fats).round();
    return '''
You are an expert sports nutritionist advising $kLifterProfile.

His targets today are ${targets.kcal} kcal, ${targets.protein} g protein,
${targets.carbs} g carbs and ${targets.fats} g fats.

So far he has eaten ${eaten.calories.round()} kcal, ${eaten.protein.round()} g
protein, ${eaten.carbs.round()} g carbs and ${eaten.fats.round()} g fats —
leaving $kcalLeft kcal, $proteinLeft g protein, $carbsLeft g carbs and
$fatsLeft g fats.

Assess the meal he describes or photographs. Be concise and practical: estimate
all four macros, say how the meal fits what he has left today, and give one
specific adjustment if it does not fit.

Then, as the VERY LAST line of your reply and nothing after it, append this
exact block with your numeric estimates:

$_dataOpen Name: Meal Name | Calories: X | Protein: Y | Carbs: Z | Fats: W $_dataClose

Use plain integers with no units inside the block.''';
  }

  /// Analyse a meal from text and/or a photo.
  ///
  /// [day] is the calendar date the resulting meal is logged against — the date
  /// currently selected on the calendar strip, NOT necessarily today.
  Future<Analysis> analyze({
    String text = '',
    Uint8List? image,
    String imageMime = 'image/jpeg',
    required Targets targets,
    required MacroTotals eaten,
    required DateTime day,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && image == null) {
      throw ArgumentError('Describe your meal or attach a photo of your plate.');
    }

    final parts = <Part>[
      if (trimmed.isNotEmpty) TextPart('Here is what I ate: $trimmed'),
      if (image != null) DataPart(imageMime, image),
    ];

    final content = [Content.multi(parts)];

    Object? lastError;
    for (final name in _models) {
      final GenerateContentResponse response;
      try {
        response = await _model(name, targets, eaten).generateContent(content);
      } catch (e) {
        if (!_retryable(e)) rethrow;
        lastError = e; // model retired or overloaded — fall through to the next
        continue;
      }

      final reply = response.text;
      if (reply == null || reply.isEmpty) {
        throw StateError('Gemini returned an empty response.');
      }
      return parseReply(reply, day);
    }

    throw StateError('No Gemini model available. Last error: $lastError');
  }

  /// Split the reply into (prose, Meal) on the [DATA] block.
  ///
  /// Returns a null Meal if the block is missing or malformed, which pushes the
  /// UI to the manual Quick Add fallback rather than silently logging garbage.
  /// Exposed (and not private) so it can be unit-tested without a network call.
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
