import 'package:flutter_test/flutter_test.dart';
import 'package:nuntius/features/parser/whatsapp_parser.dart';
import 'package:nuntius/models/chat_message.dart';
import 'package:nuntius/models/parsed_chat.dart';

void main() {
  const parser = WhatsAppParser();

  group('format detection', () {
    test('parses the Android dashed format', () {
      final chat = parser.parse(
        '14/01/2023, 20:12 - Sana: hello\n'
        '14/01/2023, 20:13 - Rehan: hi\n',
      );

      expect(chat.messages, hasLength(2));
      expect(chat.participants, ['Sana', 'Rehan']);
      expect(chat.messages.first.body, 'hello');
      expect(chat.messages.first.timestamp, DateTime(2023, 1, 14, 20, 12));
    });

    test('parses the iOS bracketed format', () {
      final chat = parser.parse(
        '[14/01/2023, 8:12:05 PM] Sana: hello\n'
        '[14/01/2023, 8:13:40 PM] Rehan: hi\n',
      );

      expect(chat.messages, hasLength(2));
      expect(chat.messages.first.timestamp.hour, 20);
      expect(chat.messages.first.timestamp.minute, 12);
    });

    test('handles 12-hour times with AM/PM', () {
      final chat = parser.parse(
        '14/01/2023, 12:05 AM - Sana: midnight\n'
        '14/01/2023, 12:05 PM - Sana: noon\n',
      );

      expect(chat.messages[0].timestamp.hour, 0);
      expect(chat.messages[1].timestamp.hour, 12);
    });

    test('reads two-digit years', () {
      final chat = parser.parse('14/01/23, 20:12 - Sana: hello\n');
      expect(chat.messages.single.timestamp.year, 2023);
    });
  });

  group('date order', () {
    test('day-first when a value above 12 appears in the first position', () {
      final chat = parser.parse(
        '25/01/2023, 10:00 - Sana: a\n'
        '26/01/2023, 10:00 - Sana: b\n',
      );

      expect(chat.dateOrder, DateOrder.dayFirst);
      expect(chat.messages.first.timestamp.day, 25);
      expect(chat.messages.first.timestamp.month, 1);
    });

    test('month-first when a value above 12 appears in the second position',
        () {
      final chat = parser.parse(
        '01/25/2023, 10:00 - Sana: a\n'
        '01/26/2023, 10:00 - Sana: b\n',
      );

      expect(chat.dateOrder, DateOrder.monthFirst);
      expect(chat.messages.first.timestamp.month, 1);
      expect(chat.messages.first.timestamp.day, 25);
    });

    test('falls back to sequence when both positions are ambiguous', () {
      // Read day-first these are 1 Feb, 1 Mar, 1 Apr — in order.
      // Read month-first they are 2 Jan, 3 Jan, 4 Jan — also in order, so the
      // parser should not crash or produce times that run backwards.
      final chat = parser.parse(
        '01/02/2023, 10:00 - Sana: a\n'
        '01/03/2023, 10:00 - Sana: b\n'
        '01/04/2023, 10:00 - Sana: c\n',
      );

      expect(chat.messages, hasLength(3));
      expect(
        chat.messages[1].timestamp.isAfter(chat.messages[0].timestamp),
        isTrue,
      );
    });

    test('parses the ISO format', () {
      final chat = parser.parse('2023-01-14, 20:12 - Sana: hello\n');
      expect(chat.messages.single.timestamp, DateTime(2023, 1, 14, 20, 12));
    });
  });

  group('message bodies', () {
    test('folds continuation lines into the previous message', () {
      final chat = parser.parse(
        '14/01/2023, 20:12 - Sana: line one\n'
        'line two\n'
        'line three\n'
        '14/01/2023, 20:14 - Rehan: reply\n',
      );

      expect(chat.messages, hasLength(2));
      expect(chat.messages.first.body, 'line one\nline two\nline three');
    });

    test('treats a line with no sender as a system message', () {
      final chat = parser.parse(
        '14/01/2023, 20:12 - Messages are end-to-end encrypted.\n'
        '14/01/2023, 20:13 - Sana: hi\n',
      );

      expect(chat.messages.first.isSystem, isTrue);
      expect(chat.messages.first.sender, isNull);
      expect(chat.participants, ['Sana']);
    });

    test('does not treat a colon in ordinary prose as a sender', () {
      final chat = parser.parse(
        '14/01/2023, 20:12 - Sana: note to self: buy milk\n',
      );

      expect(chat.messages.single.sender, 'Sana');
      expect(chat.messages.single.body, 'note to self: buy milk');
    });
  });

  group('classification', () {
    test('recognises omitted media', () {
      final chat = parser.parse(
        '14/01/2023, 20:12 - Sana: <Media omitted>\n'
        '14/01/2023, 20:13 - Sana: image omitted\n'
        '14/01/2023, 20:14 - Sana: This message was deleted\n',
      );

      expect(chat.messages[0].type.isMedia, isTrue);
      expect(chat.messages[1].type, MessageType.image);
      expect(chat.messages[2].type, MessageType.deleted);
    });

    test('an attachment marker classifies by file extension', () {
      final chat = parser.parse(
        '[14/01/2023, 8:12:00 PM] Sana: \u200eIMG-2023.jpg \u2039attached\u203a\n',
      );

      expect(chat.messages.single.type, MessageType.image);
    });

    test('a filename mentioned in ordinary text stays text', () {
      final chat = parser.parse(
        '14/01/2023, 20:12 - Sana: have a look at budget.pdf when you can\n',
      );

      expect(chat.messages.single.type, MessageType.text);
    });
  });

  group('robustness', () {
    test('an empty export produces no messages rather than throwing', () {
      final chat = parser.parse('');
      expect(chat.messages, isEmpty);
      expect(chat.participants, isEmpty);
    });

    test('unparseable leading junk is counted, not fatal', () {
      final chat = parser.parse(
        'this is not an export\n'
        'neither is this\n'
        '14/01/2023, 20:12 - Sana: but this is\n',
      );

      expect(chat.messages, hasLength(1));
      expect(chat.skippedLines, 2);
    });

    test('looksLikeWhatsAppExport needs several convincing lines', () {
      expect(
        looksLikeWhatsAppExport('Dear Sir,\nPlease find attached.'),
        isFalse,
      );
      // One lucky line is not enough — a document could contain a date.
      expect(
        looksLikeWhatsAppExport('14/01/2023, 20:12 - Sana: hello'),
        isFalse,
      );
      expect(
        looksLikeWhatsAppExport(
          '14/01/2023, 20:12 - Sana: hello\n'
          '14/01/2023, 20:13 - Rehan: hi\n'
          '14/01/2023, 20:14 - Sana: how are you\n',
        ),
        isTrue,
      );
    });
  });
}
