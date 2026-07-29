import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/extensions/extensions.dart';
import '../../core/utils/emoji_utils.dart';
import '../../core/utils/formatters.dart';
import '../../models/chat_analytics.dart';
import '../../models/participant_stats.dart';

/// Builds the printable report.
///
/// The hard part of a PDF is not layout, it is glyphs. A PDF carries its own
/// fonts, and with none embedded a reader falls back to the "base 14" set —
/// Helvetica and relatives — which are WinAnsi-encoded and contain Latin-1 only.
/// A character with no glyph does not substitute the way it does on screen: it
/// prints as nothing, or as a box. That is why the first version of this report
/// dropped emoji and any Urdu, Hindi, Arabic or CJK text without saying so.
///
/// So the service runs in one of two modes, decided at runtime by whether the
/// optional fonts in `assets/fonts/` are present (see the README there):
///
///  * **Unicode mode** — Noto Sans is embedded as the base face and monochrome
///    Noto Emoji as a fallback, so every character in the chat renders and the
///    reader only reaches for the emoji face when the base has no glyph.
///  * **Latin-1 mode** — no fonts bundled. Every string is sanitized before it
///    reaches the page rather than left to print as boxes, and the method note
///    at the end of the report says this happened.
///
/// Fonts are never downloaded. `printing` can fetch Google Fonts for a PDF in
/// one line, but Nuntius promises that nothing about a chat leaves the device,
/// and it would also break the export whenever the user is offline.
///
/// Charts are drawn as vector boxes rather than by rasterising the on-screen
/// fl_chart widgets, so the report prints sharply and does not depend on the
/// dashboard being open.
class PdfReportService {
  const PdfReportService();

  static const _green = PdfColor.fromInt(0xFF128C7E);
  static const _accent = PdfColor.fromInt(0xFF25D366);
  static const _ink = PdfColor.fromInt(0xFF10201E);
  static const _muted = PdfColor.fromInt(0xFF6B7676);
  static const _hairline = PdfColor.fromInt(0xFFE2E0DA);

  static const _regularPath = 'assets/fonts/NotoSans-Regular.ttf';
  static const _boldPath = 'assets/fonts/NotoSans-Bold.ttf';
  static const _emojiPath = 'assets/fonts/NotoEmoji-Regular.ttf';

  /// Loaded once per process. Font parsing is not free and the result never
  /// changes, so a second export reuses it.
  static Future<_Typeset>? _typeset;

  static Future<_Typeset> _loadTypeset() {
    return _typeset ??= _readTypeset();
  }

  static Future<_Typeset> _readTypeset() async {
    final regular = await _tryFont(_regularPath);
    final bold = await _tryFont(_boldPath);
    final emoji = await _tryFont(_emojiPath);

    // The base face is what decides the mode. Bold and emoji are refinements:
    // without bold we reuse the regular face, without emoji we keep Unicode
    // text and drop only the pictographs.
    if (regular == null) {
      return const _Typeset(unicode: false, hasEmoji: false, theme: null);
    }

    return _Typeset(
      unicode: true,
      hasEmoji: emoji != null,
      theme: pw.ThemeData.withFont(
        base: regular,
        bold: bold ?? regular,
        italic: regular,
        boldItalic: bold ?? regular,
        fontFallback: [if (emoji != null) emoji],
      ),
    );
  }

  static Future<pw.Font?> _tryFont(String asset) async {
    try {
      return pw.Font.ttf(await rootBundle.load(asset));
    } catch (_) {
      // Missing or unreadable asset. Not an error — the fonts are optional.
      return null;
    }
  }

  Future<Uint8List> build(ChatAnalytics a) async {
    final typeset = await _loadTypeset();
    final text = _TextPolicy(typeset, a.participants);

    final doc = pw.Document(
      title: text.plain('${a.chatTitle} — Chat Wrapped'),
      author: 'Nuntius',
      creator: 'Nuntius',
      theme: typeset.theme,
    );

    doc.addPage(_coverPage(a, text));
    doc.addPage(_bodyPages(a, text));

    return doc.save();
  }

