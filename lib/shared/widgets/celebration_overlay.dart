import 'dart:math';

import 'package:flutter/material.dart';

// ── Festive colour palette ─────────────────────────────────

const _kColors = [
  Color(0xFF6C5CE7),
  Color(0xFF0984E3),
  Color(0xFF00B894),
  Color(0xFFE17055),
  Color(0xFFFDCB6E),
  Color(0xFFFF7675),
  Color(0xFF00CEC9),
  Color(0xFFFD79A8),
  Color(0xFFA29BFE),
  Color(0xFF55EFC4),
];

// ── Particle model ─────────────────────────────────────────

class _Particle {
  /// Launch angle in radians. 0 = right, negative Y axis = up on canvas.
  final double angle;

  /// Normalised launch speed (0..1 → scaled to [_maxSpeed] × screenHeight).
  final double speed;

  final Color color;

  /// Particle size as a fraction of the screen's shortest side.
  final double normSize;

  /// Rectangle (true) vs circle (false).
  final bool isRect;

  final double initRot;

  /// Spin speed in radians per second.
  final double rotSpeed;

  _Particle(Random rnd)
    : angle = rnd.nextDouble() * 2 * pi,
      speed = 0.25 + rnd.nextDouble() * 0.75,
      color = _kColors[rnd.nextInt(_kColors.length)],
      normSize = 0.012 + rnd.nextDouble() * 0.018,
      isRect = rnd.nextBool(),
      initRot = rnd.nextDouble() * 2 * pi,
      rotSpeed = (rnd.nextDouble() - 0.5) * 16;
}

// ── Painter ────────────────────────────────────────────────

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress; // 0..1

  // Physics constants
  static const _totalSeconds = 1.4;
  static const _gravity = 0.85; // screen-heights per second²
  static const _maxSpeed = 0.60; // screen-heights per second

  const _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final elapsed = progress * _totalSeconds;
    final cx = size.width * 0.5;
    final cy = size.height * 0.42;
    final minDim = size.shortestSide;
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      // Fast fade-in (0→0.12), hold, then slow fade-out (0.70→1.0)
      final double opacity;
      if (progress < 0.12) {
        opacity = progress / 0.12;
      } else if (progress > 0.70) {
        opacity = 1.0 - (progress - 0.70) / 0.30;
      } else {
        opacity = 1.0;
      }

      final speedPx = p.speed * _maxSpeed * size.height;
      final gravPx = _gravity * size.height;

      final vx = cos(p.angle) * speedPx;
      final vy = sin(p.angle) * speedPx;

      final px = cx + vx * elapsed;
      final py = cy + vy * elapsed + 0.5 * gravPx * elapsed * elapsed;

      paint.color = p.color.withValues(alpha: opacity.clamp(0.0, 1.0));
      final sz = p.normSize * minDim;
      final rot = p.initRot + p.rotSpeed * elapsed;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(rot);

      if (p.isRect) {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: sz, height: sz * 0.55),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, sz * 0.5, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

// ── Widget ─────────────────────────────────────────────────

class _CelebrationWidget extends StatefulWidget {
  final VoidCallback onDone;

  const _CelebrationWidget({required this.onDone});

  @override
  State<_CelebrationWidget> createState() => _CelebrationWidgetState();
}

class _CelebrationWidgetState extends State<_CelebrationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _particles = List.generate(60, (_) => _Particle(Random()));
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder:
            (_, __) => CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _ConfettiPainter(
                particles: _particles,
                progress: _ctrl.value,
              ),
            ),
      ),
    );
  }
}

// ── Public API ─────────────────────────────────────────────

/// Shows a confetti burst animation over the entire screen.
///
/// The overlay is inserted into the root [Overlay] so it appears above
/// all other content. It removes itself automatically when the animation
/// completes (~1.4 s).
///
/// Safe to call multiple times — each call inserts a new independent burst.
class CelebrationOverlay {
  CelebrationOverlay._();

  static void show(BuildContext context) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder:
          (_) => Positioned.fill(
            child: _CelebrationWidget(onDone: entry.remove),
          ),
    );
    overlay.insert(entry);
  }
}
