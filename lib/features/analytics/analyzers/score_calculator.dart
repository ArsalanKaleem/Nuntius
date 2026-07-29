import 'dart:math' as math;

import '../../../models/chat_analytics.dart';
import '../../../models/participant_stats.dart';

/// Turns raw statistics into the four 0–100 scores the app displays.
///
/// These are opinions, not measurements, so the formulas are written out here
/// rather than buried: anyone can read what "friendship score 82" was built
/// from and disagree with the weighting.
abstract final class ScoreCalculator {
  static Scores build({
    required List<ParticipantStats> participants,
    required ConversationStats conversation,
    required ActivityStats activity,
    required ResponseStats response,
    required EmojiStats emoji,
  }) {
    final balance = _balance(participants);
    final consistency = _consistency(conversation);
    final responsiveness = _responsiveness(response);
    final warmth = _warmth(participants, emoji, conversation);
    final volume = _volume(conversation.totalMessages);

    final friendship = (consistency * 0.30 +
            balance * 0.25 +
            responsiveness * 0.20 +
            warmth * 0.15 +
            volume * 0.10)
        .clamp(0.0, 100.0);

    return Scores(
      friendship: friendship,
      balance: balance,
      consistency: consistency,
      responsiveness: responsiveness,
      warmth: warmth,
    );
  }

  /// Normalised Shannon entropy of the message shares.
  ///
  /// A 50/50 two-person chat scores 100; 90/10 scores about 47. Entropy is
  /// used instead of the simpler "100 minus the gap" because it generalises
  /// to group chats of any size without a special case.
  static double _balance(List<ParticipantStats> participants) {
    final shares = participants
        .map((p) => p.share)
        .where((s) => s > 0)
        .toList();
    if (shares.length < 2) return 0;

    var entropy = 0.0;
    for (final share in shares) {
      entropy -= share * (math.log(share) / math.ln2);
    }
    final maxEntropy = math.log(shares.length) / math.ln2;
    if (maxEntropy == 0) return 100;
    return (entropy / maxEntropy * 100).clamp(0.0, 100.0);
  }

  /// Share of calendar days with at least one message, curved so that chats do
  /// not need to be literally daily to score well.
  static double _consistency(ConversationStats conversation) {
    if (conversation.totalDays == 0) return 0;
    final ratio = conversation.activeDays / conversation.totalDays;
    return (math.sqrt(ratio) * 100).clamp(0.0, 100.0);
  }

  /// Decays with the median reply time: instant is 100, 20 minutes is 50,
  /// an hour is 25.
  static double _responsiveness(ResponseStats response) {
    final median = response.medianReply;
    if (median == null || response.sampleCount < 5) return 50;
    final minutes = median.inSeconds / 60.0;
    return (100 / (1 + minutes / 20)).clamp(0.0, 100.0);
  }

  /// Emoji, laughter and affectionate language, per message.
  static double _warmth(
    List<ParticipantStats> participants,
    EmojiStats emoji,
    ConversationStats conversation,
  ) {
    if (conversation.totalMessages == 0) return 0;
    var laughs = 0;
    for (final p in participants) {
      laughs += p.laughCount;
    }
    final emojiRate = emoji.emojiRate; // 0..1
    final laughRate = (laughs / conversation.totalMessages).clamp(0.0, 1.0);
    // Half the score from emoji use, half from laughter, both saturating well
    // before every message needs one.
    final score = (emojiRate / 0.35).clamp(0.0, 1.0) * 50 +
        (laughRate / 0.15).clamp(0.0, 1.0) * 50;
    return score.clamp(0.0, 100.0);
  }

  /// Log-scaled so a 500-message chat is not written off next to a 50,000
  /// message one.
  static double _volume(int totalMessages) {
    if (totalMessages <= 0) return 0;
    final score = math.log(totalMessages) / math.log(50000) * 100;
    return score.clamp(0.0, 100.0);
  }
}
