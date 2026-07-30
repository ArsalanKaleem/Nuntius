import 'package:flutter/material.dart';

import '../../core/extensions/extensions.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/utils/formatters.dart';
import '../../models/chat_analytics.dart';

enum WrappedLayout { intro, stat, leaderboard, emoji, wordCloud, score }

/// One screen of the Wrapped story.
class WrappedCard {
  const WrappedCard({
    required this.id,
    required this.eyebrow,
    required this.headline,
    required this.body,
    required this.gradient,
    required this.layout,
    this.value,
    this.numericValue,
    this.emoji,
  });

  final String id;
  final String eyebrow;

  /// The line above or below the big number.
  final String headline;
  final String body;
  final LinearGradient gradient;
  final WrappedLayout layout;

  /// Pre-formatted display value for non-numeric cards.
  final String? value;

  /// When set, the card animates a counter up to this.
  final num? numericValue;
  final String? emoji;
}

/// Builds the story from the analysis.
///
/// Cards are skipped when the chat has nothing to say for them — a chat with
/// no emoji does not get an emoji card with a zero on it. The sequence is
/// ordered to build: how long, how much, who, what, and finally the score.
abstract final class WrappedStory {
  static List<WrappedCard> build(ChatAnalytics a) {
    final cards = <WrappedCard>[];
    var gradientIndex = 0;
    LinearGradient next() => AppGradients.byIndex(gradientIndex++);

    final conversation = a.conversation;

    cards.add(
      WrappedCard(
        id: 'welcome',
        eyebrow: 'Chat Wrapped',
        headline: a.chatTitle,
        body: 'Everything you two said, counted. Swipe to begin.',
        gradient: next(),
        layout: WrappedLayout.intro,
        emoji: '👋',
      ),
    );

    cards.add(
      WrappedCard(
        id: 'started',
        eyebrow: 'It began on',
        headline: conversation.firstAt.longDate,
        body: 'That was ${Fmt.n(conversation.totalDays)} days ago. You have '
            'been talking on ${Fmt.n(conversation.activeDays)} of them.',
        gradient: next(),
        layout: WrappedLayout.stat,
        value: conversation.firstAt.longDate,
        emoji: '🌱',
      ),
    );

    cards.add(
      WrappedCard(
        id: 'messages',
        eyebrow: 'Messages sent',
        headline: 'messages',
        body: '${Fmt.n(conversation.totalWords)} words, or about '
            '${conversation.messagesPerActiveDay.round()} messages on every '
            'day you spoke.',
        gradient: next(),
        layout: WrappedLayout.stat,
        numericValue: conversation.totalMessages,
        emoji: '💬',
      ),
    );

    if (a.participants.length >= 2) {
      final top = a.participants.first;
      cards.add(
        WrappedCard(
          id: 'talkative',
          eyebrow: a.isGroupChat ? 'Loudest in the group' : 'More talkative',
          headline: top.name,
          body: '${top.name} sent ${Fmt.percent(top.share, decimals: 0)} of '
              'everything here — ${Fmt.n(top.messageCount)} messages against '
              '${Fmt.n(a.participants[1].messageCount)}.',
          gradient: next(),
          layout: WrappedLayout.leaderboard,
          emoji: '👑',
        ),
      );
    }

    final favorite = a.emoji.favorite;
    if (favorite != null && a.emoji.top.isNotEmpty) {
      cards.add(
        WrappedCard(
          id: 'emoji',
          eyebrow: 'Your emoji',
          headline: favorite,
          body: 'Used ${Fmt.n(a.emoji.top.first.value)} times. Your chat leans '
              '${a.emoji.dominantMood.label.toLowerCase()}.',
          gradient: next(),
          layout: WrappedLayout.emoji,
          value: favorite,
          emoji: favorite,
        ),
      );
    }

    final hour = a.activity.busiestHour;
    cards.add(
      WrappedCard(
        id: 'hour',
        eyebrow: hour <= 4 ? 'Night owls' : 'Peak hour',
        headline: Fmt.hourRange(hour),
        body: hour <= 4
            ? 'Most of this conversation happens after midnight. Sleep is '
                'clearly optional.'
            : 'That is when this chat is at its busiest, week in and week out.',
        gradient: next(),
        layout: WrappedLayout.stat,
        value: Fmt.hour(hour),
        emoji: hour <= 4 ? '🦉' : '🕰️',
      ),
    );

    final median = a.response.medianReply;
    if (median != null && a.response.isReliable) {
      cards.add(
        WrappedCard(
          id: 'reply',
          eyebrow: 'Typical reply',
          headline: median.humanized,
          body: a.response.fastestResponder == null
              ? 'Measured across every reply in the chat.'
              : '${a.response.fastestResponder} is the quickest off the mark.',
          gradient: next(),
          layout: WrappedLayout.stat,
          value: median.humanized,
          emoji: '⚡',
        ),
      );
    }

    final streak = a.activity.longestStreak;
    if (streak.exists && streak.days >= 3) {
      cards.add(
        WrappedCard(
          id: 'streak',
          eyebrow: 'Longest streak',
          headline: 'days in a row',
          body: 'From ${streak.start!.shortDate} to ${streak.end!.shortDate}, '
              'not a single day passed without a message.',
          gradient: next(),
          layout: WrappedLayout.stat,
          numericValue: streak.days,
          emoji: '🔥',
        ),
      );
    }

    if (a.language.topWords.length >= 8) {
      cards.add(
        WrappedCard(
          id: 'words',
          eyebrow: 'Your words',
          headline: a.language.topWords.first.name,
          body: 'The words you keep coming back to, sized by how often they '
              'turn up.',
          gradient: next(),
          layout: WrappedLayout.wordCloud,
          emoji: '📝',
        ),
      );
    }

    cards.add(
      WrappedCard(
        id: 'score',
        eyebrow: 'Friendship score',
        headline: a.scores.friendshipGrade,
        body: 'Built from how consistently you talk, how evenly you share the '
            'conversation, how fast you reply and how warm it reads.',
        gradient: AppGradients.dusk,
        layout: WrappedLayout.score,
        numericValue: a.scores.friendship.round(),
        emoji: '🏆',
      ),
    );

    return cards;
  }
}
