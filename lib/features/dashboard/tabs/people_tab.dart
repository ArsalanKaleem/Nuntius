import 'package:flutter/material.dart';

import '../../../core/extensions/extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../models/chat_analytics.dart';
import '../../../models/participant_stats.dart';

class PeopleTab extends StatelessWidget {
  const PeopleTab({super.key, required this.analytics});
  final ChatAnalytics analytics;

  static const _medals = ['🥇', '🥈', '🥉'];

  @override
  Widget build(BuildContext context) {
    final people = analytics.participants;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        const SectionHeader('Leaderboard', subtitle: 'By messages sent'),
        SurfaceCard(
          child: Column(
            children: [
              for (var i = 0; i < people.length; i++)
                _LeaderboardRow(
                  rank: i,
                  medal: i < _medals.length ? _medals[i] : null,
                  person: people[i],
                  topCount: people.first.messageCount,
                  last: i == people.length - 1,
                ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        if (analytics.awards.isNotEmpty) ...[
          const SectionHeader(
            'Awards',
            subtitle: 'Decided on rates, not raw totals',
          ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.98,
            children: [
              for (final award in analytics.awards)
                SurfaceCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(award.emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(height: 10),
                      Eyebrow(award.title),
                      const SizedBox(height: 6),
                      Text(
                        Fmt.name(award.winner, max: 14),
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        award.value,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const Spacer(),
                      Text(
                        award.blurb,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontSize: 12),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),
        ],

        const SectionHeader('Person by person'),
        for (final person in people)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PersonCard(person: person),
          ),
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.person,
    required this.topCount,
    required this.last,
    this.medal,
  });

  final int rank;
  final ParticipantStats person;
  final int topCount;
  final bool last;
  final String? medal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppColors.forParticipant(person.colorIndex);

    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 16),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              medal ?? '${rank + 1}',
              style: medal != null
                  ? const TextStyle(fontSize: 18)
                  : theme.textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        person.name,
                        style: theme.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${Fmt.compact(person.messageCount)}  '
                      '${Fmt.percent(person.share, decimals: 0)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(
                      begin: 0,
                      end: topCount == 0 ? 0 : person.messageCount / topCount,
                    ),
                    duration: Duration(milliseconds: 700 + rank * 90),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 8,
                      backgroundColor: theme.colorScheme.outline,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.person});
  final ParticipantStats person;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppColors.forParticipant(person.colorIndex);

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withOpacity(0.18),
                child: Text(
                  person.name.characters.first.toUpperCase(),
                  style: theme.textTheme.titleMedium?.copyWith(color: color),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.name,
                      style: theme.textTheme.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      person.typingPersonality,
                      style: theme.textTheme.bodyMedium?.copyWith(color: color),
                    ),
                  ],
                ),
              ),
              if (person.topEmoji != null)
                Text(person.topEmoji!, style: const TextStyle(fontSize: 26)),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 20,
            runSpacing: 14,
            children: [
              _Mini(label: 'Messages', value: Fmt.compact(person.messageCount)),
              _Mini(label: 'Words', value: Fmt.compact(person.wordCount)),
              _Mini(
                label: 'Per message',
                value: person.averageWordsPerMessage.toStringAsFixed(1),
              ),
              _Mini(
                label: 'Typical reply',
                value: person.medianReply?.humanized ?? '—',
              ),
              _Mini(label: 'Double texts', value: Fmt.n(person.doubleTexts)),
              _Mini(
                label: 'Starts chats',
                value: Fmt.n(person.conversationsStarted),
              ),
              _Mini(label: 'Emoji', value: Fmt.n(person.emojiCount)),
              _Mini(
                label: 'Longest streak',
                value: '${person.longestStreak.days}d',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 96,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(label),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      );
}