  Future<void> shareReport(ChatAnalytics a) async {
    final bytes = await build(a);
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${_slug(a.chatTitle)}-chat-report.pdf',
    );
  }

  /// Opens the OS print preview, which also covers "save as PDF".
  Future<void> printReport(ChatAnalytics a) async {
    await Printing.layoutPdf(onLayout: (_) => build(a));
  }

  // ------------------------------------------------------------------ pages

  pw.Page _coverPage(ChatAnalytics a, _TextPolicy t) {
    final c = a.conversation;
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Container(
        color: _green,
        padding: const pw.EdgeInsets.all(48),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'NUNTIUS',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 11,
                letterSpacing: 4,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 140),
            pw.Text(
              'Chat Wrapped',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 46,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              t.plain(a.chatTitle),
              maxLines: 2,
              style: const pw.TextStyle(color: PdfColors.white, fontSize: 22),
            ),
            pw.SizedBox(height: 28),
            pw.Text(
              Fmt.dateRange(c.firstAt, c.lastAt),
              style: const pw.TextStyle(color: PdfColors.white, fontSize: 13),
            ),
            pw.Spacer(),
            pw.Row(
              children: [
                _coverStat('Messages', Fmt.n(c.totalMessages)),
                _coverStat('Words', Fmt.n(c.totalWords)),
                _coverStat('Days', Fmt.n(c.totalDays)),
                _coverStat('Score', a.scores.friendship.round().toString()),
              ],
            ),
            pw.SizedBox(height: 32),
            pw.Text(
              'Generated on ${a.generatedAt.longDate}. Every number in this '
                  'report was calculated on the device that produced it.',
              style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _coverStat(String label, String value) => pw.Expanded(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label.toUpperCase(),
          style: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 8,
            letterSpacing: 1.6,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    ),
  );

  pw.MultiPage _bodyPages(ChatAnalytics a, _TextPolicy t) {
    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(44, 46, 44, 46),
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 18),
        child: pw.Text(
          t.plain(a.chatTitle),
          maxLines: 1,
          style: const pw.TextStyle(color: _muted, fontSize: 9),
        ),
      ),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 14),
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: const pw.TextStyle(color: _muted, fontSize: 9),
        ),
      ),
      build: (context) => [
        _heading('Summary'),
        _summaryTable(a),
        pw.SizedBox(height: 22),

        _heading('Who talks most'),
        _participantsTable(a.participants, t),
        pw.SizedBox(height: 22),

        if (a.awards.isNotEmpty) ...[
          _heading('Awards'),
          _keyValueTable([
            for (final award in a.awards)
              (
              t.decorate(award.emoji, award.title),
              '${t.name(award.winner)} — ${t.plain(award.value)}',
              ),
          ]),
          pw.SizedBox(height: 22),
        ],

        _heading('When you talk'),
        _barBlock(
          'By hour of day',
          a.activity.hourHistogram,
              (i) => i % 3 == 0 ? Fmt.hour(i).replaceAll(' ', '') : '',
        ),
        pw.SizedBox(height: 14),
        _barBlock(
          'By day of week',
          a.activity.weekdayHistogram,
              (i) => Fmt.weekdayShort[i],
        ),
        pw.SizedBox(height: 14),
        _barBlock(
          'By month of year',
          a.activity.monthHistogram,
              (i) => Fmt.monthShort[i].substring(0, 1),
        ),
        pw.SizedBox(height: 22),

        _heading('What stands out'),
        for (final insight in a.insights.take(8))
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 4,
                  height: 4,
                  margin: const pw.EdgeInsets.only(top: 5, right: 8),
                  decoration: const pw.BoxDecoration(
                    color: _accent,
                    shape: pw.BoxShape.circle,
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    t.plain(
                      insight.detail == null
                          ? insight.text
                          : '${insight.text}  (${insight.detail})',
                    ),
                    style: const pw.TextStyle(fontSize: 10.5, color: _ink),
                  ),
                ),
              ],
            ),
          ),
        pw.SizedBox(height: 22),

        _heading('Timeline'),
        _milestoneTable(a, t),
        pw.SizedBox(height: 22),

        _heading('Words'),
        _wordTable(a, t),
        pw.SizedBox(height: 22),

        _heading('Method'),
        pw.Text(
          _methodNote(a, t),
          style:
          const pw.TextStyle(fontSize: 9.5, color: _muted, lineSpacing: 3),
        ),
      ],
    );
  }

  // --------------------------------------------------------------- sections

  pw.Widget _heading(String text) => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 10),
    padding: const pw.EdgeInsets.only(bottom: 6),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _hairline)),
    ),
    child: pw.Text(
      text.toUpperCase(),
      style: pw.TextStyle(
        fontSize: 9,
        letterSpacing: 2,
        fontWeight: pw.FontWeight.bold,
        color: _green,
      ),
    ),
  );

  pw.Widget _summaryTable(ChatAnalytics a) {
    final c = a.conversation;
    return _keyValueTable([
      ('Messages', Fmt.n(c.totalMessages)),
      ('Words', Fmt.n(c.totalWords)),
      ('Characters', Fmt.n(c.totalCharacters)),
      ('First message', c.firstAt.longDate),
      ('Most recent message', c.lastAt.longDate),
      ('Days covered', Fmt.n(c.totalDays)),
      ('Days with messages', Fmt.n(c.activeDays)),
      ('Messages per active day', c.messagesPerActiveDay.toStringAsFixed(1)),
      ('Typical reply', a.response.medianReply?.humanized ?? 'Not enough data'),
      ('Longest silence', a.activity.longestSilence.humanized),
      (
      'Longest streak',
      a.activity.longestStreak.exists
          ? '${a.activity.longestStreak.days} days'
          : 'None',
      ),
      (
      'Friendship score',
      '${a.scores.friendship.round()} / 100 (${a.scores.friendshipGrade})',
      ),
    ]);
  }

  pw.Widget _keyValueTable(List<(String, String)> rows) => pw.Column(
    children: [
      for (final row in rows)
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _hairline)),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 5,
                child: pw.Text(
                  row.$1,
                  style: const pw.TextStyle(fontSize: 10, color: _muted),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                flex: 4,
                child: pw.Text(
                  row.$2,
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: _ink,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );

  pw.Widget _participantsTable(List<ParticipantStats> people, _TextPolicy t) {
    return pw.TableHelper.fromTextArray(
      border: null,
      headerDecoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _hairline)),
      ),
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 3),
      headerStyle: pw.TextStyle(
        fontSize: 8,
        letterSpacing: 1.2,
        fontWeight: pw.FontWeight.bold,
        color: _muted,
      ),
      cellStyle: const pw.TextStyle(fontSize: 9.5, color: _ink),
      columnWidths: const {
        0: pw.FlexColumnWidth(3.2),
        1: pw.FlexColumnWidth(1.5),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1.5),
        4: pw.FlexColumnWidth(1.4),
        5: pw.FlexColumnWidth(1.2),
      },
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
      },
      headers: const [
        'PERSON',
        'MESSAGES',
        'SHARE',
        'WORDS/MSG',
        'REPLY',
        'STARTS',
      ],
      data: [
        for (final p in people)
          [
            t.name(p.name),
            Fmt.n(p.messageCount),
            Fmt.percent(p.share, decimals: 1),
            p.averageWordsPerMessage.toStringAsFixed(1),
            p.medianReply?.humanized ?? '-',
            Fmt.n(p.conversationsStarted),
          ],
      ],
    );
  }

  /// A bar chart drawn from boxes. Vector, printable, no rasterisation.
  pw.Widget _barBlock(
      String title,
      List<int> values,
      String Function(int index) labelAt,
      ) {
    final max = values.isEmpty
        ? 1
        : values.reduce((a, b) => a > b ? a : b).clamp(1, 1 << 30);
    const height = 62.0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: const pw.TextStyle(fontSize: 9, color: _muted)),
        pw.SizedBox(height: 6),
        pw.SizedBox(
          height: height,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < values.length; i++)
                pw.Expanded(
                  child: pw.Container(
                    margin: const pw.EdgeInsets.symmetric(horizontal: 1),
                    height: (values[i] / max * height).clamp(1.0, height),
                    color: _accent,
                  ),
                ),
            ],
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Row(
          children: [
            for (var i = 0; i < values.length; i++)
              pw.Expanded(
                child: pw.Center(
                  child: pw.Text(
                    labelAt(i),
                    style: const pw.TextStyle(fontSize: 6, color: _muted),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  pw.Widget _milestoneTable(ChatAnalytics a, _TextPolicy t) => _keyValueTable([
    for (final milestone in a.milestones.take(18))
      (
      '${milestone.date.shortDate} — '
          '${t.decorate(milestone.emoji, milestone.title)}',
      t.plain(milestone.subtitle),
      ),
  ]);

  pw.Widget _wordTable(ChatAnalytics a, _TextPolicy t) {
    final words = a.language.topWords.take(20).toList();
    final emoji = a.emoji;

    // Words are sanitized individually, and any that vanish entirely in
    // Latin-1 mode are dropped rather than printed as an empty gap.
    //
    // `num`, not `int`: NamedValue.value is declared num because the same type
    // carries counts, rates and averages elsewhere in the analytics.
    final printable = <(String, num)>[];
    for (final word in words) {
      final label = t.plain(word.name);
      if (label.isNotEmpty) printable.add((label, word.value));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (printable.isEmpty)
          pw.Text(
            'The most-used words in this chat are written in a script this '
                'report cannot print. See the note below.',
            style: const pw.TextStyle(fontSize: 10, color: _muted),
          )
        else
          pw.Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              for (final word in printable)
                pw.Text(
                  '${word.$1} (${word.$2})',
                  style: const pw.TextStyle(fontSize: 10, color: _ink),
                ),
            ],
          ),
        pw.SizedBox(height: 14),
        if (t.canDrawEmoji && emoji.top.isNotEmpty) ...[
          pw.Text(
            'Most used emoji',
            style: const pw.TextStyle(fontSize: 9, color: _muted),
          ),
          pw.SizedBox(height: 6),
          pw.Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final e in emoji.top.take(12))
                pw.Text(
                  '${e.name} ${e.value}',
                  style: const pw.TextStyle(fontSize: 12, color: _ink),
                ),
            ],
          ),
          pw.SizedBox(height: 14),
        ],
        _keyValueTable([
          ('Unique words', Fmt.n(a.language.uniqueWords)),
          ('Questions asked', Fmt.n(a.language.questionCount)),
          ('Links shared', Fmt.n(a.language.linkCount)),
          ('Emoji sent', Fmt.n(emoji.totalEmojis)),
          (
          'Messages with an emoji',
          Fmt.percent(emoji.emojiRate, decimals: 1),
          ),
          ('Dominant emoji mood', emoji.dominantMood.label),
        ]),
      ],
    );
  }

  String _methodNote(ChatAnalytics a, _TextPolicy t) {
    final method =
        'Reply times are medians, measured only between messages from different '
        'people sent less than three hours apart; longer gaps are treated as a '
        'new conversation rather than a slow reply, and this report is based on '
        '${Fmt.n(a.response.sampleCount)} such pairs. A conversation is counted '
        'as starting when more than six hours have passed since the previous '
        'message. The friendship score is a weighted blend of consistency '
        '(30%), balance (25%), responsiveness (20%), warmth (15%) and volume '
        '(10%); it is an opinion, not a measurement. Word counts exclude common '
        'filler words.';

    if (t.unicode) {
      return t.canDrawEmoji
          ? method
          : '$method No emoji font was bundled with this build, so emoji '
          'characters have been removed from the text above; every other '
          'script renders normally.';
    }

    return '$method This build has no Unicode fonts bundled, so the report '
        'falls back to the standard document fonts, which contain Latin-1 '
        'characters only. Emoji and any non-Latin script have been removed '
        'from the text above rather than printed as empty boxes, and names '
        'that could not be represented appear as "Participant n". The chat '
        'itself is unaffected; see assets/fonts/README.md to enable full '
        'character coverage.';
  }

  static String _slug(String value) {
    final slug = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'chat' : slug;
  }
}

