/// Emoji detection and mood classification.
///
/// Kept dependency-free and regex-based so it can run inside a parsing isolate
/// with no Flutter bindings.
abstract final class EmojiUtils {
  static final RegExp pattern = RegExp(
    // keycaps (1️⃣) — matched first so the digit is not dropped
    r'(?:[0-9#*]\uFE0F?\u20E3)'
    // regional indicator pairs (flags)
    r'|(?:[\u{1F1E6}-\u{1F1FF}]{2})'
    // main pictographic ranges, plus modifiers and ZWJ sequences
    r'|(?:[\u{1F300}-\u{1FAFF}\u{1F004}\u{1F0CF}\u{2600}-\u{27BF}'
    r'\u{2B00}-\u{2BFF}\u{2934}\u{2935}\u{3030}\u{303D}\u{3297}\u{3299}'
    r'\u{00A9}\u{00AE}\u{203C}\u{2049}\u{2122}\u{2139}\u{2194}-\u{21AA}'
    r'\u{231A}\u{231B}\u{2328}\u{23CF}-\u{23FA}\u{24C2}\u{25AA}-\u{25FE}]'
    r'\uFE0F?[\u{1F3FB}-\u{1F3FF}]?'
    r'(?:\u200D[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]\uFE0F?[\u{1F3FB}-\u{1F3FF}]?)*)',
    unicode: true,
  );

  /// Fast pre-check: skip the regex entirely for plain ASCII messages, which is
  /// most of a large chat. Saves a lot of time on 250k-message exports.
  static bool mightContainEmoji(String text) {
    for (var i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) > 0x2000) return true;
    }
    return false;
  }

  static List<String> extract(String text) {
    if (!mightContainEmoji(text)) return const [];
    return pattern.allMatches(text).map((m) => m.group(0)!).toList();
  }

  static int count(String text) {
    if (!mightContainEmoji(text)) return 0;
    return pattern.allMatches(text).length;
  }

  /// Strips skin-tone and variation modifiers so 👍🏽 and 👍 are one entry.
  /// Removes every emoji from [text].
  ///
  /// Used by the PDF report when no emoji-capable font is bundled: dropping the
  /// characters gives clean prose, whereas leaving them in gives a row of empty
  /// tofu boxes.
  static String strip(String text) {
    if (!mightContainEmoji(text)) return text;
    return text
        .replaceAll(pattern, '')
        .replaceAll(RegExp(r'  +'), ' ')
        .trim();
  }

  static String normalize(String emoji) => emoji
      .replaceAll(RegExp(r'[\u{1F3FB}-\u{1F3FF}]', unicode: true), '')
      .replaceAll('\uFE0F', '');

  static const _love = {
    '❤', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💕', '💞', '💓',
    '💗', '💖', '💘', '💝', '😍', '🥰', '😘', '😻', '💑', '💏', '👩‍❤️‍👨',
  };

  static const _funny = {
    '😂', '🤣', '😹', '😆', '😅', '😜', '😝', '🤪', '😛', '🙃', '💀', '☠',
  };

  static const _positive = {
    '😊', '😁', '😃', '😄', '🙂', '😌', '👍', '🙌', '👏', '🎉', '🥳', '✨',
    '🔥', '💯', '🤩', '😎', '🥹', '🫶', '🙏', '✅', '💪', '🌟', '☺',
  };

  static const _negative = {
    '😢', '😭', '😞', '😔', '😟', '😩', '😫', '😤', '😡', '🤬', '👎', '💔',
    '😰', '😨', '😱', '🙄', '😒', '😕', '🥲', '😬', '❌',
  };

  static EmojiMood moodOf(String emoji) {
    final e = normalize(emoji);
    if (_love.contains(e)) return EmojiMood.love;
    if (_funny.contains(e)) return EmojiMood.funny;
    if (_positive.contains(e)) return EmojiMood.positive;
    if (_negative.contains(e)) return EmojiMood.negative;
    return EmojiMood.neutral;
  }
}

enum EmojiMood {
  love('Love', '💚'),
  funny('Funny', '😂'),
  positive('Positive', '✨'),
  negative('Negative', '💔'),
  neutral('Neutral', '💬');

  const EmojiMood(this.label, this.icon);
  final String label;
  final String icon;
}
