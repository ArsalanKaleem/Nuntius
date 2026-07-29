import '../../models/chat_message.dart';

/// Regular expressions and placeholder tables for reading WhatsApp exports.
///
/// WhatsApp has no documented export format. What it actually produces varies
/// by platform, OS locale and app version, so this file collects the shapes
/// seen in the wild:
///
///   iOS      `[12/03/2023, 21:34:56] Sara: Hello`
///   Android  `12/03/2023, 21:34 - Sara: Hello`
///   US       `3/12/23, 9:34 PM - Sara: Hello`
///   ISO-ish  `2023-03-12, 21:34 - Sara: Hello`
///
/// plus `.` or `-` date separators, optional seconds, a narrow no-break space
/// before AM/PM (newer iOS), an en dash instead of a hyphen, and invisible
/// bidi marks sprinkled through iOS exports.
abstract final class WhatsAppPatterns {
  /// Invisible characters iOS inserts around timestamps and media
  /// placeholders. They break naive matching, so they are stripped up front.
  static final invisibles = RegExp(r'[\u200E\u200F\u202A-\u202E\uFEFF\u2066-\u2069]');

  /// `[12/03/2023, 21:34:56] Sara: Hello`
  static final bracketed = RegExp(
    r'^\[\s*'
    r'(\d{1,4})[./-](\d{1,2})[./-](\d{2,4})'
    r'[,\s]+'
    r'(\d{1,2}):(\d{2})(?::(\d{2}))?'
    r'\s*([APap]\.?\s?[Mm]\.?)?'
    r'\s*\]\s*'
    r'(?:([^:]{1,120}):[ \t]?)?'
    r'([\s\S]*)$',
  );

  /// `12/03/2023, 21:34 - Sara: Hello`
  static final dashed = RegExp(
    r'^'
    r'(\d{1,4})[./-](\d{1,2})[./-](\d{2,4})'
    r'[,\s]+'
    r'(\d{1,2}):(\d{2})(?::(\d{2}))?'
    r'\s*([APap]\.?\s?[Mm]\.?)?'
    r'\s*[-\u2013\u2014]\s*'
    r'(?:([^:]{1,120}):[ \t]?)?'
    r'([\s\S]*)$',
  );

  /// Cheap probe used by the date-order pass. Matching this is much faster
  /// than running a full header regex over every line twice.
  static final datePrefix = RegExp(
    r'^\[?\s*(\d{1,4})[./-](\d{1,2})[./-](\d{2,4})',
  );

  /// Phrases that appear where a sender name would be, in messages that are
  /// actually system notices containing a colon. Without this guard, a line
  /// like "You changed the group description to: ..." invents a participant.
  static final systemSenderGuard = RegExp(
    r'\b(changed|created|added|removed|left|joined|deleted|turned|pinned|'
    r'security code|group description|subject|icon|invite|admin)\b',
    caseSensitive: false,
  );

  /// `<attached: 00000042-PHOTO-2023-03-12.jpg>` (iOS) and
  /// `IMG-20230312-WA0001.jpg (file attached)` (Android).
  static final attached = RegExp(
    r'^<\s*attached:\s*(.+?)\s*>$|^(\S+)\s*\(file attached\)',
    caseSensitive: false,
  );

