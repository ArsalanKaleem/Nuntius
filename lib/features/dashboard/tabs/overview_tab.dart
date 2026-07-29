import 'package:flutter/material.dart';

import '../../../core/extensions/extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../models/chat_analytics.dart';
import '../../../models/chat_message.dart';
import '../../../models/insight.dart';

class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key, required this.analytics});
  final ChatAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final c = analytics.conversation;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        _ScoreCard(analytics: analytics),
        const SizedBox(height: 24),

        const SectionHeader('The numbers'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.18,
          children: [
            StatTile(
              label: 'Messages',
              value: Fmt.n(c.totalMessages),
              numericValue: c.totalMessages,
              icon: Icons.chat_bubble_outline_rounded,
            ),
            StatTile(
              label: 'Words',
              value: Fmt.n(c.totalWords),
              numericValue: c.totalWords,
              accent: AppColors.purple,
              icon: Icons.abc_rounded,
            ),
            StatTile(
              label: 'Days talking',
              value: Fmt.n(c.activeDays),
              numericValue: c.activeDays,
              detail: 'of ${Fmt.n(c.totalDays)} days',
              accent: AppColors.blue,
              icon: Icons.calendar_today_outlined,
            ),
            StatTile(
              label: 'Per active day',
              value: c.messagesPerActiveDay.toStringAsFixed(1),
              detail: 'messages',
              accent: AppColors.warning,
              icon: Icons.speed_rounded,
            ),
            StatTile(
              label: 'Typical reply',
              value: analytics.response.medianReply?.humanized ?? '—',
              detail: analytics.response.isReliable
                  ? 'median across ${Fmt.compact(analytics.response.sampleCount)} replies'
                  : 'too few replies to be certain',
              icon: Icons.bolt_rounded,
            ),
            StatTile(
              label: 'Longest silence',
              value: analytics.activity.longestSilence.humanized,
              detail: analytics.activity.longestSilenceStart?.shortDate,
              accent: AppColors.grey,
              icon: Icons.hourglass_empty_rounded,
            ),
          ],
        ),
        const SizedBox(height: 28),

        if (analytics.insights.isNotEmpty) ...[
          const SectionHeader(
            'What stands out',
            subtitle: 'Generated from your own numbers, on this device',
          ),
          for (final insight in analytics.insights.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _InsightCard(insight: insight),
            ),
          const SizedBox(height: 28),
        ],

        const SectionHeader('What you send'),
        SurfaceCard(
          child: Column(
            children: [
              for (final entry in _typeRows(c))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          entry.$1,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      Expanded(
                        flex: 6,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: c.totalMessages == 0
                                ? 0
                                : entry.$2 / c.totalMessages,
                            minHeight: 8,
                            backgroundColor: theme.colorScheme.outline,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 58,
                        child: Text(
                          Fmt.compact(entry.$2),
                          textAlign: TextAlign.right,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Groups the message-type breakdown into the handful of rows worth showing.
  List<(String, int)> _typeRows(ConversationStats c) {
    final rows = <(String, int)>[];
    void add(String label, int count) {
      if (count > 0) rows.add((label, count));
    }

    final breakdown = c.typeBreakdown;
    var media = 0;
    breakdown.forEach((type, count) {
      if (type.isMedia) media += count;
    });

    add('Text', breakdown[MessageType.text] ?? 0);
    add('Photos and video', media);
    add('Deleted', breakdown[MessageType.deleted] ?? 0);
    rows.sort((a, b) => b.$2.compareTo(a.$2));
    return rows;
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.analytics});
  final ChatAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scores = analytics.scores;

    return SurfaceCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Friendship score'),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                scores.friendship.round().toString(),
                style: theme.textTheme.displayMedium
                    ?.copyWith(color: AppColors.accent),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Text('/100', style: theme.textTheme.titleMedium),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  scores.friendshipGrade,
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _Bar(label: 'Consistency', value: scores.consistency),
          _Bar(label: 'Balance', value: scores.balance),
          _Bar(label: 'Responsiveness', value: scores.responsiveness),
          _Bar(label: 'Warmth', value: scores.warmth, last: true),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.value, this.last = false});
  final String label;
  final double value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Row(
        children: [
          SizedBox(
            width: 116,
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (value / 100).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: v,
                  minHeight: 7,
                  backgroundColor: theme.colorScheme.outline,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 30,
            child: Text(
              value.round().toString(),
              textAlign: TextAlign.right,
              style: theme.textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});
  final Insight insight;

  Color _tint() => switch (insight.tone) {
        InsightTone.celebratory => AppColors.accent,
        InsightTone.playful => AppColors.purple,
        InsightTone.warm => AppColors.warning,
        InsightTone.curious => AppColors.blue,
        InsightTone.factual => AppColors.grey,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _tint().withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(insight.emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.text, style: theme.textTheme.bodyLarge),
                if (insight.detail != null) ...[
                  const SizedBox(height: 4),
                  Text(insight.detail!, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
