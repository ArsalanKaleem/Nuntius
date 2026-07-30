import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Confetti for the final Wrapped card.
///
/// Hand-rolled rather than pulled from a package: it is about eighty lines,
/// it respects the app's animation setting, and it keeps the dependency list
/// honest for an app that advertises having no moving parts it cannot explain.
class Confetti extends StatefulWidget {
  const Confetti({super.key, this.pieces = 70, this.play = true});
  final int pieces;
  final bool play;

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  late final List<_Piece> _confetti = _build(widget.pieces);

  @override
  void initState() {
    super.initState();
    if (widget.play) _controller.forward();
  }

  @override
  void didUpdateWidget(Confetti oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.play && !oldWidget.play) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static List<_Piece> _build(int count) {
    final random = math.Random(7);
    const palette = [
      AppColors.accent,
      AppColors.purple,
      AppColors.blue,
      AppColors.warning,
      Colors.white,
    ];
    return [
      for (var i = 0; i < count; i++)
        _Piece(
          x: random.nextDouble(),
          delay: random.nextDouble() * 0.35,
          drift: (random.nextDouble() - 0.5) * 0.4,
          size: 5 + random.nextDouble() * 7,
          spin: (random.nextDouble() - 0.5) * 12,
          color: palette[random.nextInt(palette.length)],
        ),
    ];
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              size: Size.infinite,
              painter: _ConfettiPainter(_confetti, _controller.value),
            ),
          ),
        ),
      );
}

class _Piece {
  const _Piece({
    required this.x,
    required this.delay,
    required this.drift,
    required this.size,
    required this.spin,
    required this.color,
  });

  final double x;
  final double delay;
  final double drift;
  final double size;
  final double spin;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter(this.pieces, this.t);
  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final piece in pieces) {
      final progress = ((t - piece.delay) / (1 - piece.delay)).clamp(0.0, 1.0);
      if (progress <= 0) continue;

      final y = -0.1 + progress * 1.25;
      final x = piece.x + piece.drift * progress;
      final fade = progress > 0.75 ? 1 - (progress - 0.75) / 0.25 : 1.0;

      canvas
        ..save()
        ..translate(x * size.width, y * size.height)
        ..rotate(piece.spin * progress)
        ..drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: piece.size,
            height: piece.size * 0.5,
          ),
          Paint()..color = piece.color.withOpacity(fade.clamp(0.0, 1.0)),
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => oldDelegate.t != t;
}
