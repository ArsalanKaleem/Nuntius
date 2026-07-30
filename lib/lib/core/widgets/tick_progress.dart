import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The Wrapped page indicator, drawn as WhatsApp delivery ticks.
///
/// This is the app's signature element. A row of dots would have worked, but
/// the double tick is the one piece of visual vocabulary everybody already
/// associates with a message being read — which is exactly what the Wrapped
/// sequence is doing, one card at a time.
///
///   seen       ✓✓ in accent green
///   current    ✓  single tick, white
///   upcoming   ·  faint dot
class TickProgress extends StatelessWidget {
  const TickProgress({
    super.key,
    required this.count,
    required this.current,
    this.color = Colors.white,
    this.accent = const Color(0xFF25D366),
  });

  final int count;
  final int current;
  final Color color;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Card ${current + 1} of $count',
      excludeSemantics: true,
      child: SizedBox(
        height: 14,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: SizedBox(
                  width: i < current ? 16 : (i == current ? 11 : 6),
                  height: 12,
                  child: CustomPaint(
                    painter: _TickPainter(
                      state: i < current
                          ? _TickState.seen
                          : (i == current
                              ? _TickState.current
                              : _TickState.upcoming),
                      color: color,
                      accent: accent,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _TickState { seen, current, upcoming }

class _TickPainter extends CustomPainter {
  const _TickPainter({
    required this.state,
    required this.color,
    required this.accent,
  });

  final _TickState state;
  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    switch (state) {
      case _TickState.upcoming:
        canvas.drawCircle(
          Offset(size.width / 2, size.height / 2),
          2.2,
          Paint()..color = color.withOpacity(0.35),
        );
      case _TickState.current:
        _tick(canvas, size, 0, color, 1);
      case _TickState.seen:
        _tick(canvas, size, 0, accent, 0.95);
        _tick(canvas, size, 5, accent, 0.95);
    }
  }

  void _tick(
    Canvas canvas,
    Size size,
    double dx,
    Color tint,
    double opacity,
  ) {
    final paint = Paint()
      ..color = tint.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final h = size.height;
    final path = Path()
      ..moveTo(dx + 0.5, h * 0.55)
      ..lineTo(dx + 3.4, h * 0.86)
      ..lineTo(dx + 9.2, h * 0.16);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TickPainter oldDelegate) =>
      oldDelegate.state != state || oldDelegate.accent != accent;
}

/// Slow-drifting bubbles behind Wrapped cards. Deliberately low-contrast: the
/// number on the card is the thing you should look at.
class FloatingShapes extends StatefulWidget {
  const FloatingShapes({
    super.key,
    this.seed = 0,
    this.animate = true,
    this.color = Colors.white,
  });

  final int seed;
  final bool animate;
  final Color color;

  @override
  State<FloatingShapes> createState() => _FloatingShapesState();
}

class _FloatingShapesState extends State<FloatingShapes>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(FloatingShapes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _ShapesPainter(
              t: _controller.value,
              seed: widget.seed,
              color: widget.color,
            ),
            size: Size.infinite,
          ),
        ),
      );
}

class _ShapesPainter extends CustomPainter {
  _ShapesPainter({required this.t, required this.seed, required this.color});
  final double t;
  final int seed;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed * 7919 + 13);
    for (var i = 0; i < 6; i++) {
      final baseX = random.nextDouble();
      final baseY = random.nextDouble();
      final radius = 40 + random.nextDouble() * 90;
      final drift = 0.06 + random.nextDouble() * 0.08;
      final phase = random.nextDouble();

      final dy = math.sin((t + phase) * 2 * math.pi) * drift;
      final dx = math.cos((t + phase) * 2 * math.pi) * drift * 0.6;

      canvas.drawCircle(
        Offset((baseX + dx) * size.width, (baseY + dy) * size.height),
        radius,
        Paint()..color = color.withOpacity(0.045),
      );
    }
  }

  @override
  bool shouldRepaint(_ShapesPainter oldDelegate) => oldDelegate.t != t;
}
