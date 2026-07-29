import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/extensions/extensions.dart';
import '../../core/utils/formatters.dart';
import '../../models/chat_analytics.dart';
import '../../models/participant_stats.dart';

/// Builds the printable report.
///
/// Two deliberate constraints, both in service of the app's promise that
/// nothing leaves the device:
///
///  * Fonts are the PDF base-14 set (Helvetica), which every reader has built
///    in. `printing` can fetch Google Fonts for PDFs, but that is a network
///    call, so it is not used here.
///  * Because base-14 fonts have no emoji glyphs, the report describes emoji
///    statistics in words and numbers rather than printing the characters.
///
/// Charts are drawn with plain boxes rather than by rasterising the on-screen
/// fl_chart widgets — the output is vector, prints cleanly, and does not depend
/// on the dashboard being open.
class PdfReportService {
  const PdfReportService();

  static const _green = PdfColor.fromInt(0xFF128C7E);
  static const _accent = PdfColor.fromInt(0xFF25D366);
  static const _ink = PdfColor.fromInt(0xFF10201E);
  static const _muted = PdfColor.fromInt(0xFF6B7676);
  static const _hairline = PdfColor.fromInt(0xFFE2E0DA);

  Future<Uint8List> build(ChatAnalytics a) async {
    final doc = pw.Document(
      title: '${a.chatTitle} — Chat Wrapped',
      author: 'Nuntius',
      creator: 'Nuntius',
    );

    doc.addPage(_coverPage(a));
    doc.addPage(_bodyPages(a));

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

  pw.Page _coverPage(ChatAnalytics a) {
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
              a.chatTitle,
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

  pw.MultiPage _bodyPages(ChatAnalytics a) {
    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(44, 46, 44, 46),
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 18),
              child: pw.Text(
                a.chatTitle,
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
        _participantsTable(a.participants),
        pw.SizedBox(height: 22),

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
                    insight.detail == null
                        ? insight.text
                        : '${insight.text}  (${insight.detail})',
                    style: const pw.TextStyle(fontSize: 10.5, color: _ink),
                  ),
                ),
              ],
            ),
          ),
        pw.SizedBox(height: 22),

        _heading('Timeline'),
        _milestoneTable(a),
        pw.SizedBox(height: 22),

        _heading('Words'),
        _wordTable(a),
        pw.SizedBox(height: 22),

        _heading('Method'),
        pw.Text(
          _methodNote(a),
          style: const pw.TextStyle(fontSize: 9.5, color: _muted, lineSpacing: 3),
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
      ('Friendship score', '${a.scores.friendship.round()} / 100 '
          '(${a.scores.friendshipGrade})'),
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
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      row.$1,
                      style: const pw.TextStyle(fontSize: 10, color: _muted),
                    ),
                  ),
                  pw.Text(
                    row.$2,
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: _ink,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );

  pw.Widget _participantsTable(List<ParticipantStats> people) {
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
            p.name,
            Fmt.n(p.messageCount),
            Fmt.percent(p.share, decimals: 1),
            p.averageWordsPerMessage.toStringAsFixed(1),
            p.medianReply?.humanized ?? '—',
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

  pw.Widget _milestoneTable(ChatAnalytics a) => _keyValueTable([
        for (final milestone in a.milestones.take(18))
          ('${milestone.date.shortDate} — ${milestone.title}',
              milestone.subtitle),
      ]);

  pw.Widget _wordTable(ChatAnalytics a) {
    final words = a.language.topWords.take(20).toList();
    final emoji = a.emoji;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Wrap(
          spacing: 10,
          runSpacing: 4,
          children: [
            for (final word in words)
              pw.Text(
                '${word.name} (${word.value})',
                style: const pw.TextStyle(fontSize: 10, color: _ink),
              ),
          ],
        ),
        pw.SizedBox(height: 14),
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

  String _methodNote(ChatAnalytics a) =>
      'Reply times are medians, measured only between messages from different '
      'people sent less than three hours apart; longer gaps are treated as a '
      'new conversation rather than a slow reply, and this report is based on '
      '${Fmt.n(a.response.sampleCount)} such pairs. A conversation is counted '
      'as starting when more than six hours have passed since the previous '
      'message. The friendship score is a weighted blend of consistency (30%), '
      'balance (25%), responsiveness (20%), warmth (15%) and volume (10%); it '
      'is an opinion, not a measurement. Word counts exclude common filler '
      'words. Emoji characters are omitted from this PDF because the standard '
      'document fonts used here contain no emoji glyphs.';

  static String _slug(String value) {
    final slug = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'chat' : slug;
  }
}