  /// Ordered table of localised "omitted" placeholders — first match wins, so
  /// specific kinds (voice note) are tested before the generic media line.
  ///
  /// Only placeholder *phrases* live here. File extensions are deliberately
  /// excluded: a normal text message saying "see budget.pdf" is text, not a
  /// document. Extensions are only trusted inside an attachment marker.
  static final List<(RegExp, MessageType)> bodyPatterns = [
    (
      RegExp(r'^(?:this message was deleted|you deleted this message|'
          r'this message was deleted by admin)\.?$', caseSensitive: false),
      MessageType.deleted,
    ),
    (
      RegExp(r'^(?:missed voice call|missed video call|missed group call|'
          r'no answer|call ended|silenced call)', caseSensitive: false),
      MessageType.missedCall,
    ),
    (
      RegExp(r'\b(?:audio|ptt|voice)\s*(?:note|message)?\s*omitted\b|'
          r'\bvoice message omitted\b', caseSensitive: false),
      MessageType.voiceNote,
    ),
    (RegExp(r'\bsticker omitted\b', caseSensitive: false), MessageType.sticker),
    (RegExp(r'\bGIF omitted\b', caseSensitive: false), MessageType.gif),
    (
      RegExp(r'\b(?:image|photo) omitted\b', caseSensitive: false),
      MessageType.image,
    ),
    (RegExp(r'\bvideo omitted\b', caseSensitive: false), MessageType.video),
    (RegExp(r'\baudio omitted\b', caseSensitive: false), MessageType.audio),
    (
      RegExp(r'\bcontact card omitted\b|^contact card$', caseSensitive: false),
      MessageType.contact,
    ),
    (
      RegExp(r'\bdocument omitted\b', caseSensitive: false),
      MessageType.document,
    ),
    (
      RegExp(r'\blive location shared\b', caseSensitive: false),
      MessageType.liveLocation,
    ),
    (
      RegExp(r'^location: https?://|^\u{1F4CD}\s|maps\.google\.[a-z.]+/\?q=',
          caseSensitive: false, unicode: true),
      MessageType.location,
    ),
    (
      RegExp(r'^POLL:|\bcreated a poll\b', caseSensitive: false),
      MessageType.poll,
    ),
    // Generic placeholder, across the locales WhatsApp ships.
    (
      RegExp(r'^<\s*(?:media omitted|medien ausgeschlossen|multimedia omitido|'
          r'archivo omitido|m[e\u00e9]dias? omis|m[i\u00ed]dia oculta|'
          r'media weggelaten|media omessi|multimedia omesso|'
          r'medya atland\u0131)\s*>$', caseSensitive: false),
      MessageType.media,
    ),
  ];

  static final Map<String, MessageType> _extensions = {
    'jpg': MessageType.image, 'jpeg': MessageType.image,
    'png': MessageType.image, 'heic': MessageType.image,
    'webp': MessageType.sticker, 'gif': MessageType.gif,
    'mp4': MessageType.video, 'mov': MessageType.video,
    '3gp': MessageType.video, 'mkv': MessageType.video,
    'avi': MessageType.video,
    'opus': MessageType.voiceNote,
    'mp3': MessageType.audio, 'm4a': MessageType.audio,
    'aac': MessageType.audio, 'wav': MessageType.audio,
    'ogg': MessageType.audio,
    'vcf': MessageType.contact,
    'pdf': MessageType.document, 'doc': MessageType.document,
    'docx': MessageType.document, 'xls': MessageType.document,
    'xlsx': MessageType.document, 'ppt': MessageType.document,
    'pptx': MessageType.document, 'txt': MessageType.document,
    'zip': MessageType.document, 'rar': MessageType.document,
    'csv': MessageType.document, 'apk': MessageType.document,
  };

  static MessageType _byFilename(String filename) {
    final upper = filename.toUpperCase();
    // WhatsApp encodes the kind in the filename on iOS; trust that first
    // because the extension can be generic.
    if (upper.contains('-PHOTO-') || upper.startsWith('IMG-')) {
      return MessageType.image;
    }
    if (upper.contains('-VIDEO-') || upper.startsWith('VID-')) {
      return MessageType.video;
    }
    if (upper.contains('-AUDIO-') || upper.startsWith('PTT-')) {
      return MessageType.voiceNote;
    }
    if (upper.contains('-STICKER-') || upper.startsWith('STK-')) {
      return MessageType.sticker;
    }
    if (upper.contains('-GIF-')) return MessageType.gif;
    if (upper.contains('-DOCUMENT-') || upper.startsWith('DOC-')) {
      return MessageType.document;
    }
    final dot = filename.lastIndexOf('.');
    if (dot != -1 && dot < filename.length - 1) {
      final ext = filename.substring(dot + 1).toLowerCase();
      final type = _extensions[ext];
      if (type != null) return type;
    }
    return MessageType.media;
  }

  /// WhatsApp writes system notices (encryption warnings, "Ali added Sara",
  /// group icon changes) with a timestamp but no `Name:` prefix. The parser
  /// therefore treats any header line without a sender as a system line —
  /// there is no phrase list to keep up to date, so it works in every locale.
  /// Classifies a message body. Returns null for ordinary text.
  static MessageType? classify(String body) {
    if (body.isEmpty) return null;
    final attachment = attached.firstMatch(body);
    if (attachment != null) {
      return _byFilename(attachment.group(1) ?? attachment.group(2) ?? '');
    }
    for (final (pattern, type) in bodyPatterns) {
      if (pattern.hasMatch(body)) return type;
    }
    return null;
  }
}
