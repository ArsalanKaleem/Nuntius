import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Empty screens are an invitation to act, so every one of these takes an
/// action rather than just apologising for having nothing to show.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.emoji = '💬',
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String emoji;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // A chat bubble with nothing in it — the illustration is the
              // subject of the app, not a generic spot drawing.
              CustomPaint(
                size: const Size(96, 82),
                painter: _EmptyBubblePainter(
                  color: theme.colorScheme.outline,
                  fill: theme.colorScheme.surface,
                ),
                child: SizedBox(
                  width: 96,
                  height: 82,
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 24),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyBubblePainter extends CustomPainter {
  const _EmptyBubblePainter({required this.color, required this.fill});
  final Color color;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final bubble = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height - 14),
      const Radius.circular(22),
    );
    final tail = Path()
      ..moveTo(20, size.height - 15)
      ..lineTo(20, size.height)
      ..lineTo(38, size.height - 15)
      ..close();

    canvas
      ..drawRRect(bubble, Paint()..color = fill)
      ..drawPath(tail, Paint()..color = fill)
      ..drawRRect(
        bubble,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      )
      ..drawPath(
        tail,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
  }

  @override
  bool shouldRepaint(_EmptyBubblePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.fill != fill;
}

/// Shown when a screen has data but a filter matched nothing.
class NoResults extends StatelessWidget {
  const NoResults({super.key, this.query});
  final String? query;

  @override
  Widget build(BuildContext context) => EmptyState(
        emoji: '🔍',
        title: 'Nothing found',
        message: query == null
            ? 'Try a different filter.'
            : 'No messages match "$query". Try a shorter word or clear the '
                'filters.',
      );
}

/// Small inline badge reused on the home screen and settings.
class PrivacyBadge extends StatelessWidget {
  const PrivacyBadge({super.key, this.text = 'Your chats never leave your device.'});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.accent.withOpacity(0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline_rounded,
              size: 15, color: AppColors.accent),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
