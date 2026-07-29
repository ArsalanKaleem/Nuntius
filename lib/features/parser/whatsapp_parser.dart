import '../../core/utils/text_utils.dart';
import '../../models/chat_message.dart';
import '../../models/parsed_chat.dart';
import 'whatsapp_patterns.dart';

/// Reads a WhatsApp `.txt` export into [ChatMessage]s.
///
/// Pure Dart with no Flutter dependency so it can run unchanged inside an
/// isolate and in unit tests.
///
/// Reading takes two passes:
///   1. a cheap scan of date prefixes to work out whether the export is
///      day-first, month-first or year-first;
///   2. a full pass that builds messages, folding continuation lines into the
///      message above them.
///
/// Both passes are exposed line-at-a-time — [DateOrderProbe] for the first and
/// [ChatLineParser] for the second — so a caller can feed them from a file
/// stream and never hold the whole export in memory. [parse] is the convenience
/// wrapper that does both over a string already in hand, and is what the tests
/// and the bundled sample use.
class WhatsAppParser {
  const WhatsAppParser();

  /// [onProgress] receives 0..1 and is called at most 100 times.
  ParsedChat parse(
      String raw, {
        String sourceName = 'chat.txt',
        int? sourceBytes,
        void Function(double progress)? onProgress,
      }) {
    final text = raw.replaceAll(WhatsAppPatterns.invisibles, '');
    final lines = text.split(RegExp(r'\r\n|\r|\n'));

    final probe = DateOrderProbe();
    for (final line in lines) {
      probe.add(line);
    }

    final warnings = <ParseWarning>[];
    final order = probe.resolve(warnings);

    final parser = ChatLineParser(
      order: order,
      sourceName: sourceName,
      sourceBytes: sourceBytes ?? raw.length,
      warnings: warnings,
    );

    final progressEvery = (lines.length / 100).ceil().clamp(1, 1 << 30);
    for (var i = 0; i < lines.length; i++) {
      if (onProgress != null && i % progressEvery == 0) {
        onProgress(i / lines.length);
      }
      parser.add(lines[i]);
    }
    onProgress?.call(1);

    return parser.finish();
  }
}

/// First pass: works out how to read `12/03/2023`.
///
/// Order of evidence:
///   1. a four-digit first component means year-first;
///   2. a first component above 12 means day-first, a second component above 12
///      means month-first — this settles almost every real export;
///   3. if a chat is short enough that neither ever exceeds 12, try both and
///      keep whichever produces a chronologically increasing sequence;
///   4. otherwise fall back on the clock: a 12-hour clock with AM/PM is
///      overwhelmingly a US-locale export, which is month-first.
///
/// Holds a bounded amount of state — three counters, at most 400 sampled dates
/// and one boolean — so it costs the same on a 200-message chat as on a
/// 2-million-message one.
class DateOrderProbe {
  final _sample = <List<int>>[];
  final _meridiemPattern = RegExp(r'\d\s*[APap]\.?\s?[Mm]');

  int _dayFirst = 0;
  int _monthFirst = 0;
  int _yearFirst = 0;
  bool _usesMeridiem = false;

  void add(String line) {
    if (!_usesMeridiem && _meridiemPattern.hasMatch(line)) {
      _usesMeridiem = true;
    }

    final m = WhatsAppPatterns.datePrefix.firstMatch(line);
    if (m == null) return;

    final a = int.parse(m.group(1)!);
    final b = int.parse(m.group(2)!);
    final c = int.parse(m.group(3)!);

    if (a >= 1000) {
      _yearFirst++;
      return;
    }
    if (a > 12) _dayFirst++;
    if (b > 12) _monthFirst++;
    if (_sample.length < 400) _sample.add([a, b, c]);
  }

  /// Appends an explanatory warning when the evidence was ambiguous, so the
  /// import screen can tell the user which way the dates were read.
  DateOrder resolve(List<ParseWarning> warnings) {
    if (_yearFirst > 0 && _yearFirst >= _dayFirst + _monthFirst) {
      return DateOrder.yearFirst;
    }
    if (_dayFirst > 0 && _monthFirst == 0) return DateOrder.dayFirst;
    if (_monthFirst > 0 && _dayFirst == 0) return DateOrder.monthFirst;

    if (_dayFirst > 0 && _monthFirst > 0) {
      warnings.add(
        const ParseWarning(
          'This export mixes date formats. Dates were read day-first; check '
              'the date range on the summary card.',
        ),
      );
      return _dayFirst >= _monthFirst ? DateOrder.dayFirst : DateOrder.monthFirst;
    }

    final dayFirstSorted = _isChronological(_sample, dayFirst: true);
    final monthFirstSorted = _isChronological(_sample, dayFirst: false);
    if (dayFirstSorted && !monthFirstSorted) return DateOrder.dayFirst;
    if (monthFirstSorted && !dayFirstSorted) return DateOrder.monthFirst;

    if (_sample.isNotEmpty) {
      warnings.add(
        ParseWarning(
          'Every date in this chat could be read two ways. Assuming '
              '${_usesMeridiem ? "month/day" : "day/month"} order.',
        ),
      );
    }
    return _usesMeridiem ? DateOrder.monthFirst : DateOrder.dayFirst;
  }

