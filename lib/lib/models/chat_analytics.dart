import '../core/utils/emoji_utils.dart';
import 'achievement.dart';
import 'chat_message.dart';
import 'insight.dart';
import 'milestone.dart';
import 'participant_stats.dart';
import 'stat_types.dart';

class ConversationStats {
  const ConversationStats({
    required this.totalMessages,
    required this.systemMessages,
    required this.totalWords,
    required this.totalCharacters,
    required this.firstAt,
    required this.lastAt,
    required this.totalDays,
    required this.activeDays,
    required this.typeBreakdown,
  });

  final int totalMessages;
  final int systemMessages;
  final int totalWords;
  final int totalCharacters;
  final DateTime firstAt;
  final DateTime lastAt;

  /// Calendar days from first to last message, inclusive.
  final int totalDays;

  /// Days that actually contain at least one message.
  final int activeDays;
  final Map<MessageType, int> typeBreakdown;

  double get messagesPerDay => totalDays == 0 ? 0 : totalMessages / totalDays;

  double get messagesPerActiveDay =>
      activeDays == 0 ? 0 : totalMessages / activeDays;

  double get wordsPerMessage =>
      totalMessages == 0 ? 0 : totalWords / totalMessages;

  int get silentDays => (totalDays - activeDays).clamp(0, totalDays);

  Duration get span => lastAt.difference(firstAt);
}

class ActivityStats {
  const ActivityStats({
    required this.hourHistogram,
    required this.weekdayHistogram,
    required this.monthHistogram,
    required this.perDay,
    required this.monthlyTrend,
    required this.yearlyTrend,
    required this.busiestDay,
    required this.busiestHour,
    required this.busiestWeekday,
    required this.busiestMonth,
    required this.longestStreak,
    required this.currentStreak,
    required this.longestSilence,
    required this.longestSilenceStart,
  });

  /// 24 buckets, local time.
  final List<int> hourHistogram;

  /// 7 buckets, Monday first.
  final List<int> weekdayHistogram;

  /// 12 buckets, January first — aggregated across all years.
  final List<int> monthHistogram;

  /// Day key (yyyymmdd as int) -> message count. Backs the calendar heatmap.
  final Map<int, int> perDay;

  /// Chronological month-by-month counts for the relationship timeline.
  final List<TimelinePoint> monthlyTrend;
  final List<TimelinePoint> yearlyTrend;

  final DateCount busiestDay;

  /// 0..23
  final int busiestHour;

  /// 1..7 (DateTime.monday == 1)
  final int busiestWeekday;

  /// 1..12
  final int busiestMonth;

  final Streak longestStreak;
  final Streak currentStreak;
  final Duration longestSilence;
  final DateTime? longestSilenceStart;

  int get peakDayCount => busiestDay.count;
}

class ResponseStats {
  const ResponseStats({
    required this.averageReply,
    required this.medianReply,
    required this.sampleCount,
    required this.fastestResponder,
    required this.slowestResponder,
    required this.perParticipantMedian,
    required this.conversationsPerDay,
    required this.momentum,
  });

  final Duration? averageReply;
  final Duration? medianReply;

  /// How many reply pairs fell inside the reply window. Small samples make the
  /// averages unreliable, and the UI says so when this is low.
  final int sampleCount;

  final String? fastestResponder;
  final String? slowestResponder;
  final Map<String, Duration> perParticipantMedian;
  final double conversationsPerDay;

  /// -1..1 — negative means the chat is cooling off compared with its own
  /// history, positive means it is heating up. Compares the last 20% of the
  /// timeline against the preceding 80%.
  final double momentum;

  bool get isReliable => sampleCount >= 30;
}

class LanguageStats {
  const LanguageStats({
    required this.topWords,
    required this.topPhrases,
    required this.topHashtags,
    required this.topMentions,
    required this.topDomains,
    required this.uniqueWords,
    required this.totalWords,
    required this.questionCount,
    required this.linkCount,
    required this.longestMessage,
    required this.shortestMessage,
  });

  final List<NamedValue> topWords;
  final List<NamedValue> topPhrases;
  final List<NamedValue> topHashtags;
  final List<NamedValue> topMentions;
  final List<NamedValue> topDomains;
  final int uniqueWords;
  final int totalWords;
  final int questionCount;
  final int linkCount;
  final ChatMessage? longestMessage;
  final ChatMessage? shortestMessage;

  /// Type-token ratio. Higher means a more varied vocabulary.
  double get vocabularyRichness =>
      totalWords == 0 ? 0 : uniqueWords / totalWords;
}

class EmojiStats {
  const EmojiStats({
    required this.top,
    required this.moodBreakdown,
    required this.favoritePerPerson,
    required this.totalEmojis,
    required this.messagesWithEmoji,
    required this.totalMessages,
  });

  final List<NamedValue> top;
  final Map<EmojiMood, int> moodBreakdown;
  final Map<String, String> favoritePerPerson;
  final int totalEmojis;
  final int messagesWithEmoji;
  final int totalMessages;

  String? get favorite => top.isEmpty ? null : top.first.name;

  double get emojiRate =>
      totalMessages == 0 ? 0 : messagesWithEmoji / totalMessages;

  /// The mood that shows up most, ignoring neutral.
  EmojiMood get dominantMood {
    EmojiMood best = EmojiMood.neutral;
    var bestCount = -1;
    moodBreakdown.forEach((mood, count) {
      if (mood != EmojiMood.neutral && count > bestCount) {
        best = mood;
        bestCount = count;
      }
    });
    return best;
  }
}

class Scores {
  const Scores({
    required this.friendship,
    required this.balance,
    required this.consistency,
    required this.responsiveness,
    required this.warmth,
  });

  /// All 0..100.
  final double friendship;
  final double balance;
  final double consistency;
  final double responsiveness;
  final double warmth;

  String get friendshipGrade {
    if (friendship >= 90) return 'Legendary';
    if (friendship >= 78) return 'Inseparable';
    if (friendship >= 64) return 'Close';
    if (friendship >= 48) return 'Steady';
    if (friendship >= 32) return 'Casual';
    return 'Distant';
  }
}

/// The complete analysis of one chat. Everything the dashboard, Wrapped and PDF
/// need — produced once, in an isolate, then held in memory for the session.
class ChatAnalytics {
  const ChatAnalytics({
    required this.chatTitle,
    required this.participants,
    required this.isGroupChat,
    required this.conversation,
    required this.activity,
    required this.response,
    required this.language,
    required this.emoji,
    required this.scores,
    required this.awards,
    required this.milestones,
    required this.insights,
    required this.achievements,
    required this.generatedAt,
  });

  final String chatTitle;
  final List<ParticipantStats> participants;
  final bool isGroupChat;
  final ConversationStats conversation;
  final ActivityStats activity;
  final ResponseStats response;
  final LanguageStats language;
  final EmojiStats emoji;
  final Scores scores;
  final List<Award> awards;
  final List<Milestone> milestones;
  final List<Insight> insights;
  final List<Achievement> achievements;
  final DateTime generatedAt;

  ParticipantStats? get topTalker =>
      participants.isEmpty ? null : participants.first;

  ParticipantStats? byName(String name) {
    for (final p in participants) {
      if (p.name == name) return p;
    }
    return null;
  }

  Award? award(String title) {
    for (final a in awards) {
      if (a.title == title) return a;
    }
    return null;
  }
}
