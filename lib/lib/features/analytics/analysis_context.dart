import '../../core/constants/app_constants.dart';
import '../../core/utils/emoji_utils.dart';
import '../../core/utils/text_utils.dart';
import '../../models/chat_message.dart';

/// Per-message derived data, computed once and shared by every analyzer.
///
/// This is the reason the engine makes a single pass over the messages: word
/// splitting and emoji matching are the two expensive operations, and running
/// them once per message instead of once per analyzer is the difference
/// between a snappy import and a three-second freeze on a large chat.
class MessageContext {
  MessageContext({
    required this.message,
    required this.previous,
    required this.next,
  });

  final ChatMessage message;
  final ChatMessage? previous;
  final ChatMessage? next;

  Duration? get sincePrevious =>
      previous == null ? null : message.timestamp.difference(previous!.timestamp);

  Duration? get untilNext =>
      next == null ? null : next!.timestamp.difference(message.timestamp);

  /// First message after a long quiet period — whoever sends it restarted the
  /// conversation.
  bool get startsSession {
    final gap = sincePrevious;
    return gap == null || gap >= AnalyticsConfig.sessionGap;
  }

  /// Last message before a long quiet period.
  bool get endsSession {
    final gap = untilNext;
    return gap == null || gap >= AnalyticsConfig.sessionGap;
  }

  /// A reply is a message from a different person, close enough in time that
  /// it is plausibly a response rather than a fresh conversation.
  bool get isReply {
    final prev = previous;
    final gap = sincePrevious;
    if (prev == null || gap == null) return false;
    if (prev.sender == null || message.sender == null) return false;
    if (prev.sender == message.sender) return false;
    return gap <= AnalyticsConfig.maxReplyGap;
  }

  /// Same person, twice, with enough of a pause that it reads as a nudge
  /// rather than one thought split across two bubbles.
  bool get isDoubleText {
    final prev = previous;
    final gap = sincePrevious;
    if (prev == null || gap == null) return false;
    if (prev.sender == null || message.sender == null) return false;
    if (prev.sender != message.sender) return false;
    return gap >= AnalyticsConfig.doubleTextGap &&
        gap < AnalyticsConfig.sessionGap;
  }

  List<String>? _tokens;

  /// Lowercased word tokens. Empty for media and system lines.
  List<String> get tokens =>
      _tokens ??= message.hasText ? TextUtils.words(message.body) : const [];

  List<String>? _emojis;

  List<String> get emojis =>
      _emojis ??= message.hasText ? EmojiUtils.extract(message.body) : const [];

  int? _wordCount;

  int get wordCount =>
      _wordCount ??= message.hasText ? TextUtils.wordCount(message.body) : 0;

  int get charCount => message.hasText ? message.body.length : 0;
}
