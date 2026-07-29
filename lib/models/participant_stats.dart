import 'chat_message.dart';
import 'stat_types.dart';

/// Everything the engine knows about one person in the chat.
class ParticipantStats {
  const ParticipantStats({
    required this.name,
    required this.colorIndex,
    required this.messageCount,
    required this.share,
    required this.wordCount,
    required this.charCount,
    required this.emojiCount,
    required this.mediaCount,
    required this.linkCount,
    required this.questionCount,
    required this.deletedCount,
    required this.laughCount,
    required this.doubleTexts,
    required this.conversationsStarted,
    required this.conversationsEnded,
    required this.activeDays,
    required this.longestStreak,
    required this.hourHistogram,
    required this.weekdayHistogram,
    required this.typeBreakdown,
    required this.averageReply,
    required this.medianReply,
    required this.fastestReply,
    required this.topEmoji,
    required this.longestMessage,
    required this.firstMessageAt,
    required this.lastMessageAt,
  });

  final String name;

  /// Index into AppColors.participantPalette — fixed for the whole session so
  /// a person is the same colour in every chart, card and PDF page.
  final int colorIndex;

  final int messageCount;

  /// 0..1 of all non-system messages.
  final double share;

  final int wordCount;
  final int charCount;
  final int emojiCount;
  final int mediaCount;
  final int linkCount;
  final int questionCount;
  final int deletedCount;
  final int laughCount;
  final int doubleTexts;
  final int conversationsStarted;
  final int conversationsEnded;
  final int activeDays;
  final Streak longestStreak;

  /// 24 buckets, local time.
  final List<int> hourHistogram;

  /// 7 buckets, Monday first.
  final List<int> weekdayHistogram;

  final Map<MessageType, int> typeBreakdown;

  /// `null` when this person never replied inside the reply window (e.g. a
  /// broadcast-only account).
  final Duration? averageReply;
  final Duration? medianReply;
  final Duration? fastestReply;

  final String? topEmoji;
  final ChatMessage? longestMessage;
  final DateTime firstMessageAt;
  final DateTime lastMessageAt;

  double get averageMessageLength =>
      messageCount == 0 ? 0 : charCount / messageCount;

  double get averageWordsPerMessage =>
      messageCount == 0 ? 0 : wordCount / messageCount;

  double get emojisPerMessage =>
      messageCount == 0 ? 0 : emojiCount / messageCount;

  /// Share of this person's messages sent between midnight and 5am.
  double get nightShare {
    if (messageCount == 0) return 0;
    var night = 0;
    for (var h = 0; h < 5; h++) {
      night += hourHistogram[h];
    }
    return night / messageCount;
  }

  /// Share sent between 5am and 9am.
  double get morningShare {
    if (messageCount == 0) return 0;
    var morning = 0;
    for (var h = 5; h < 9; h++) {
      morning += hourHistogram[h];
    }
    return morning / messageCount;
  }

  double get weekendShare {
    if (messageCount == 0) return 0;
    final weekend = weekdayHistogram[5] + weekdayHistogram[6];
    return weekend / messageCount;
  }

  /// A one-line "typing personality" derived from message shape, used on the
  /// participant cards. Ordered so the most distinctive trait wins.
  String get typingPersonality {
    if (averageWordsPerMessage >= 25) return 'Essayist';
    if (averageWordsPerMessage <= 3.5) return 'Rapid-fire';
    if (emojisPerMessage >= 0.8) return 'Emoji-forward';
    if (messageCount > 0 && questionCount / messageCount >= 0.3) {
      return 'Interviewer';
    }
    if (messageCount > 0 && mediaCount / messageCount >= 0.25) {
      return 'Media sharer';
    }
    if (messageCount > 0 && laughCount / messageCount >= 0.2) {
      return 'Comedian';
    }
    if (averageWordsPerMessage >= 12) return 'Storyteller';
    return 'Steady talker';
  }
}
