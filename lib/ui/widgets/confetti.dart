import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// A lightweight confetti burst.
///
/// Particles are simulated in normalised space (0..1 on both axes) so the burst
/// looks identical on a phone and on a desktop window, and are painted by a
/// single CustomPainter — one repaint per frame, no widget rebuilds.
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({
    super.key,
    required this.controller,
    this.particleCount = 140,
  });

  final ConfettiController controller;
  final int particleCount;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  List<_Particle> _particles = const [];

  @override
  void initState() {
    super.initState();
    widget.controller._attach(_fire);
    _anim.addStatusListener((s) {
      // Drop the particles once the burst finishes so the painter stops doing
      // work while the overlay sits idle.
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _particles = const []);
      }
    });
  }

  void _fire() {
    if (!mounted) return;
    setState(() {
      _particles = _Particle.burst(widget.particleCount);
    });
    _anim.forward(from: 0);
  }

  @override
  void dispose() {
    widget.controller._detach();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_particles.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _ConfettiPainter(_particles, _anim),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// Handle used by a parent to trigger a burst.
class ConfettiController {
  VoidCallback? _fire;

  void _attach(VoidCallback fire) => _fire = fire;
  void _detach() => _fire = null;

  /// Burst now. A no-op if no overlay is mounted.
  void fire() => _fire?.call();
}

class _Particle {
  _Particle({
    required this.x,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.spin,
    required this.phase,
  });

  final double x; // normalised launch x, 0..1
  final double vx; // normalised horizontal velocity
  final double vy; // normalised initial upward velocity (negative = up)
  final Color color;
  final double size; // logical px
  final double spin; // radians/sec
  final double phase; // desync the flutter wobble

  /// Launch from across the full width, fired upward and outward.
  static List<_Particle> burst(int count) {
    final rng = math.Random();
    return List.generate(count, (_) {
      final x = rng.nextDouble();
      return _Particle(
        x: x,
        // Push outward from centre so the burst opens up rather than raining
        // straight down.
        vx: (x - 0.5) * 0.55 + (rng.nextDouble() - 0.5) * 0.35,
        vy: -(0.55 + rng.nextDouble() * 0.75),
        color: AppColors.confetti[rng.nextInt(AppColors.confetti.length)],
        size: 6 + rng.nextDouble() * 7,
        spin: (rng.nextDouble() - 0.5) * 10,
        phase: rng.nextDouble() * math.pi * 2,
      );
    });
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.particles, this.t) : super(repaint: t);

  final List<_Particle> particles;
  final Animation<double> t;

  static const _gravity = 1.15; // normalised units / sec^2

  @override
  void paint(Canvas canvas, Size size) {
    final elapsed = t.value * 2.6; // seconds
    final paint = Paint();

    for (final p in particles) {
      // Simple projectile motion, launched from just below the bottom edge.
      final dy = p.vy * elapsed + 0.5 * _gravity * elapsed * elapsed;
      final ny = 1.05 + dy;
      if (ny > 1.12) continue; // fallen off-screen

      final nx = p.x + p.vx * elapsed;
      final dx = nx * size.width;
      final py = ny * size.height;

      // Fade out over the last third of the burst.
      final fade = (1 - (t.value - 0.66) / 0.34).clamp(0.0, 1.0);
      paint.color = p.color.withValues(alpha: fade);

      canvas.save();
      canvas.translate(dx, py);
      canvas.rotate(p.spin * elapsed + p.phase);
      // Squash on one axis so each piece reads as a tumbling paper rectangle
      // rather than a flat blob.
      final w = p.size;
      final h = p.size * (0.4 + 0.6 * (math.sin(elapsed * 6 + p.phase)).abs());
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: w, height: h),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.particles != particles;
}
