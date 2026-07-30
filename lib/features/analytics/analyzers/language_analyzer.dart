import '../../../core/constants/app_constants.dart';
import '../../../core/utils/stopwords.dart';
import '../../../core/utils/text_utils.dart';
import '../../../models/chat_analytics.dart';
import '../../../models/chat_message.dart';
import '../../../models/stat_types.dart';
import '../analysis_context.dart';

/// Words, phrases, links and the two extreme messages.
class LanguageAnalyzer {
  final Map<String, int> _words = {};
  final Map<String, int> _phrases = {};
  final Map<String, int> _hashtags = {};
  final Map<String, int> _mentions = {};
  final Map<String, int> _domains = {};

  int _totalWords = 0;
  int _questions = 0;
  int _links = 0;

  ChatMessage? _longest;
  ChatMessage? _shortest;

  /// Guard against a pathological chat blowing up memory. Well above what a
  /// real conversation produces, but bounded.
  static const _maxTrackedKeys = 250000;

  void add(MessageContext ctx) {
    final message = ctx.message;
    if (!message.hasText) return;

    final body = message.body;
    if (TextUtils.isQuestion(body)) _questions++;

    if (TextUtils.hasLink(body)) {
      for (final url in TextUtils.links(body)) {
        _links++;
        final domain = TextUtils.domainOf(url);
        if (domain != null) _bump(_domains, domain);
      }
    }

    for (final tag in TextUtils.hashtags(body)) {
      _bump(_hashtags, tag);
    }
    for (final mention in TextUtils.mentions(body)) {
      _bump(_mentions, mention.toLowerCase());
    }

    final tokens = ctx.tokens;
    _totalWords += tokens.length;

    final meaningful = <String>[];
    for (final raw in tokens) {
      final word = TextUtils.collapseRepeats(raw);
      if (word.length < AnalyticsConfig.minWordLength) continue;
      if (Stopwords.contains(word)) continue;
      // Skip pure numbers — dates and prices are not vocabulary.
      if (int.tryParse(word) != null) continue;
      _bump(_words, word);
      meaningful.add(word);
    }

    if (meaningful.length >= 2) {
      for (final phrase in TextUtils.ngrams(meaningful, 2)) {
        _bump(_phrases, phrase);
      }
    }

    final length = body.length;
    if (length > (_longest?.body.length ?? -1)) _longest = message;
    if (length > 0 && length < (_shortest?.body.length ?? 1 << 30)) {
      _shortest = message;
    }
  }

  LanguageStats build() => LanguageStats(
        topWords: _top(_words, AnalyticsConfig.topWordCount),
        // Phrases need to appear more than twice before they mean anything.
        topPhrases: _top(_phrases, AnalyticsConfig.topPhraseCount, minCount: 3),
        topHashtags: _top(_hashtags, 12),
        topMentions: _top(_mentions, 12),
        topDomains: _top(_domains, 12),
        uniqueWords: _words.length,
        totalWords: _totalWords,
        questionCount: _questions,
        linkCount: _links,
        longestMessage: _longest,
        shortestMessage: _shortest,
      );

  void _bump(Map<String, int> map, String key) {
    if (map.length >= _maxTrackedKeys && !map.containsKey(key)) return;
    map[key] = (map[key] ?? 0) + 1;
  }

  static List<NamedValue> _top(Map<String, int> map, int n, {int minCount = 1}) {
    final entries = map.entries.where((e) => e.value >= minCount).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final e in entries.take(n)) NamedValue(e.key, e.value),
    ];
  }
}
