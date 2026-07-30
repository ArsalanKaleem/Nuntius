import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'animated_counter.dart';
import 'eyebrow.dart';
import 'glass_card.dart';

/// One number with its label. The building block of the dashboard overview.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.numericValue,
    this.detail,
    this.accent,
    this.icon,
    this.onTap,
  });

  final String label;

  /// Pre-formatted display value, used when the statistic is not a plain
  /// number (a duration, a name, an emoji).
  final String value;

  /// When set, the tile animates up to this number instead of showing [value].
  final num? numericValue;

  final String? detail;
  final Color? accent;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = accent ?? AppColors.accent;

    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      button: onTap != null,
      child: SurfaceCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: tint),
                  const SizedBox(width: 8),
                ],
                Expanded(child: Eyebrow(label)),
              ],
            ),
            const SizedBox(height: 14),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: numericValue != null
                  ? AnimatedCounter(
                      value: numericValue!,
                      compact: numericValue! >= 100000,
                      style: theme.textTheme.displaySmall,
                    )
                  : Text(value, style: theme.textTheme.displaySmall),
            ),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(
                detail!,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
