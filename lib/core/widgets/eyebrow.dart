import 'package:flutter/material.dart';

/// The small tracked-out uppercase label that sits above every statistic.
///
/// It is the one typographic device repeated across the whole app — dashboard,
/// Wrapped cards, share images and the PDF — so a number is never presented
/// without saying what it counts.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color, this.maxLines = 2});
  final String text;
  final Color? color;

  /// Eyebrows are tracked out, so they run wide for their point size. Capping
  /// the line count keeps a long label ("WEEKEND WARRIOR" at a large text
  /// scale) from silently pushing everything below it down a line.
  final int maxLines;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
  );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle, this.action});
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
