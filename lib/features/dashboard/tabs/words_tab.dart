import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/emoji_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/word_cloud.dart';
import '../../../models/chat_analytics.dart';
import '../../../models/stat_types.dart';

class WordsTab extends StatelessWidget {
  const WordsTab({super.key, required this.analytics});
  final ChatAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final language = analytics.language;
    final emoji = analytics.emoji;
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        const SectionHeader(
          'Word cloud',
          subtitle: 'Common words and filler are filtered out',
        ),
        SurfaceCard(
          padding: const EdgeInsets.all(20),
          child: WordCloud(words: language.topWords, onLight: isLight),
        ),
        const SizedBox(height: 24),

        SurfaceCard(
          child: Row(
            children: [
              Expanded(
                child: _Mini(
                  label: 'Unique words',
                  value: Fmt.compact(language.uniqueWords),
                ),
              ),
              Expanded(
                child: _Mini(
                  label: 'Questions',
                  value: Fmt.compact(language.questionCount),
                ),
              ),
              Expanded(
                child: _Mini(
                  label: 'Links',
                  value: Fmt.compact(language.linkCount),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        if (language.topWords.isNotEmpty) ...[
          const SectionHeader('Most used words'),
          _RankedList(
            items: language.topWords.take(15).toList(),
            color: AppColors.accent,
          ),
          const SizedBox(height: 24),
        ],

        if (language.topPhrases.isNotEmpty) ...[
          const SectionHeader(
            'Phrases you repeat',
            subtitle: 'Two-word pairs used at least three times',
          ),
          _RankedList(
            items: language.topPhrases.take(10).toList(),
            color: AppColors.purple,
          ),
          const SizedBox(height: 24),
        ],

        if (emoji.top.isNotEmpty) ...[
          const SectionHeader('Emoji'),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final e in emoji.top.take(12))
                      SizedBox(
                        width: 48,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Emoji are drawn by the platform font and ignore
                            // the text scale, so this glyph size is fixed on
                            // purpose; only the count below it scales.
                            Text(
                              e.name,
                              style: const TextStyle(fontSize: 28),
                              maxLines: 1,
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                Fmt.compact(e.value),
                                style: theme.textTheme.bodyMedium,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                const Eyebrow('Mood'),
                const SizedBox(height: 10),
                for (final mood in EmojiMood.values)
                  if ((emoji.moodBreakdown[mood] ?? 0) > 0 &&
                      mood != EmojiMood.neutral)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 104,
                            child: Text(
                              '${mood.icon} ${mood.label}',
                              style: theme.textTheme.bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: emoji.totalEmojis == 0
                                    ? 0
                                    : (emoji.moodBreakdown[mood] ?? 0) /
                                    emoji.totalEmojis,
                                minHeight: 8,
                                backgroundColor: theme.colorScheme.outline,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            Fmt.compact(emoji.moodBreakdown[mood] ?? 0),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        if (language.topDomains.isNotEmpty) ...[
          const SectionHeader('Sites you share'),
          _RankedList(
            items: language.topDomains.take(8).toList(),
            color: AppColors.blue,
          ),
          const SizedBox(height: 24),
        ],

        if (language.longestMessage != null)
          Builder(
            builder: (context) {
              final longest = language.longestMessage!;
              final sender = longest.sender;
              return SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('Longest message'),
                    const SizedBox(height: 10),
                    Text(
                      sender == null
                          ? '${Fmt.n(longest.body.length)} characters'
                          : '${Fmt.n(longest.body.length)} characters '
                          'from $sender',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      longest.body,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _RankedList extends StatelessWidget {
  const _RankedList({required this.items, required this.color});
  final List<NamedValue> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = items.isEmpty ? 1 : items.first.value;

    return SurfaceCard(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Text(
                      '${i + 1}',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      items[i].name,
                      style: theme.textTheme.bodyLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: top == 0 ? 0 : items[i].value / top,
                        minHeight: 6,
                        backgroundColor: theme.colorScheme.outline,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 46,
                    child: Text(
                      Fmt.compact(items[i].value),
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodyMedium,
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

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Eyebrow(label),
      const SizedBox(height: 6),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          style: Theme.of(context).textTheme.titleLarge,
          maxLines: 1,
        ),
      ),
    ],
  );
}
