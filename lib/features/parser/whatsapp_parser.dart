import '../../core/utils/text_utils.dart';
import '../../models/chat_message.dart';
import '../../models/parsed_chat.dart';
import 'whatsapp_patterns.dart';

/// Reads a WhatsApp `.txt` export into [ChatMessage]s.
///
/// Pure Dart with no Flutter dependency so it can run unchanged inside an
/// isolate (see ParserService) and in unit tests.
///
/// Two passes:
///   1. a cheap scan of date prefixes to work out whether the export is
///      day-first, month-first or year-first;
///   2. a full pass that builds messages, folding continuation lines into the
///      message above them.
class WhatsAppParser {
  const WhatsAppParser();

  /// [onProgress] receives 0..1 and is called at most 100 times.
  ParsedChat parse(
    String raw, {
    String sourceName = 'chat.txt',
    int? sourceBytes,
    void Function(double progress)? onProgress,
  }) {
    final warnings = <ParseWarning>[];
    final text = raw.replaceAll(WhatsAppPatterns.invisibles, '');
    final lines = text.split(RegExp(r'\r\n|\r|\n'));

    final order = _detectDateOrder(lines, warnings);

    final messages = <ChatMessage>[];
    final participants = <String>[];
    final participantSet = <String>{};

    var skipped = 0;
    String? pendingSender;
    DateTime? pendingTime;
    StringBuffer? pendingBody;
    var index = 0;

    void flush() {
      if (pendingTime == null || pendingBody == null) return;
      final body = pendingBody!.toString().trimRight();
      final isSystem = pendingSender == null;
      final type = isSystem
          ? MessageType.system
          : (WhatsAppPatterns.classify(body) ?? MessageType.text);
      messages.add(
        ChatMessage(
          index: index++,
          timestamp: pendingTime!,
          sender: pendingSender,
          body: body,
          type: type,
        ),
      );
      pendingSender = null;
      pendingTime = null;
      pendingBody = null;
    }

    final progressEvery = (lines.length / 100).ceil().clamp(1, 1 << 30);

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (onProgress != null && i % progressEvery == 0) {
        onProgress(i / lines.length);
      }

      final header = _matchHeader(line);
      if (header == null) {
        if (pendingBody != null) {
          // Continuation of a multi-line message.
          pendingBody!.write('\n');
          pendingBody!.write(line);
        } else if (line.trim().isNotEmpty) {
          skipped++;
          if (warnings.length < 5) {
            warnings.add(
              ParseWarning(
                'Line did not match any known export format and was skipped.',
                lineNumber: i + 1,
                sample: line.length > 80 ? '${line.substring(0, 80)}…' : line,
              ),
            );
          }
        }
        continue;
      }

      flush();

      final timestamp = _buildTimestamp(header, order);
      if (timestamp == null) {
        skipped++;
        continue;
      }

      var sender = header.sender?.trim();
      final body = header.body;

      // A sender candidate that reads like a system notice is not a person.
      if (sender != null &&
          (sender.length > 60 ||
              WhatsAppPatterns.systemSenderGuard.hasMatch(sender))) {
        sender = null;
      }
      if (sender != null && sender.isNotEmpty) {
        if (participantSet.add(sender)) participants.add(sender);
      }

      pendingSender = (sender != null && sender.isNotEmpty) ? sender : null;
      pendingTime = timestamp;
      pendingBody = StringBuffer(body);
    }

    flush();
    onProgress?.call(1);

    if (messages.isEmpty) {
      warnings.add(
        const ParseWarning(
          'No messages were recognised. This does not look like a WhatsApp '
          'export — make sure you exported the chat "Without media" and are '
          'opening the .txt file, not the .zip.',
        ),
      );
    } else if (skipped > messages.length * 0.25) {
      warnings.add(
        ParseWarning(
          '$skipped lines could not be read. Dates or names may be incomplete.',
        ),
      );
    }

