import 'package:flutter/material.dart';

import '../../../core/extensions/extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../models/chat_analytics.dart';
import '../charts.dart';

class ActivityTab extends StatelessWidget {
  const ActivityTab({super.key, required this.analytics});
  final ChatAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final activity = analytics.activity;
    final theme = Theme.of(context);
    final monthly = activity.monthlyTrend;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        SurfaceCard(
          child: Row(
            children: [
              Expanded(
                child: _Peak(
                  label: 'Busiest hour',
                  value: Fmt.hour(activity.busiestHour),
                ),
              ),
              Expanded(
                child: _Peak(
                  label: 'Busiest day',
                  value: Fmt.weekdayShort[activity.busiestWeekday - 1],
                ),
              ),
              Expanded(
                child: _Peak(
                  label: 'Busiest month',
                  value: Fmt.month(activity.busiestMonth),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        const SectionHeader(
          'Through the day',
          subtitle: 'Every message, bucketed by the hour it was sent',
        ),
        SurfaceCard(
          child: SimpleBarChart(
            values: activity.hourHistogram,
            highlightIndex: activity.busiestHour,
            labelEvery: 3,
            labelAt: (i) => Fmt.hour(i).replaceAll(' ', ''),
          ),
        ),
        const SizedBox(height: 24),

        const SectionHeader('Through the week'),
        SurfaceCard(
          child: SimpleBarChart(
            values: activity.weekdayHistogram,
            color: AppColors.purple,
            highlightIndex: activity.busiestWeekday - 1,
            labelAt: (i) => Fmt.weekdayShort[i.clamp(0, 6)],
          ),
        ),
        const SizedBox(height: 24),

        const SectionHeader(
          'The relationship timeline',
          subtitle: 'Messages per month, since the first one',
        ),
        SurfaceCard(
          child: TrendLineChart(
            values: [for (final point in monthly) point.count],
            color: AppColors.blue,
            labelAt: (i) {
              if (i < 0 || i >= monthly.length) return '';
              final date = monthly[i].period;
              return '${Fmt.month(date.month)}\n${date.year % 100}';
            },
          ),
        ),
        const SizedBox(height: 24),

        const SectionHeader(
          'Every day at a glance',
          subtitle: 'Darker squares are busier days',
        ),
        SurfaceCard(
          child: CalendarHeatmap(
            perDay: activity.perDay,
            from: analytics.conversation.firstAt,
            to: analytics.conversation.lastAt,
          ),
        ),
        const SizedBox(height: 24),

        const SectionHeader('Streaks and silences'),
        SurfaceCard(
          child: Column(
            children: [
              _Row(
                label: 'Longest streak',
                value: activity.longestStreak.exists
                    ? '${activity.longestStreak.days} days'
                    : '—',
                detail: activity.longestStreak.exists
                    ? '${activity.longestStreak.start!.shortDate} – '
                        '${activity.longestStreak.end!.shortDate}'
                    : null,
              ),
              _Row(
                label: 'Streak at the end',
                value: activity.currentStreak.exists
                    ? '${activity.currentStreak.days} days'
                    : '—',
              ),
              _Row(
                label: 'Longest silence',
                value: activity.longestSilence.humanized,
                detail: activity.longestSilenceStart?.shortDate,
              ),
              _Row(
                label: 'Quiet days',
                value: Fmt.n(analytics.conversation.silentDays),
                detail: 'days with nothing said',
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Busiest single day: ${activity.busiestDay.date.longDate} with '
          '${Fmt.n(activity.busiestDay.count)} messages.',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _Peak extends StatelessWidget {
  const _Peak({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(label),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.detail,
    this.last = false,
  });

  final String label;
  final String value;
  final String? detail;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyLarge),
                if (detail != null)
                  Text(detail!, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}
