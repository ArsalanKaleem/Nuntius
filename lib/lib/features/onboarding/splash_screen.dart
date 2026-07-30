import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import '../../routes/app_router.dart';

/// The logo is a chat bubble that fills, then gets its second tick — the same
/// motif the Wrapped progress indicator uses.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _continue();
  }

  Future<void> _continue() async {
    final settings = ref.read(settingsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    context.go(
      settings.onboardingComplete ? Routes.home : Routes.onboarding,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                size: const Size(120, 108),
                painter: _LogoPainter(_controller.value),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              AppInfo.name,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Chat Wrapped',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final bubbleProgress = Curves.easeOutBack.transform(t.clamp(0, 0.6) / 0.6);
    final tickOne = ((t - 0.45) / 0.25).clamp(0.0, 1.0);
    final tickTwo = ((t - 0.65) / 0.25).clamp(0.0, 1.0);

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(bubbleProgress);
    canvas.translate(-size.width / 2, -size.height / 2);

    final bubble = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height - 16),
      const Radius.circular(28),
    );
    final tail = Path()
      ..moveTo(26, size.height - 17)
      ..lineTo(24, size.height)
      ..lineTo(48, size.height - 17)
      ..close();

    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.secondary, AppColors.accent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas
      ..drawRRect(bubble, fill)
      ..drawPath(tail, fill);
    canvas.restore();

    void tick(double dx, double progress) {
      if (progress <= 0) return;
      final paint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final start = Offset(dx, size.height * 0.42);
      final mid = Offset(dx + 10, size.height * 0.56);
      final end = Offset(dx + 30, size.height * 0.24);

      final path = Path()..moveTo(start.dx, start.dy);
      if (progress < 0.5) {
        final p = progress / 0.5;
        path.lineTo(
          start.dx + (mid.dx - start.dx) * p,
          start.dy + (mid.dy - start.dy) * p,
        );
      } else {
        final p = (progress - 0.5) / 0.5;
        path
          ..lineTo(mid.dx, mid.dy)
          ..lineTo(
            mid.dx + (end.dx - mid.dx) * p,
            mid.dy + (end.dy - mid.dy) * p,
          );
      }
      canvas.drawPath(path, paint);
    }

    tick(size.width * 0.22, tickOne);
    tick(size.width * 0.42, tickTwo);
  }

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) => oldDelegate.t != t;
}
