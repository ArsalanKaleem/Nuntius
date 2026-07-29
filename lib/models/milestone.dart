enum MilestoneKind {
  firstMessage,
  messageCount,
  firstEmoji,
  firstImage,
  firstVideo,
  firstVoiceNote,
  firstLink,
  firstDocument,
  busiestDay,
  longestStreak,
  anniversary,
  lastMessage,
}

/// A dated moment worth calling out on the timeline.
class Milestone {
  const Milestone({
    required this.kind,
    required this.title,
    required this.date,
    required this.subtitle,
    this.emoji = '📍',
    this.messageIndex,
  });

  final MilestoneKind kind;
  final String title;
  final DateTime date;
  final String subtitle;
  final String emoji;

  /// Where to jump to in the message list, when the milestone points at a
  /// specific message.
  final int? messageIndex;
}