/// Which fonts were available, and therefore which mode the report runs in.
class _Typeset {
  const _Typeset({
    required this.unicode,
    required this.hasEmoji,
    required this.theme,
  });

  /// True when a real Unicode base face was embedded.
  final bool unicode;

  /// True when a monochrome emoji face was embedded as a fallback.
  final bool hasEmoji;

  /// Null in Latin-1 mode, which leaves the `pdf` package on its base-14
  /// default.
  final pw.ThemeData? theme;
}

/// Decides what each user-supplied string may contain before it is drawn.
///
/// In Unicode mode this is close to a no-op. In Latin-1 mode it is the
/// difference between a readable page and a field of boxes.
class _TextPolicy {
  _TextPolicy(this._typeset, List<ParticipantStats> participants) {
    if (_typeset.unicode) return;

    // Names are resolved once, in leaderboard order, so the same person is
    // called the same thing on every page.
    var n = 0;
    for (final person in participants) {
      n++;
      final folded = _fold(person.name);
      _names[person.name] = folded.length >= 2 ? folded : 'Participant $n';
    }
  }

  final _Typeset _typeset;
  final Map<String, String> _names = {};

  bool get unicode => _typeset.unicode;
  bool get canDrawEmoji => _typeset.unicode && _typeset.hasEmoji;

