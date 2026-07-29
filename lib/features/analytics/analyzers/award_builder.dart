import '../../../core/utils/formatters.dart';
import '../../../models/chat_analytics.dart';
import '../../../models/participant_stats.dart';
import '../../../models/stat_types.dart';

/// The "who does X most" awards.
///
/// Every award is decided on a rate rather than a raw count wherever a raw
/// count would just re-crown whoever talks most. Someone who sends 80% of the
/// messages should not automatically win "night owl" too.
abstract final class AwardBuilder {
  static List<Award> build({
    required List<ParticipantStats> participants,
    required ActivityStats activity,
    required ResponseStats response,
    required EmojiStats emoji,
  }) {
    if (participants.isEmpty) return const [];
    final awards = <Award>[];

    void add(
      String title,
      ParticipantStats? winner,
      String Function(ParticipantStats p) value,
      String Function(ParticipantStats p) blurb,
      String emojiIcon,
    ) {
      if (winner == null) return;
      awards.add(
        Award(
          title: title,
          winner: winner.name,
          value: value(winner),
          blurb: blurb(winner),
          emoji: emojiIcon,
        ),
      );
    }

    // Only rank people with enough messages for a rate to mean anything.
    final ranked =
        participants.where((p) => p.messageCount >= 20).toList();
    final pool = ranked.isEmpty ? participants : ranked;

    add(
      'Most talkative',
      _maxBy(participants, (p) => p.messageCount.toDouble()),
      (p) => '${Fmt.compact(p.messageCount)} messages',
      (p) => '${Fmt.percent(p.share, decimals: 0)} of everything sent here',
      '👑',
    );

    add(
      'Night owl',
      _maxBy(pool, (p) => p.nightShare),
      (p) => '${Fmt.percent(p.nightShare, decimals: 0)} after midnight',
      (p) => 'Sends more between midnight and 5am than anyone else',
      '🦉',
    );

    add(
      'Early bird',
      _maxBy(pool, (p) => p.morningShare),
      (p) => '${Fmt.percent(p.morningShare, decimals: 0)} before 9am',
      (p) => 'Already typing while everyone else is asleep',
      '🌅',
    );

    add(
      'Weekend warrior',
      _maxBy(pool, (p) => p.weekendShare),
      (p) => '${Fmt.percent(p.weekendShare, decimals: 0)} on weekends',
      (p) => 'Saves it all up for Saturday and Sunday',
      '🎉',
    );

    add(
      'Chief laugher',
      _maxBy(pool, (p) => p.messageCount == 0 ? 0 : p.laughCount / p.messageCount),
      (p) => '${Fmt.n(p.laughCount)} laughs',
      (p) => 'Types "lol", "haha" or similar more often than anyone',
      '😂',
    );

    add(
      'Conversation starter',
      _maxBy(pool, (p) => p.conversationsStarted.toDouble()),
      (p) => '${Fmt.n(p.conversationsStarted)} times',
      (p) => 'Breaks the silence more than anyone else',
      '🚀',
    );

    add(
      'Last word',
      _maxBy(pool, (p) => p.conversationsEnded.toDouble()),
      (p) => '${Fmt.n(p.conversationsEnded)} times',
      (p) => 'Usually the one who sends the final message',
      '🎤',
    );

    add(
      'Double texter',
      _maxBy(pool, (p) => p.messageCount == 0 ? 0 : p.doubleTexts / p.messageCount),
      (p) => '${Fmt.n(p.doubleTexts)} double texts',
      (p) => 'Not the type to wait around for a reply',
      '📲',
    );

    add(
      'Emoji master',
      _maxBy(pool, (p) => p.emojisPerMessage),
      (p) => '${p.emojisPerMessage.toStringAsFixed(1)} per message',
      (p) => p.topEmoji == null
          ? 'Speaks fluent emoji'
          : 'Reaches for ${p.topEmoji} more than any word',
      '✨',
    );

    add(
      'Word wizard',
      _maxBy(pool, (p) => p.averageWordsPerMessage),
      (p) => '${p.averageWordsPerMessage.toStringAsFixed(1)} words per message',
      (p) => 'Writes paragraphs where others write "k"',
      '📝',
    );

    final fastest = response.fastestResponder == null
        ? null
        : participants
            .where((p) => p.name == response.fastestResponder)
            .firstOrNull;
    if (fastest?.medianReply != null) {
      awards.add(
        Award(
          title: 'Fastest replier',
          winner: fastest!.name,
          value: _duration(fastest.medianReply!),
          blurb: 'Typical time to answer, measured across every reply',
          emoji: '⚡',
        ),
      );
    }

    final slowest = response.slowestResponder == null
        ? null
        : participants
            .where((p) => p.name == response.slowestResponder)
            .firstOrNull;
    if (slowest?.medianReply != null) {
      awards.add(
        Award(
          title: 'Takes their time',
          winner: slowest!.name,
          value: _duration(slowest.medianReply!),
          blurb: 'Worth the wait, presumably',
          emoji: '🐢',
        ),
      );
    }

    return awards;
  }

  static String _duration(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    if (d.inHours < 24) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inDays}d';
  }

  static ParticipantStats? _maxBy(
    List<ParticipantStats> people,
    double Function(ParticipantStats) score,
  ) {
    if (people.isEmpty) return null;
    ParticipantStats? best;
    var bestScore = double.negativeInfinity;
    for (final p in people) {
      final value = score(p);
      if (value > bestScore) {
        bestScore = value;
        best = p;
      }
    }
    return bestScore <= 0 ? null : best;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