    return ParsedChat(
      messages: messages,
      participants: participants,
      dateOrder: order,
      sourceName: sourceName,
      sourceBytes: sourceBytes ?? raw.length,
      skippedLines: skipped,
      warnings: warnings,
    );
  }

  // ---------------------------------------------------------------- headers

  _Header? _matchHeader(String line) {
    if (line.isEmpty) return null;
    // Fast reject: every header starts with a digit or an opening bracket.
    final first = line.codeUnitAt(0);
    final startsPlausibly =
        first == 0x5B /* [ */ || (first >= 0x30 && first <= 0x39);
    if (!startsPlausibly) return null;

    final match = WhatsAppPatterns.bracketed.firstMatch(line) ??
        WhatsAppPatterns.dashed.firstMatch(line);
    if (match == null) return null;

    return _Header(
      a: int.parse(match.group(1)!),
      b: int.parse(match.group(2)!),
      c: int.parse(match.group(3)!),
      hour: int.parse(match.group(4)!),
      minute: int.parse(match.group(5)!),
      second: int.tryParse(match.group(6) ?? '') ?? 0,
      meridiem: match.group(7),
      sender: match.group(8),
      body: match.group(9) ?? '',
    );
  }

  DateTime? _buildTimestamp(_Header h, DateOrder order) {
    int year, month, day;
    switch (order) {
      case DateOrder.yearFirst:
        year = h.a;
        month = h.b;
        day = h.c;
      case DateOrder.dayFirst:
        day = h.a;
        month = h.b;
        year = _expandYear(h.c);
      case DateOrder.monthFirst:
        month = h.a;
        day = h.b;
        year = _expandYear(h.c);
    }

    var hour = h.hour;
    final meridiem = h.meridiem?.toLowerCase().replaceAll(RegExp(r'[^apm]'), '');
    if (meridiem != null && meridiem.isNotEmpty) {
      if (meridiem.startsWith('p') && hour < 12) hour += 12;
      if (meridiem.startsWith('a') && hour == 12) hour = 0;
    }

    if (month < 1 || month > 12 || day < 1 || day > 31 || hour > 23) {
      return null;
    }
    return DateTime(year, month, day, hour, h.minute, h.second);
  }

  static int _expandYear(int value) {
    if (value >= 1000) return value;
    // WhatsApp did not exist before 2009, so a two-digit year is always 20xx.
    return 2000 + value;
  }

  // ------------------------------------------------------------ date order

  /// Works out how to read `12/03/2023`.
  ///
  /// Order of evidence:
  ///   1. a four-digit first component means year-first;
  ///   2. a first component above 12 means day-first, a second component above
  ///      12 means month-first — this settles almost every real export;
  ///   3. if a chat is short enough that neither ever exceeds 12, try both and
  ///      keep whichever produces a chronologically increasing sequence;
  ///   4. otherwise fall back on the clock: a 12-hour clock with AM/PM is
  ///      overwhelmingly a US-locale export, which is month-first.
  DateOrder _detectDateOrder(List<String> lines, List<ParseWarning> warnings) {
    var dayFirstEvidence = 0;
    var monthFirstEvidence = 0;
    var yearFirstEvidence = 0;
    final sample = <List<int>>[];

    for (final line in lines) {
      final m = WhatsAppPatterns.datePrefix.firstMatch(line);
      if (m == null) continue;
      final a = int.parse(m.group(1)!);
      final b = int.parse(m.group(2)!);
      final c = int.parse(m.group(3)!);
      if (a >= 1000) {
        yearFirstEvidence++;
        continue;
      }
      if (a > 12) dayFirstEvidence++;
      if (b > 12) monthFirstEvidence++;
      if (sample.length < 400) sample.add([a, b, c]);
    }

    if (yearFirstEvidence > 0 &&
        yearFirstEvidence >= dayFirstEvidence + monthFirstEvidence) {
      return DateOrder.yearFirst;
    }
    if (dayFirstEvidence > 0 && monthFirstEvidence == 0) {
      return DateOrder.dayFirst;
    }
    if (monthFirstEvidence > 0 && dayFirstEvidence == 0) {
      return DateOrder.monthFirst;
    }
    if (dayFirstEvidence > 0 && monthFirstEvidence > 0) {
      warnings.add(
        const ParseWarning(
          'This export mixes date formats. Dates were read day-first; check '
          'the date range on the summary card.',
        ),
      );
      return dayFirstEvidence >= monthFirstEvidence
          ? DateOrder.dayFirst
          : DateOrder.monthFirst;
    }

    final dayFirstSorted = _isChronological(sample, dayFirst: true);
    final monthFirstSorted = _isChronological(sample, dayFirst: false);
    if (dayFirstSorted && !monthFirstSorted) return DateOrder.dayFirst;
    if (monthFirstSorted && !dayFirstSorted) return DateOrder.monthFirst;

    final usesMeridiem = lines.any(
      (l) => RegExp(r'\d\s*[APap]\.?\s?[Mm]').hasMatch(l),
    );
    if (sample.isNotEmpty) {
      warnings.add(
        ParseWarning(
          'Every date in this chat could be read two ways. Assuming '
          '${usesMeridiem ? "month/day" : "day/month"} order.',
        ),
      );
    }
    return usesMeridiem ? DateOrder.monthFirst : DateOrder.dayFirst;
  }

  bool _isChronological(List<List<int>> sample, {required bool dayFirst}) {
    var previous = 0;
    for (final parts in sample) {
      final year = _expandYear(parts[2]);
      final month = dayFirst ? parts[1] : parts[0];
      final day = dayFirst ? parts[0] : parts[1];
      if (month < 1 || month > 12 || day < 1 || day > 31) return false;
      final key = year * 10000 + month * 100 + day;
      if (key < previous) return false;
      previous = key;
    }
    return true;
  }
}

class _Header {
  const _Header({
    required this.a,
    required this.b,
    required this.c,
    required this.hour,
    required this.minute,
    required this.second,
    required this.meridiem,
    required this.sender,
    required this.body,
  });

  final int a;
  final int b;
  final int c;
  final int hour;
  final int minute;
  final int second;
  final String? meridiem;
  final String? sender;
  final String body;
}

/// Convenience used by the import preview: a very fast structural check that
/// avoids parsing a 40 MB file just to tell the user it is the wrong file.
bool looksLikeWhatsAppExport(String head) {
  final lines = head.split(RegExp(r'\r\n|\r|\n')).take(50);
  var hits = 0;
  for (final line in lines) {
    if (WhatsAppPatterns.bracketed.hasMatch(line) ||
        WhatsAppPatterns.dashed.hasMatch(line)) {
      hits++;
      if (hits >= 3) return true;
    }
  }
  return false;
}

/// Word/char counting lives with the parser so the analytics pass does not
/// have to re-walk every string twice.
extension MessageMetrics on ChatMessage {
  int get wordCount => hasText ? TextUtils.wordCount(body) : 0;
  int get charCount => hasText ? body.length : 0;
}
