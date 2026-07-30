/// Pure-Dart text helpers shared by the parser and the analytics engine.
/// No Flutter imports — these run inside isolates.
abstract final class TextUtils {
  static final _wordSplitter = RegExp(r"[^\p{L}\p{N}'’_-]+", unicode: true);
  static final _linkPattern = RegExp(
    r'(https?://|www\.)[^\s<>"]+',
    caseSensitive: false,
  );
  static final _mentionPattern = RegExp(r'@[\w.+-]{2,}');
  static final _hashtagPattern = RegExp(r'#[\p{L}\p{N}_]{2,}', unicode: true);
  static final _laughPattern = RegExp(
    r'\b(?:l+o+l+|lmf?ao+|h[ae](?:h[ae]){1,}|ro?fl|xd+|hehe+|jaja+)\b',
    caseSensitive: false,
  );
  static final _repeatedChars = RegExp(r'(.)\1{2,}');

  static List<String> words(String text) => text
      .toLowerCase()
      .split(_wordSplitter)
      .where((w) => w.isNotEmpty)
      .toList();

  static int wordCount(String text) {
    var count = 0;
    var inWord = false;
    for (var i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      final isSpace = c == 32 || c == 9 || c == 10 || c == 13;
      if (isSpace) {
        inWord = false;
      } else if (!inWord) {
        inWord = true;
        count++;
      }
    }
    return count;
  }

  static bool hasLink(String text) =>
      text.contains('http') || text.contains('www.');

  static Iterable<String> links(String text) =>
      _linkPattern.allMatches(text).map((m) => m.group(0)!);

  static Iterable<String> mentions(String text) =>
      _mentionPattern.allMatches(text).map((m) => m.group(0)!);

  static Iterable<String> hashtags(String text) =>
      _hashtagPattern.allMatches(text).map((m) => m.group(0)!.toLowerCase());

  static bool isQuestion(String text) => text.contains('?');

  static bool isLaughter(String text) => _laughPattern.hasMatch(text);

  static int laughterCount(String text) => _laughPattern.allMatches(text).length;

  /// "soooo" -> "soo", so stretched words collapse into one bucket.
  static String collapseRepeats(String word) =>
      word.replaceAllMapped(_repeatedChars, (m) => '${m[1]}${m[1]}');

  /// Domain of a URL, used for the "most shared sites" list.
  static String? domainOf(String url) {
    var u = url;
    final scheme = u.indexOf('://');
    if (scheme != -1) u = u.substring(scheme + 3);
    if (u.startsWith('www.')) u = u.substring(4);
    final slash = u.indexOf('/');
    if (slash != -1) u = u.substring(0, slash);
    final colon = u.indexOf(':');
    if (colon != -1) u = u.substring(0, colon);
    return u.isEmpty ? null : u.toLowerCase();
  }

  /// Bigrams and trigrams for the "most used phrases" stat.
  static Iterable<String> ngrams(List<String> tokens, int n) sync* {
    for (var i = 0; i + n <= tokens.length; i++) {
      yield tokens.sublist(i, i + n).join(' ');
    }
  }
}