  static bool _isChronological(
      List<List<int>> sample, {
        required bool dayFirst,
      }) {
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

/// Second pass: turns lines into messages, one line at a time.
///
/// A message is only complete once the *next* header arrives, because anything
/// between two headers belongs to the earlier message. So [add] buffers and
/// [finish] flushes the last one.
class ChatLineParser {
  ChatLineParser({
    required this.order,
    this.sourceName = 'chat.txt',
    this.sourceBytes,
    List<ParseWarning>? warnings,
  }) : warnings = warnings ?? <ParseWarning>[];

  final DateOrder order;
  final String sourceName;

  /// Byte length of the source, when the caller knows it. Streaming callers do,
  /// from the file handle; a string caller falls back to character count.
  final int? sourceBytes;

  final List<ParseWarning> warnings;

  final _messages = <ChatMessage>[];
  final _participants = <String>[];
  final _participantSet = <String>{};

  int _lineNumber = 0;
  int _skipped = 0;
  int _index = 0;
  int _charactersSeen = 0;

  String? _pendingSender;
  DateTime? _pendingTime;
  StringBuffer? _pendingBody;

  int get messageCount => _messages.length;

  void add(String rawLine) {
    _lineNumber++;
    // Bidi and zero-width marks are stripped per line rather than over the
    // whole document, which is what makes streaming possible: the invisible
    // characters WhatsApp inserts never straddle a line break.
    final line = rawLine.replaceAll(WhatsAppPatterns.invisibles, '');
    _charactersSeen += rawLine.length + 1;

    final header = _matchHeader(line);
    if (header == null) {
      if (_pendingBody != null) {
        // Continuation of a multi-line message.
        _pendingBody!.write('\n');
        _pendingBody!.write(line);
      } else if (line.trim().isNotEmpty) {
        _skipped++;
        if (warnings.length < 5) {
          warnings.add(
            ParseWarning(
              'Line did not match any known export format and was skipped.',
              lineNumber: _lineNumber,
              sample: line.length > 80 ? '${line.substring(0, 80)}…' : line,
            ),
          );
        }
      }
      return;
    }

    _flush();

    final timestamp = _buildTimestamp(header, order);
    if (timestamp == null) {
      _skipped++;
      return;
    }

    var sender = header.sender?.trim();

    // A sender candidate that reads like a system notice is not a person.
    if (sender != null &&
        (sender.length > 60 ||
            WhatsAppPatterns.systemSenderGuard.hasMatch(sender))) {
      sender = null;
    }
    if (sender != null && sender.isNotEmpty) {
      if (_participantSet.add(sender)) _participants.add(sender);
    }

    _pendingSender = (sender != null && sender.isNotEmpty) ? sender : null;
    _pendingTime = timestamp;
    _pendingBody = StringBuffer(header.body);
  }

  void _flush() {
    if (_pendingTime == null || _pendingBody == null) return;
    final body = _pendingBody!.toString().trimRight();
    final isSystem = _pendingSender == null;
    final type = isSystem
        ? MessageType.system
        : (WhatsAppPatterns.classify(body) ?? MessageType.text);
    _messages.add(
      ChatMessage(
        index: _index++,
        timestamp: _pendingTime!,
        sender: _pendingSender,
        body: body,
        type: type,
      ),
    );
    _pendingSender = null;
    _pendingTime = null;
    _pendingBody = null;
  }

  ParsedChat finish() {
    _flush();

    if (_messages.isEmpty) {
      warnings.add(
        const ParseWarning(
          'No messages were recognised. This does not look like a WhatsApp '
              'export — make sure you exported the chat "Without media" and are '
              'opening the .txt file, not the .zip.',
        ),
      );
    } else if (_skipped > _messages.length * 0.25) {
      warnings.add(
        ParseWarning(
          '$_skipped lines could not be read. Dates or names may be '
              'incomplete.',
        ),
      );
    }

    return ParsedChat(
      messages: _messages,
      participants: _participants,
      dateOrder: order,
      sourceName: sourceName,
      sourceBytes: sourceBytes ?? _charactersSeen,
      skippedLines: _skipped,
      warnings: warnings,
    );
  }
}

// -------------------------------------------------------------------- headers

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

int _expandYear(int value) {
  if (value >= 1000) return value;
  // WhatsApp did not exist before 2009, so a two-digit year is always 20xx.
  return 2000 + value;
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
/// avoids parsing a large file just to tell the user it is the wrong file.
///
/// This is the *only* validation the import path applies. Extension checks were
/// removed deliberately — a file handed over by Google Drive, Files or a mail
/// attachment often arrives with a cache name and no useful extension, and
/// judging a chat export by its filename rejected perfectly good files.
bool looksLikeWhatsAppExport(String head) {
  final lines = head.split(RegExp(r'\r\n|\r|\n')).take(200);
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