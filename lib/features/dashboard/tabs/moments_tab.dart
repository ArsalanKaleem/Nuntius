import 'package:flutter/material.dart';

import '../../../core/extensions/extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/auto_grid.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../models/achievement.dart';
import '../../../models/chat_analytics.dart';
import '../../../models/milestone.dart';

class MomentsTab extends StatelessWidget {
  const MomentsTab({super.key, required this.analytics});
  final ChatAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final milestones = analytics.milestones;
    final achievements = analytics.achievements;
    final unlocked = achievements.where((a) => a.unlocked).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        SectionHeader(
          'Badges',
          subtitle: '$unlocked of ${achievements.length} unlocked',
        ),
        AutoGrid(
          children: [
            for (final achievement in achievements)
              _BadgeCard(achievement: achievement),
          ],
        ),
        const SizedBox(height: 28),

        const SectionHeader('Timeline', subtitle: 'The moments worth marking'),
        for (var i = 0; i < milestones.length; i++)
          _TimelineRow(
            milestone: milestones[i],
            first: i == 0,
            last: i == milestones.length - 1,
          ),
      ],
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.achievement});
  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unlocked = achievement.unlocked;

    return Opacity(
      opacity: unlocked ? 1 : 0.55,
      child: SurfaceCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(achievement.emoji, style: const TextStyle(fontSize: 26)),
                const Spacer(),
                if (unlocked)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: AppColors.accent,
                  )
                else
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              achievement.title,
              style: theme.textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              achievement.description,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (!unlocked) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: achievement.progress,
                  minHeight: 5,
                  backgroundColor: theme.colorScheme.outline,
                ),
              ),
            ] else if (achievement.holder != null) ...[
              const SizedBox(height: 8),
              Eyebrow(achievement.holder!),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.milestone,
    required this.first,
    required this.last,
  });

  final Milestone milestone;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The rail: a continuous line with a node per milestone, so the gaps
          // between moments read as time passing.
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 10,
                  color: first
                      ? Colors.transparent
                      : theme.colorScheme.outline,
                ),
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: Text(
                    milestone.emoji,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color:
                    last ? Colors.transparent : theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 20, top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(milestone.date.shortDate,
                      style: theme.textTheme.labelSmall),
                  const SizedBox(height: 4),
                  Text(milestone.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(milestone.subtitle,
                      style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
