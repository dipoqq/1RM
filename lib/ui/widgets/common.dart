import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/profile.dart';
import '../../state/app_state.dart';

/// Male / Female, in the same segmented style as the language switch — two
/// options do not earn a dropdown.
///
/// Lives here rather than on either screen because both use it: the Nutrition
/// tab, where the choice visibly moves the BMR line, and Settings, where it is
/// a profile field like any other.
class GenderToggle extends StatelessWidget {
  const GenderToggle({
    super.key,
    required this.gender,
    required this.onChanged,
  });

  final Gender gender;
  final ValueChanged<Gender> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return SegmentedButton<Gender>(
      segments: [
        for (final g in Gender.values)
          ButtonSegment(value: g, label: Text(s.genderLabel(g))),
      ],
      selected: {gender},
      showSelectedIcon: false,
      onSelectionChanged: (set) => onChanged(set.first),
      style: SegmentedButton.styleFrom(
        backgroundColor: AppColors.bgBase,
        foregroundColor: AppColors.textMid,
        selectedBackgroundColor: AppColors.accentTint,
        selectedForegroundColor: AppColors.accentDim,
        side: const BorderSide(color: AppColors.border),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Weights, the way a lifter writes them: 95, not 95.0 — but 92.5, not 93.
///
/// One helper, used by every screen that prints a load. It was three private
/// copies of the same three lines before the bench goal made a fourth caller.
String fmtKg(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// The standard card shell: soft gray fill, hairline border, 16 px radius.
///
/// A Material, not a Container. ListTile (and SwitchListTile, in the log card)
/// paints its background and ink splashes onto the nearest Material ancestor —
/// with a plain DecoratedBox in between, the card's own fill hid those effects
/// and the framework said so, once per layout. Painting the fill ON the Material
/// is the fix the assertion asks for, and doing it here fixes every card rather
/// than the one tile that happened to complain.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      elevation: 0,
      // The hairline border and the 16 px radius, exactly as before — carried
      // by the Material's shape instead of a BoxDecoration.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title!.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textLow,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 14),
            ],
            // Container gave the card its full width; Material sizes to its
            // child, so the stretch has to be asked for explicitly or a narrow
            // card would shrink-wrap its content.
            SizedBox(width: double.infinity, child: child),
          ],
        ),
      ),
    );
  }
}

/// A circular macro gauge. Fills toward [target]; overshoot is clamped to a
/// full ring but flagged with the over-target colour so a 3,000 kcal day on a
/// 2,350 kcal target cannot masquerade as "on plan".
class MacroRing extends StatelessWidget {
  const MacroRing({
    super.key,
    required this.label,
    required this.value,
    required this.target,
    required this.unit,
    required this.color,
    this.size = 116,
  });

  final String label;
  final double value;
  final int target;
  final String unit;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final ratio = target <= 0 ? 0.0 : value / target;
    final over = ratio > 1.0;
    final ringColor = over ? AppColors.warning : color;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 550),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => CustomPaint(
              painter: _RingPainter(progress: t, color: ringColor),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value.round().toString(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textHi,
                      ),
                    ),
                    Text(
                      '/ $target $unit',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textLow,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMid,
          ),
        ),
        Text(
          over
              ? s.overBy('${(value - target).round()}', unit)
              : s.leftOf('${(target - value).round()}', unit),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: over ? AppColors.warning : AppColors.textLow,
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - stroke) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = AppColors.border;

    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // start at 12 o'clock
      2 * math.pi * progress,
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

/// Randomised iron/discipline quote.
///
/// [pick] is a 0..1 fraction chosen by the CALLER and held in its state, not
/// rolled here. A widget's build must be a pure function of its inputs: rolling
/// the dice in the constructor meant every rebuild — a language switch, a saved
/// bench goal, any notify at all — silently dealt a new quote, and during a
/// rebuild storm it flickered through them.
///
/// A fraction rather than an index into a particular language's list, so
/// switching to Russian re-renders the quote you were already reading rather
/// than jumping to a different one.
class QuoteCard extends StatelessWidget {
  const QuoteCard({super.key, required this.pick});

  /// A fresh quote: call this when the lifter actually asks for one (app start,
  /// pull-to-refresh), and keep the result in state.
  static double roll([math.Random? rng]) => (rng ?? math.Random()).nextDouble();

  /// 0..1.
  final double pick;

  @override
  Widget build(BuildContext context) {
    final quotes = context.s.quotes;
    final quote = quotes[(pick * quotes.length).floor() % quotes.length];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.accentTint,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${quote.text}"',
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              fontStyle: FontStyle.italic,
              color: AppColors.textHi,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '— ${quote.author}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.accentDim,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width status banner (plateau warning, history notice).
class Banner extends StatelessWidget {
  const Banner({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
    required this.tint,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;
  final Color tint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textMid,
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(height: 10),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
