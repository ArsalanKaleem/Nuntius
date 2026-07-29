import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/text_utils.dart';
import '../../../models/chat_analytics.dart';
import '../../../models/chat_message.dart';
import '../../../models/milestone.dart';
import '../analysis_context.dart';

/// Collects "firsts" and counted milestones as the pass goes by, then adds the
/// milestones that can only be known once the whole chat has been read.
class MilestoneAnalyzer {
  final List<Milestone> _milestones = [];
  final Set<MilestoneKind> _seen = {};
  int _counted = 0;
  int _nextMilestoneIndex = 0;
  ChatMessage? _first;
  ChatMessage? _last;

  void add(MessageContext ctx) {
    final message = ctx.message;
    if (message.sender == null) return;

    _first ??= message;
    _last = message;
    _counted++;

    // Counted milestones — 1,000th message and friends.
    while (_nextMilestoneIndex < AnalyticsConfig.messageMilestones.length &&
        _counted == AnalyticsConfig.messageMilestones[_nextMilestoneIndex]) {
      final target = AnalyticsConfig.messageMilestones[_nextMilestoneIndex];
      _milestones.add(
        Milestone(
          kind: MilestoneKind.messageCount,
          title: '${Fmt.n(target)} messages',
          date: message.timestamp,
          subtitle: '${message.sender} sent the ${Fmt.ordinal(target)} message',
          emoji: '💬',
          messageIndex: message.index,
        ),
      );
      _nextMilestoneIndex++;
    }

    void once(MilestoneKind kind, String title, String emoji) {
      if (_seen.add(kind)) {
        _milestones.add(
          Milestone(
            kind: kind,
            title: title,
            date: message.timestamp,
            subtitle: 'Sent by ${message.sender}',
            emoji: emoji,
            messageIndex: message.index,
          ),
        );
      }
    }

    switch (message.type) {
      case MessageType.image:
        once(MilestoneKind.firstImage, 'First photo', '📸');
      case MessageType.video:
        once(MilestoneKind.firstVideo, 'First video', '🎬');
      case MessageType.voiceNote:
        once(MilestoneKind.firstVoiceNote, 'First voice note', '🎙️');
      case MessageType.document:
        once(MilestoneKind.firstDocument, 'First document', '📄');
      default:
        break;
    }

    if (message.hasText) {
      if (ctx.emojis.isNotEmpty && !_seen.contains(MilestoneKind.firstEmoji)) {
        final emoji = ctx.emojis.first;
        _seen.add(MilestoneKind.firstEmoji);
        _milestones.add(
          Milestone(
            kind: MilestoneKind.firstEmoji,
            title: 'First emoji',
            date: message.timestamp,
            subtitle: '${message.sender} sent $emoji',
            emoji: emoji,
            messageIndex: message.index,
          ),
        );
      }
      if (TextUtils.hasLink(message.body)) {
        once(MilestoneKind.firstLink, 'First link', '🔗');
      }
    }
  }

  List<Milestone> build(ActivityStats activity) {
    final all = <Milestone>[..._milestones];

    final first = _first;
    if (first != null) {
      all.add(
        Milestone(
          kind: MilestoneKind.firstMessage,
          title: 'It started here',
          date: first.timestamp,
          subtitle: '${first.sender} sent the first message',
          emoji: '🌱',
          messageIndex: first.index,
        ),
      );

      // Yearly anniversaries of the first message, up to the last message.
      final last = _last;
      if (last != null) {
        var year = first.timestamp.year + 1;
        while (DateTime(year, first.timestamp.month, first.timestamp.day)
            .isBefore(last.timestamp)) {
          final date =
              DateTime(year, first.timestamp.month, first.timestamp.day);
          final years = year - first.timestamp.year;
          all.add(
            Milestone(
              kind: MilestoneKind.anniversary,
              title: '$years ${years == 1 ? "year" : "years"} of talking',
              date: date,
              subtitle: 'Since ${first.timestamp.shortDate}',
              emoji: '🎂',
            ),
          );
          year++;
        }
      }
    }

    if (activity.busiestDay.count > 0) {
      all.add(
        Milestone(
          kind: MilestoneKind.busiestDay,
          title: 'Busiest day',
          date: activity.busiestDay.date,
          subtitle:
              '${Fmt.n(activity.busiestDay.count)} messages in a single day',
          emoji: '🔥',
        ),
      );
    }

    final streak = activity.longestStreak;
    if (streak.exists && streak.days >= 3) {
      all.add(
        Milestone(
          kind: MilestoneKind.longestStreak,
          title: '${streak.days}-day streak',
          date: streak.end!,
          subtitle: 'From ${streak.start!.shortDate}',
          emoji: '⚡',
        ),
      );
    }

    final last = _last;
    if (last != null) {
      all.add(
        Milestone(
          kind: MilestoneKind.lastMessage,
          title: 'Most recent message',
          date: last.timestamp,
          subtitle: 'From ${last.sender}',
          emoji: '📍',
          messageIndex: last.index,
        ),
      );
    }

    all.sort((a, b) => a.date.compareTo(b.date));
    return all;
  }
}
