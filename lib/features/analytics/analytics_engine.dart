import '../../core/extensions/extensions.dart';
import '../../models/chat_analytics.dart';
import '../../models/chat_message.dart';
import '../../models/parsed_chat.dart';
import 'analysis_context.dart';
import 'analyzers/achievement_builder.dart';
import 'analyzers/activity_analyzer.dart';
import 'analyzers/award_builder.dart';
import 'analyzers/emoji_analyzer.dart';
import 'analyzers/insight_generator.dart';
import 'analyzers/language_analyzer.dart';
import 'analyzers/milestone_analyzer.dart';
import 'analyzers/participant_analyzer.dart';
import 'analyzers/response_analyzer.dart';
import 'analyzers/score_calculator.dart';

/// Turns a [ParsedChat] into a [ChatAnalytics].
///
/// Architecture note: every per-message analyzer is fed from a single loop.
/// Each analyzer owns its accumulators and exposes `add` / `build`, so adding a
/// new statistic means adding one class and one line here — no extra pass over
/// the messages, which is what keeps a 250,000-message chat under a couple of
/// seconds.
///
/// Nothing in this file or its analyzers touches Flutter, the filesystem or the
/// network, so the whole engine runs unchanged inside an isolate and in tests.
class AnalyticsEngine {
  const AnalyticsEngine();

  ChatAnalytics analyze(
    ParsedChat chat, {
    void Function(double progress)? onProgress,
  }) {
    final messages = chat.messages;
    if (messages.isEmpty) {
      throw StateError('Cannot analyse an empty chat.');
    }

    final participantAnalyzer = ParticipantAnalyzer();
    final activityAnalyzer = ActivityAnalyzer();
    final responseAnalyzer = ResponseAnalyzer();
    final languageAnalyzer = LanguageAnalyzer();
    final emojiAnalyzer = EmojiAnalyzer();
    final milestoneAnalyzer = MilestoneAnalyzer();

    var totalWords = 0;
    var totalChars = 0;
    var systemMessages = 0;
    final typeBreakdown = <MessageType, int>{};
    final activeDays = <int>{};

    // Split once: system lines are metadata, not conversation, and letting
    // them sit in the middle of the sequence would break reply timing (an
    // encryption notice is not somebody answering you).
    final counted = <ChatMessage>[];
    for (final message in messages) {
      typeBreakdown[message.type] = (typeBreakdown[message.type] ?? 0) + 1;
      if (message.isSystem) {
        systemMessages++;
      } else {
        counted.add(message);
      }
    }

    final progressEvery = (counted.length / 100).ceil().clamp(1, 1 << 30);

    // The one pass.
    for (var i = 0; i < counted.length; i++) {
      final message = counted[i];
      if (onProgress != null && i % progressEvery == 0) {
        onProgress(i / counted.length);
      }

      final ctx = MessageContext(
        message: message,
        previous: i == 0 ? null : counted[i - 1],
        next: i == counted.length - 1 ? null : counted[i + 1],
      );

      totalWords += ctx.wordCount;
      totalChars += ctx.charCount;
      activeDays.add(message.timestamp.dayKey);

      participantAnalyzer.add(ctx);
      activityAnalyzer.add(ctx);
      responseAnalyzer.add(ctx);
      languageAnalyzer.add(ctx);
      emojiAnalyzer.add(ctx);
      milestoneAnalyzer.add(ctx);
    }
    onProgress?.call(1);

    // Dates come from real messages, so a trailing "you were removed" notice
    // does not stretch the reported date range.
    final firstAt = counted.isEmpty
        ? messages.first.timestamp
        : counted.first.timestamp;
    final lastAt =
        counted.isEmpty ? messages.last.timestamp : counted.last.timestamp;

    final conversation = ConversationStats(
      totalMessages: participantAnalyzer.countedMessages,
      systemMessages: systemMessages,
      totalWords: totalWords,
      totalCharacters: totalChars,
      firstAt: firstAt,
      lastAt: lastAt,
      totalDays: lastAt.dateOnly.difference(firstAt.dateOnly).inDays + 1,
      activeDays: activeDays.length,
      typeBreakdown: typeBreakdown,
    );

    final participants = participantAnalyzer.build();
    final activity = activityAnalyzer.build();
    final response = responseAnalyzer.build(participants);
    final language = languageAnalyzer.build();
    final emoji = emojiAnalyzer.build(participants);

    final scores = ScoreCalculator.build(
      participants: participants,
      conversation: conversation,
      activity: activity,
      response: response,
      emoji: emoji,
    );

    return ChatAnalytics(
      chatTitle: titleFor(chat),
      participants: participants,
      isGroupChat: chat.isGroupChat,
      conversation: conversation,
      activity: activity,
      response: response,
      language: language,
      emoji: emoji,
      scores: scores,
      awards: AwardBuilder.build(
        participants: participants,
        activity: activity,
        response: response,
        emoji: emoji,
      ),
      milestones: milestoneAnalyzer.build(activity),
      insights: InsightGenerator.build(
        participants: participants,
        conversation: conversation,
        activity: activity,
        response: response,
        language: language,
        emoji: emoji,
        scores: scores,
        isGroupChat: chat.isGroupChat,
      ),
      achievements: AchievementBuilder.build(
        participants: participants,
        conversation: conversation,
        activity: activity,
        response: response,
        emoji: emoji,
        scores: scores,
      ),
      generatedAt: DateTime.now(),
    );
  }

  /// WhatsApp names exports "WhatsApp Chat with Sara.txt" (or the group name),
  /// which is a better title than anything we could infer from the messages.
  static String titleFor(ParsedChat chat) {
    final name = chat.sourceName;
    final withoutExtension =
        name.endsWith('.txt') ? name.substring(0, name.length - 4) : name;
    final match = RegExp(
      r'^(?:whatsapp )?chat (?:with|mit|con|avec|com) (.+)$',
      caseSensitive: false,
    ).firstMatch(withoutExtension.trim());
    if (match != null) return match.group(1)!.trim();

    if (withoutExtension.trim().isNotEmpty &&
        withoutExtension.toLowerCase() != 'chat') {
      return withoutExtension.trim();
    }
    if (chat.participants.length <= 3) return chat.participants.join(' & ');
    return '${chat.participants.first} + ${chat.participants.length - 1} others';
  }
}