  /// A string of prose or a label.
  String plain(String value) => _typeset.unicode
      ? (_typeset.hasEmoji ? value : EmojiUtils.strip(value))
      : _fold(value);

  /// A participant name, which additionally gets a stable stand-in when it
  /// cannot be represented at all.
  String name(String value) {
    if (_typeset.unicode) return plain(value);
    return _names[value] ?? (_fold(value).length >= 2 ? _fold(value) : value);
  }

  /// Prefixes [label] with [emoji] only when there is a font that can draw it.
  String decorate(String emoji, String label) =>
      canDrawEmoji ? '$emoji  ${plain(label)}' : plain(label);

  /// Folds a string down to what the base-14 fonts can actually print:
  /// pictographs removed, typographic punctuation flattened to ASCII, and
  /// anything outside Latin-1 dropped.
  static String _fold(String value) {
    var out = EmojiUtils.strip(value);
    out = out
        .replaceAll('\u2018', "'")
        .replaceAll('\u2019', "'")
        .replaceAll('\u201C', '"')
        .replaceAll('\u201D', '"')
        .replaceAll('\u2013', '-')
        .replaceAll('\u2014', '-')
        .replaceAll('\u2026', '...')
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u200D', '');

    final buffer = StringBuffer();
    for (final rune in out.runes) {
      // 0x20-0xFF is the printable Latin-1 range the base-14 fonts cover.
      if (rune == 0x0A || (rune >= 0x20 && rune <= 0xFF)) {
        buffer.writeCharCode(rune);
      }
    }

    return buffer
        .toString()
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .trim();
  }
}