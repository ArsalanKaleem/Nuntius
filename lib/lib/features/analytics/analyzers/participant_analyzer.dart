import '../../../core/utils/emoji_utils.dart';
import '../../../core/utils/text_utils.dart';
import '../../../models/chat_message.dart';
import '../../../models/participant_stats.dart';
import '../analysis_context.dart';
import 'streaks.dart';

/// Builds one [ParticipantStats] per person.
class ParticipantAnalyzer {
  final Map<String, _Accumulator> _people = {};
  int _countedMessages = 0;

  void add(MessageContext ctx) {
    final message = ctx.message;
    final sender = message.sender;
    if (sender == null) return;

    _countedMessages++;
    final acc = _people.putIfAbsent(sender, () => _Accumulator(sender));
    acc.messages++;
    acc.words += ctx.wordCount;
    acc.chars += ctx.charCount;
    acc.days.add(_dayKey(message.timestamp));
    acc.hours[message.timestamp.hour]++;
    acc.weekdays[message.timestamp.weekday - 1]++;
    acc.types[message.type] = (acc.types[message.type] ?? 0) + 1;

    acc.firstAt ??= message.timestamp;
    acc.lastAt = message.timestamp;

    if (message.type.isMedia) acc.media++;
    if (message.type == MessageType.deleted) acc.deleted++;

    if (message.hasText) {
      if (TextUtils.hasLink(message.body)) acc.links++;
      if (TextUtils.isQuestion(message.body)) acc.questions++;
      acc.laughs += TextUtils.laughterCount(message.body);
      if (ctx.charCount > (acc.longest?.body.length ?? -1)) {
        acc.longest = message;
      }
      for (final emoji in ctx.emojis) {
        acc.emojis++;
        final key = EmojiUtils.normalize(emoji);
        acc.emojiCounts[key] = (acc.emojiCounts[key] ?? 0) + 1;
      }
    }

    if (ctx.isDoubleText) acc.doubleTexts++;
    if (ctx.startsSession) acc.conversationsStarted++;
    if (ctx.endsSession) acc.conversationsEnded++;

    if (ctx.isReply) {
      final gap = ctx.sincePrevious!;
      acc.replySeconds.add(gap.inSeconds);
    }
  }

  int get countedMessages => _countedMessages;

  List<ParticipantStats> build() {
    final total = _countedMessages == 0 ? 1 : _countedMessages;
    final stats = <ParticipantStats>[];

    // Colour index is assigned by rank, so the busiest person always gets the
    // brand green and the palette reads consistently across the app.
    final ordered = _people.values.toList()
      ..sort((a, b) => b.messages.compareTo(a.messages));

    for (var i = 0; i < ordered.length; i++) {
      final a = ordered[i];
      final replies = a.replySeconds..sort();
      stats.add(
        ParticipantStats(
          name: a.name,
          colorIndex: i,
          messageCount: a.messages,
          share: a.messages / total,
          wordCount: a.words,
          charCount: a.chars,
          emojiCount: a.emojis,
          mediaCount: a.media,
          linkCount: a.links,
          questionCount: a.questions,
          deletedCount: a.deleted,
          laughCount: a.laughs,
          doubleTexts: a.doubleTexts,
          conversationsStarted: a.conversationsStarted,
          conversationsEnded: a.conversationsEnded,
          activeDays: a.days.length,
          longestStreak: Streaks.longest(a.days),
          hourHistogram: a.hours,
          weekdayHistogram: a.weekdays,
          typeBreakdown: a.types,
          averageReply: _mean(replies),
          medianReply: _median(replies),
          fastestReply:
              replies.isEmpty ? null : Duration(seconds: replies.first),
          topEmoji: _topEmoji(a.emojiCounts),
          longestMessage: a.longest,
          firstMessageAt: a.firstAt ?? DateTime.now(),
          lastMessageAt: a.lastAt ?? DateTime.now(),
        ),
      );
    }
    return stats;
  }

  static int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  static Duration? _mean(List<int> sorted) {
    if (sorted.isEmpty) return null;
    var sum = 0;
    for (final v in sorted) {
      sum += v;
    }
    return Duration(seconds: sum ~/ sorted.length);
  }

  /// The median is what the UI leads with. Averages are wrecked by the one
  /// time somebody answered two hours and fifty-nine minutes later.
  static Duration? _median(List<int> sorted) {
    if (sorted.isEmpty) return null;
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return Duration(seconds: sorted[mid]);
    return Duration(seconds: (sorted[mid - 1] + sorted[mid]) ~/ 2);
  }

  static String? _topEmoji(Map<String, int> counts) {
    String? best;
    var bestCount = 0;
    counts.forEach((emoji, count) {
      if (count > bestCount) {
        best = emoji;
        bestCount = count;
      }
    });
    return best;
  }
}

class _Accumulator {
  _Accumulator(this.name);
  final String name;

  int messages = 0;
  int words = 0;
  int chars = 0;
  int emojis = 0;
  int media = 0;
  int links = 0;
  int questions = 0;
  int deleted = 0;
  int laughs = 0;
  int doubleTexts = 0;
  int conversationsStarted = 0;
  int conversationsEnded = 0;

  final Set<int> days = {};
  final List<int> hours = List<int>.filled(24, 0);
  final List<int> weekdays = List<int>.filled(7, 0);
  final Map<MessageType, int> types = {};
  final Map<String, int> emojiCounts = {};
  final List<int> replySeconds = [];

  ChatMessage? longest;
  DateTime? firstAt;
  DateTime? lastAt;
}
