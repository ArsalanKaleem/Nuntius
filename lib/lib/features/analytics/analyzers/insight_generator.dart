import '../../../core/extensions/extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/chat_analytics.dart';
import '../../../models/insight.dart';
import '../../../models/participant_stats.dart';

/// Writes the one-line observations that appear on the dashboard and Wrapped.
///
/// Every line is produced by a threshold crossing on a real statistic. There is
/// no model, no network call and no randomness — the same chat always produces
/// the same lines, which is what makes them feel like the app actually read the
/// conversation rather than generated flattery.
///
/// More lines are generated than are shown; [Insight.weight] decides which ones
/// surface. Weight is highest for the statistics that are unusual, not the ones
/// that are large.
abstract final class InsightGenerator {
  static List<Insight> build({
    required List<ParticipantStats> participants,
    required ConversationStats conversation,
    required ActivityStats activity,
    required ResponseStats response,
    required LanguageStats language,
    required EmojiStats emoji,
    required Scores scores,
    required bool isGroupChat,
  }) {
    final out = <Insight>[];

    void say(
      String text,
      String emojiIcon,
      InsightTone tone, {
      double weight = 1,
      String? detail,
    }) {
      out.add(
        Insight(
          text: text,
          emoji: emojiIcon,
          tone: tone,
          weight: weight,
          detail: detail,
        ),
      );
    }

    // --- Streaks and consistency -----------------------------------------
    final streak = activity.longestStreak;
    if (streak.exists && streak.days >= 7) {
      say(
        'You talked every single day for ${streak.days} days straight.',
        '🔥',
        InsightTone.celebratory,
        weight: 3 + streak.days / 30,
        detail: '${streak.start!.shortDate} – ${streak.end!.shortDate}',
      );
    }

    if (conversation.totalDays > 60) {
      final ratio = conversation.activeDays / conversation.totalDays;
      if (ratio > 0.8) {
        say(
          'You have spoken on ${Fmt.percent(ratio, decimals: 0)} of the days '
          'since this chat began.',
          '📆',
          InsightTone.warm,
          weight: 3.5,
        );
      } else if (ratio < 0.15) {
        say(
          'This chat only wakes up on ${Fmt.percent(ratio, decimals: 0)} of '
          'days — a burst here, silence there.',
          '🌙',
          InsightTone.curious,
          weight: 2,
        );
      }
    }

    // --- Response times ---------------------------------------------------
    final median = response.medianReply;
    if (median != null && response.isReliable) {
      if (median.inMinutes < 3) {
        say(
          'Replies land in about ${median.humanized}. Nobody here is left '
          'waiting.',
          '⚡',
          InsightTone.celebratory,
          weight: 3.2,
        );
      } else if (median.inMinutes > 45) {
        say(
          'The typical reply takes ${median.humanized}. This is a slow-burn '
          'kind of chat.',
          '🐢',
          InsightTone.playful,
          weight: 2.4,
        );
      }
    }

    if (response.slowestResponder != null &&
        response.fastestResponder != null &&
        response.perParticipantMedian.length > 1) {
      final fast = response.perParticipantMedian[response.fastestResponder]!;
      final slow = response.perParticipantMedian[response.slowestResponder]!;
      if (slow.inSeconds > fast.inSeconds * 4 && fast.inSeconds > 0) {
        say(
          '${response.fastestResponder} replies about '
          '${(slow.inSeconds / fast.inSeconds).round()}× faster than '
          '${response.slowestResponder}.',
          '🏃',
          InsightTone.playful,
          weight: 2.8,
        );
      }
    }

    // --- Time of day ------------------------------------------------------
    final hour = activity.busiestHour;
    if (hour >= 0 && hour <= 4) {
      say(
        'Most of this conversation happens after midnight.',
        '🌃',
        InsightTone.playful,
        weight: 3,
        detail: 'Peak hour: ${Fmt.hourRange(hour)}',
      );
    } else if (hour >= 5 && hour <= 8) {
      say(
        'You are both morning people — ${Fmt.hourRange(hour)} is your busiest '
        'hour.',
        '🌅',
        InsightTone.warm,
        weight: 2.5,
      );
    } else {
      say(
        '${Fmt.hourRange(hour)} is when this chat comes alive.',
        '🕰️',
        InsightTone.factual,
        weight: 1.4,
      );
    }

    // --- Balance ----------------------------------------------------------
    if (participants.length >= 2) {
      final top = participants.first;
      if (top.share > 0.65) {
        say(
          '${top.name} sends ${Fmt.percent(top.share, decimals: 0)} of the '
          'messages here. Somebody is doing the heavy lifting.',
          '📣',
          InsightTone.playful,
          weight: 3.1,
        );
      } else if (scores.balance > 92 && !isGroupChat) {
        say(
          'The split is almost perfectly even — '
          '${Fmt.percent(participants[0].share, decimals: 0)} to '
          '${Fmt.percent(participants[1].share, decimals: 0)}.',
          '⚖️',
          InsightTone.celebratory,
          weight: 3.3,
        );
      }
    }

    // --- Emoji ------------------------------------------------------------
    final favorite = emoji.favorite;
    if (favorite != null && emoji.top.isNotEmpty) {
      say(
        'You really love $favorite — used ${Fmt.n(emoji.top.first.value)} '
        'times.',
        favorite,
        InsightTone.playful,
        weight: 3.4,
      );
    }
    if (emoji.emojiRate > 0.5) {
      say(
        'More than half of your messages carry an emoji.',
        '✨',
        InsightTone.warm,
        weight: 2.2,
      );
    } else if (emoji.emojiRate < 0.03 && conversation.totalMessages > 500) {
      say(
        'Almost no emoji anywhere. Words only, apparently.',
        '🔤',
        InsightTone.curious,
        weight: 2.3,
      );
    }

    // --- Double texting ---------------------------------------------------
    final doubler = _maxBy(participants, (p) => p.doubleTexts.toDouble());
    if (doubler != null && doubler.messageCount > 0) {
      final rate = doubler.doubleTexts / doubler.messageCount;
      if (rate > 0.18) {
        say(
          'Someone definitely likes double texting — ${doubler.name} did it '
          '${Fmt.n(doubler.doubleTexts)} times.',
          '📲',
          InsightTone.playful,
          weight: 2.9,
        );
      }
    }

    // --- Volume and language ---------------------------------------------
    if (conversation.totalWords > 50000) {
      final novels = conversation.totalWords / 80000;
      say(
        'You have written ${Fmt.compact(conversation.totalWords)} words — '
        'about ${novels < 1 ? "most of a novel" : "${novels.toStringAsFixed(1)} novels"}.',
        '📚',
        InsightTone.celebratory,
        weight: 3.6,
      );
    }

    if (language.topWords.isNotEmpty) {
      say(
        '"${language.topWords.first.name}" is the word you both keep coming '
        'back to.',
        '💬',
        InsightTone.warm,
        weight: 2.6,
      );
    }

    if (activity.longestSilence.inDays >= 21 &&
        activity.longestSilenceStart != null) {
      say(
        'The longest silence lasted ${activity.longestSilence.inDays} days, '
        'starting ${activity.longestSilenceStart!.shortDate}.',
        '🤐',
        InsightTone.curious,
        weight: 2.7,
      );
    }

    if (activity.busiestDay.count > conversation.messagesPerActiveDay * 4) {
      say(
        'On ${activity.busiestDay.date.shortDate} you sent '
        '${Fmt.n(activity.busiestDay.count)} messages in one day.',
        '💥',
        InsightTone.celebratory,
        weight: 3.05,
        detail: 'Your normal day is about '
            '${conversation.messagesPerActiveDay.round()} messages',
      );
    }

    // --- Momentum ---------------------------------------------------------
    if (response.momentum > 0.25) {
      say(
        'This chat is busier now than it has ever been.',
        '📈',
        InsightTone.celebratory,
        weight: 3.7,
      );
    } else if (response.momentum < -0.35) {
      say(
        'Things have quietened down lately compared with how this chat used '
        'to run.',
        '📉',
        InsightTone.curious,
        weight: 2.1,
      );
    }

    // --- Closing note -----------------------------------------------------
    if (scores.friendship >= 78) {
      say(
        'By every measure here, this friendship deserves premium status.',
        '🏆',
        InsightTone.celebratory,
        weight: 4,
      );
    }

    out.sort((a, b) => b.weight.compareTo(a.weight));
    return out;
  }

  static ParticipantStats? _maxBy(
    List<ParticipantStats> people,
    double Function(ParticipantStats) score,
  ) {
    ParticipantStats? best;
    var bestScore = 0.0;
    for (final p in people) {
      final value = score(p);
      if (value > bestScore) {
        bestScore = value;
        best = p;
      }
    }
    return best;
  }
}
