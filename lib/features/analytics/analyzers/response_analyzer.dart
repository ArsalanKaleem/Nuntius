import '../../../models/chat_analytics.dart';
import '../../../models/participant_stats.dart';
import '../analysis_context.dart';

/// How quickly people answer each other, and whether the chat is warming up or
/// cooling down.
class ResponseAnalyzer {
  final List<int> _allReplySeconds = [];
  final List<DateTime> _timestamps = [];
  int _sessions = 0;
  DateTime? _first;
  DateTime? _last;

  void add(MessageContext ctx) {
    _first ??= ctx.message.timestamp;
    _last = ctx.message.timestamp;
    _timestamps.add(ctx.message.timestamp);
    if (ctx.startsSession) _sessions++;
    if (ctx.isReply) {
      _allReplySeconds.add(ctx.sincePrevious!.inSeconds);
    }
  }

  ResponseStats build(List<ParticipantStats> participants) {
    _allReplySeconds.sort();

    final medians = <String, Duration>{
      for (final p in participants)
        if (p.medianReply != null) p.name: p.medianReply!,
    };

    String? fastest;
    String? slowest;
    // Only rank people with a meaningful number of replies, otherwise one
    // lucky two-second answer wins the medal.
    final eligible = participants
        .where((p) => p.medianReply != null && p.messageCount >= 20)
        .toList();
    if (eligible.isNotEmpty) {
      eligible.sort((a, b) => a.medianReply!.compareTo(b.medianReply!));
      fastest = eligible.first.name;
      slowest = eligible.last.name;
      if (fastest == slowest) slowest = null;
    }

    final days = (_first != null && _last != null)
        ? _last!.difference(_first!).inDays + 1
        : 1;

    return ResponseStats(
      averageReply: _mean(_allReplySeconds),
      medianReply: _median(_allReplySeconds),
      sampleCount: _allReplySeconds.length,
      fastestResponder: fastest,
      slowestResponder: slowest,
      perParticipantMedian: medians,
      conversationsPerDay: days == 0 ? 0 : _sessions / days,
      momentum: _momentum(),
    );
  }

  /// Compares the message rate of the most recent fifth of the timeline with
  /// the rate over the preceding four fifths, normalised to -1..1.
  ///
  /// Time-based rather than count-based: splitting by message count would
  /// always return zero, since each fifth would contain a fifth of the
  /// messages by construction.
  double _momentum() {
    if (_timestamps.length < 50 || _first == null || _last == null) return 0;
    final totalMs = _last!.difference(_first!).inMilliseconds;
    if (totalMs <= 0) return 0;

    final cutoff = _first!.add(Duration(milliseconds: (totalMs * 0.8).round()));
    var recent = 0;
    for (var i = _timestamps.length - 1; i >= 0; i--) {
      if (_timestamps[i].isBefore(cutoff)) break;
      recent++;
    }
    final earlier = _timestamps.length - recent;

    final recentRate = recent / 0.2;
    final earlierRate = earlier / 0.8;
    if (recentRate + earlierRate == 0) return 0;
    return ((recentRate - earlierRate) / (recentRate + earlierRate))
        .clamp(-1.0, 1.0);
  }

  static Duration? _mean(List<int> values) {
    if (values.isEmpty) return null;
    var sum = 0;
    for (final v in values) {
      sum += v;
    }
    return Duration(seconds: sum ~/ values.length);
  }

  static Duration? _median(List<int> sorted) {
    if (sorted.isEmpty) return null;
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return Duration(seconds: sorted[mid]);
    return Duration(seconds: (sorted[mid - 1] + sorted[mid]) ~/ 2);
  }
}
