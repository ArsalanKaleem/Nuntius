import '../../../core/constants/app_constants.dart';
import '../../../core/utils/emoji_utils.dart';
import '../../../models/chat_analytics.dart';
import '../../../models/participant_stats.dart';
import '../../../models/stat_types.dart';
import '../analysis_context.dart';

class EmojiAnalyzer {
  final Map<String, int> _counts = {};
  final Map<EmojiMood, int> _moods = {
    for (final mood in EmojiMood.values) mood: 0,
  };

  int _total = 0;
  int _messagesWithEmoji = 0;
  int _messages = 0;

  void add(MessageContext ctx) {
    if (ctx.message.sender == null) return;
    _messages++;
    final emojis = ctx.emojis;
    if (emojis.isEmpty) return;

    _messagesWithEmoji++;
    for (final emoji in emojis) {
      final key = EmojiUtils.normalize(emoji);
      if (key.isEmpty) continue;
      _total++;
      _counts[key] = (_counts[key] ?? 0) + 1;
      final mood = EmojiUtils.moodOf(key);
      _moods[mood] = (_moods[mood] ?? 0) + 1;
    }
  }

  EmojiStats build(List<ParticipantStats> participants) {
    final entries = _counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return EmojiStats(
      top: [
        for (final e in entries.take(AnalyticsConfig.topEmojiCount))
          NamedValue(e.key, e.value),
      ],
      moodBreakdown: _moods,
      favoritePerPerson: {
        for (final p in participants)
          if (p.topEmoji != null) p.name: p.topEmoji!,
      },
      totalEmojis: _total,
      messagesWithEmoji: _messagesWithEmoji,
      totalMessages: _messages,
    );
  }
}
