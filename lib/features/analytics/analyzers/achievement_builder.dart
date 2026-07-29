import '../../../models/achievement.dart';
import '../../../models/chat_analytics.dart';
import '../../../models/participant_stats.dart';

/// Badges. Locked badges keep their progress so the wall does not look like a
/// list of things you failed at.
abstract final class AchievementBuilder {
  static List<Achievement> build({
    required List<ParticipantStats> participants,
    required ConversationStats conversation,
    required ActivityStats activity,
    required ResponseStats response,
    required EmojiStats emoji,
    required Scores scores,
  }) {
    final badges = <Achievement>[];

    void badge(
      String id,
      String title,
      String description,
      String emojiIcon,
      double value,
      double target, {
      String? holder,
    }) {
      final progress = target == 0 ? 0.0 : (value / target).clamp(0.0, 1.0);
      badges.add(
        Achievement(
          id: id,
          title: title,
          description: description,
          emoji: emojiIcon,
          unlocked: value >= target,
          progress: progress,
          holder: holder,
        ),
      );
    }

    final nightOwl = _maxBy(participants, (p) => p.nightShare);
    badge(
      'night_owl',
      'Night owl',
      'A fifth of someone\u2019s messages arrive between midnight and 5am',
      '🦉',
      nightOwl?.nightShare ?? 0,
      0.20,
      holder: nightOwl?.name,
    );

    final emojiMaster = _maxBy(participants, (p) => p.emojisPerMessage);
    badge(
      'emoji_master',
      'Emoji master',
      'Averages at least one emoji per message',
      '✨',
      emojiMaster?.emojisPerMessage ?? 0,
      1.0,
      holder: emojiMaster?.name,
    );

    badge(
      'conversation_king',
      'Conversation royalty',
      '10,000 messages in a single chat',
      '👑',
      conversation.totalMessages.toDouble(),
      10000,
    );

    final weekend = _maxBy(participants, (p) => p.weekendShare);
    badge(
      'weekend_warrior',
      'Weekend warrior',
      'Two in five messages land on a Saturday or Sunday',
      '🎉',
      weekend?.weekendShare ?? 0,
      0.40,
      holder: weekend?.name,
    );

    final fastest = participants
        .where((p) => p.medianReply != null && p.messageCount >= 20)
        .toList()
      ..sort((a, b) => a.medianReply!.compareTo(b.medianReply!));
    final fastestMinutes = fastest.isEmpty
        ? double.infinity
        : fastest.first.medianReply!.inSeconds / 60.0;
    badges.add(
      Achievement(
        id: 'fast_responder',
        title: 'Fast responder',
        description: 'Typical reply in under two minutes',
        emoji: '⚡',
        unlocked: fastestMinutes <= 2,
        progress: fastestMinutes.isInfinite
            ? 0
            : (2 / fastestMinutes).clamp(0.0, 1.0),
        holder: fastest.isEmpty ? null : fastest.first.name,
      ),
    );

    final doubler = _maxBy(
      participants,
      (p) => p.messageCount == 0 ? 0 : p.doubleTexts / p.messageCount,
    );
    badge(
      'double_texter',
      'Double texter',
      'One in six messages follows their own last one',
      '📲',
      doubler == null || doubler.messageCount == 0
          ? 0
          : doubler.doubleTexts / doubler.messageCount,
      1 / 6,
      holder: doubler?.name,
    );

    final wordy = _maxBy(participants, (p) => p.averageWordsPerMessage);
    badge(
      'word_wizard',
      'Word wizard',
      'Averages 20 words or more per message',
      '📝',
      wordy?.averageWordsPerMessage ?? 0,
      20,
      holder: wordy?.name,
    );

    badge(
      'forever_friends',
      'Forever friends',
      'This chat has been going for three years',
      '🫂',
      conversation.totalDays.toDouble(),
      365 * 3,
    );

    badge(
      'unbroken',
      'Unbroken',
      'A 30-day streak without missing a single day',
      '🔥',
      activity.longestStreak.days.toDouble(),
      30,
    );

    badge(
      'perfectly_balanced',
      'Perfectly balanced',
      'Neither side carries the conversation',
      '⚖️',
      scores.balance,
      92,
    );

    badge(
      'marathon_day',
      'Marathon day',
      '500 messages inside 24 hours',
      '💥',
      activity.busiestDay.count.toDouble(),
      500,
    );

    badge(
      'novelists',
      'Novelists',
      'Written more words together than a paperback novel',
      '📚',
      conversation.totalWords.toDouble(),
      80000,
    );

    badges.sort((a, b) {
      if (a.unlocked != b.unlocked) return a.unlocked ? -1 : 1;
      return b.progress.compareTo(a.progress);
    });
    return badges;
  }

  static ParticipantStats? _maxBy(
    List<ParticipantStats> people,
    double Function(ParticipantStats) score,
  ) {
    ParticipantStats? best;
    var bestScore = -1.0;
    for (final p in people) {
      final value = score(p);
      if (value > bestScore) {
        bestScore = value;
        best = p;
      }
    }
    return best;
  }
}
