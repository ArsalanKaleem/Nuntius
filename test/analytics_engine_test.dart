import 'package:flutter_test/flutter_test.dart';
import 'package:nuntius/features/analytics/analytics_engine.dart';
import 'package:nuntius/features/parser/whatsapp_parser.dart';
import 'package:nuntius/models/chat_analytics.dart';

const _parser = WhatsAppParser();
const _engine = AnalyticsEngine();

/// Builds an export from `(day offset, hour, minute, sender, body)` tuples so
/// the tests read as timelines rather than as strings.
String _export(List<(int, int, int, String, String)> rows) {
  final base = DateTime(2023, 1, 2); // a Monday
  final buffer = StringBuffer();
  for (final (dayOffset, hour, minute, sender, body) in rows) {
    final date = base.add(Duration(days: dayOffset));
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final hh = hour.toString().padLeft(2, '0');
    final mi = minute.toString().padLeft(2, '0');
    buffer.writeln('$dd/$mm/${date.year}, $hh:$mi - $sender: $body');
  }
  return buffer.toString();
}

ChatAnalytics _analyze(String raw, {String name = 'WhatsApp Chat with Sana.txt'}) =>
    _engine.analyze(_parser.parse(raw, sourceName: name));

void main() {
  group('conversation totals', () {
    test('counts messages, words and people', () {
      final a = _analyze(_export([
        (0, 9, 0, 'Sana', 'one two three'),
        (0, 9, 5, 'Rehan', 'four five'),
      ]));

      expect(a.conversation.totalMessages, 2);
      expect(a.conversation.totalWords, 5);
      expect(a.participants, hasLength(2));
      expect(a.chatTitle, 'Sana');
    });

    test('media and deleted messages are not counted as words', () {
      final a = _analyze(_export([
        (0, 9, 0, 'Sana', 'hello there'),
        (0, 9, 1, 'Sana', '<Media omitted>'),
        (0, 9, 2, 'Sana', 'This message was deleted'),
      ]));

      expect(a.conversation.totalWords, 2);
    });

    test('shares add up to one', () {
      final a = _analyze(_export([
        (0, 9, 0, 'Sana', 'a'),
        (0, 9, 1, 'Sana', 'b'),
        (0, 9, 2, 'Sana', 'c'),
        (0, 9, 3, 'Rehan', 'd'),
      ]));

      final total = a.participants.fold<double>(0, (sum, p) => sum + p.share);
      expect(total, closeTo(1.0, 1e-9));
      expect(a.participants.first.name, 'Sana');
      expect(a.participants.first.share, closeTo(0.75, 1e-9));
    });
  });

  group('activity', () {
    test('finds the longest streak of consecutive days', () {
      final a = _analyze(_export([
        (0, 9, 0, 'Sana', 'a'),
        (1, 9, 0, 'Sana', 'b'),
        (2, 9, 0, 'Sana', 'c'),
        // gap
        (9, 9, 0, 'Sana', 'd'),
        (10, 9, 0, 'Sana', 'e'),
      ]));

      expect(a.activity.longestStreak.days, 3);
      expect(a.activity.longestStreak.start, DateTime(2023, 1, 2));
      expect(a.activity.currentStreak.days, 2);
      expect(a.conversation.activeDays, 5);
    });

    test('buckets by hour and weekday', () {
      final a = _analyze(_export([
        (0, 23, 0, 'Sana', 'a'),
        (0, 23, 30, 'Rehan', 'b'),
        (1, 8, 0, 'Sana', 'c'),
      ]));

      expect(a.activity.hourHistogram[23], 2);
      expect(a.activity.hourHistogram[8], 1);
      // 2 Jan 2023 was a Monday.
      expect(a.activity.weekdayHistogram[0], 2);
      expect(a.activity.busiestHour, 23);
    });

    test('measures the longest silence', () {
      final a = _analyze(_export([
        (0, 9, 0, 'Sana', 'a'),
        (0, 10, 0, 'Rehan', 'b'),
        (30, 9, 0, 'Sana', 'still here?'),
      ]));

      expect(a.activity.longestSilence.inDays, 29);
    });
  });

  group('replies', () {
    test('the median is taken across replies from the other person', () {
      final a = _analyze(_export([
        (0, 9, 0, 'Sana', 'a'),
        (0, 9, 10, 'Rehan', 'b'), // 10 min
        (1, 9, 0, 'Sana', 'c'),
        (1, 9, 20, 'Rehan', 'd'), // 20 min
        (2, 9, 0, 'Sana', 'e'),
        (2, 9, 30, 'Rehan', 'f'), // 30 min
      ]));

      expect(a.response.medianReply, const Duration(minutes: 20));
      expect(a.response.sampleCount, 3);
    });

    test('a gap longer than the reply window is a new conversation', () {
      final a = _analyze(_export([
        (0, 9, 0, 'Sana', 'a'),
        (0, 23, 0, 'Rehan', 'b'), // 14 hours later
      ]));

      // Not counted as a reply, so there is no reliable median.
      expect(a.response.sampleCount, 0);
      expect(a.response.isReliable, isFalse);
    });

    test('consecutive messages from one person are double texts', () {
      final a = _analyze(_export([
        (0, 9, 0, 'Sana', 'a'),
        (0, 9, 1, 'Sana', 'b'),
        (0, 9, 30, 'Rehan', 'c'),
      ]));

      final sana = a.participants.firstWhere((p) => p.name == 'Sana');
      expect(sana.doubleTexts, 1);
    });
  });

  group('scores', () {
    test('a perfectly even two-way chat scores full balance', () {
      final a = _analyze(_export([
        (0, 9, 0, 'Sana', 'a'),
        (0, 9, 1, 'Rehan', 'b'),
        (1, 9, 0, 'Sana', 'c'),
        (1, 9, 1, 'Rehan', 'd'),
      ]));

      expect(a.scores.balance, closeTo(100, 0.001));
    });

    test('a one-sided chat scores near-zero balance', () {
      final a = _analyze(_export([
        for (var i = 0; i < 20; i++) (0, 9, i, 'Sana', 'message $i'),
        (0, 10, 0, 'Rehan', 'ok'),
      ]));

      expect(a.scores.balance, lessThan(35));
    });

    test('every score stays inside 0..100', () {
      final a = _analyze(_export([
        (0, 9, 0, 'Sana', 'hello 😀'),
        (0, 9, 3, 'Rehan', 'hi haha'),
        (5, 22, 0, 'Sana', 'still awake?'),
      ]));

      for (final score in [
        a.scores.friendship,
        a.scores.balance,
        a.scores.consistency,
        a.scores.responsiveness,
        a.scores.warmth,
      ]) {
        expect(score, inInclusiveRange(0, 100));
      }
    });
  });

  group('language and emoji', () {
    test('filler words are kept out of the word cloud', () {
      final a = _analyze(_export([
        for (var i = 0; i < 8; i++)
          (i, 9, 0, 'Sana', 'the and but biryani biryani'),
      ]));

      final words = a.language.topWords.map((w) => w.name);
      expect(words, contains('biryani'));
      expect(words, isNot(contains('the')));
      expect(words, isNot(contains('and')));
    });

    test('counts emoji rather than characters', () {
      final a = _analyze(_export([
        (0, 9, 0, 'Sana', 'yes 🎉🎉 great 😀'),
        (0, 9, 5, 'Rehan', 'no emoji here'),
      ]));

      expect(a.emoji.totalEmojis, 3);
      expect(a.emoji.top.first.name, '🎉');
      expect(a.emoji.emojiRate, closeTo(0.5, 1e-9));
    });

    test('questions are detected', () {
      final a = _analyze(_export([
        (0, 9, 0, 'Sana', 'are you coming?'),
        (0, 9, 5, 'Rehan', 'yes'),
      ]));

      expect(a.language.questionCount, 1);
    });
  });

  group('derived content', () {
    test('produces milestones, insights and achievements', () {
      final a = _analyze(_export([
        for (var day = 0; day < 40; day++)
          for (var i = 0; i < 4; i++)
            (day, 20 + (i % 3), i * 7, i.isEven ? 'Sana' : 'Rehan',
                'message $day-$i 😀'),
      ]));

      expect(a.milestones, isNotEmpty);
      expect(a.insights, isNotEmpty);
      expect(a.achievements, isNotEmpty);
      expect(a.achievements.where((x) => x.unlocked), isNotEmpty);
      expect(a.awards, isNotEmpty);
    });

    test('refuses to analyse an empty chat', () {
      expect(
        () => _engine.analyze(_parser.parse('')),
        throwsA(isA<StateError>()),
      );
    });
  });
}
