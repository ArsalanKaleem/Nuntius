/// What a single exported line turned out to be.
///
/// WhatsApp does not tell you the type directly — it writes a localised
/// placeholder such as `<Media omitted>` or `image omitted`, so the parser
/// classifies each body and records the result once. Everything downstream
/// reads this enum instead of re-matching strings.
enum MessageType {
  text,
  image,
  video,
  audio,
  voiceNote,
  sticker,
  gif,
  document,
  contact,
  location,
  liveLocation,
  poll,
  deleted,
  missedCall,
  media, // media of an unknown kind (`<Media omitted>`)
  system; // encryption notice, "X added Y", group icon changes…

  bool get isMedia => switch (this) {
        MessageType.image ||
        MessageType.video ||
        MessageType.audio ||
        MessageType.voiceNote ||
        MessageType.sticker ||
        MessageType.gif ||
        MessageType.document ||
        MessageType.media =>
          true,
        _ => false,
      };

  bool get countsAsMessage => this != MessageType.system;

  String get label => switch (this) {
        MessageType.text => 'Text',
        MessageType.image => 'Photos',
        MessageType.video => 'Videos',
        MessageType.audio => 'Audio',
        MessageType.voiceNote => 'Voice notes',
        MessageType.sticker => 'Stickers',
        MessageType.gif => 'GIFs',
        MessageType.document => 'Documents',
        MessageType.contact => 'Contacts',
        MessageType.location => 'Locations',
        MessageType.liveLocation => 'Live locations',
        MessageType.poll => 'Polls',
        MessageType.deleted => 'Deleted',
        MessageType.missedCall => 'Missed calls',
        MessageType.media => 'Media',
        MessageType.system => 'System',
      };
}

/// One parsed message.
///
/// Deliberately small: a 250k-message export creates 250k of these, so derived
/// values (emoji lists, token lists) are computed during the analytics pass and
/// thrown away rather than cached on every instance.
class ChatMessage {
  const ChatMessage({
    required this.index,
    required this.timestamp,
    required this.sender,
    required this.body,
    required this.type,
  });

  /// Position in the original export, 0-based. Used for milestones and to
  /// restore ordering after filtering.
  final int index;
  final DateTime timestamp;

  /// `null` for system lines, which have no author.
  final String? sender;
  final String body;
  final MessageType type;

  bool get isSystem => type == MessageType.system;
  bool get hasText => type == MessageType.text && body.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'i': index,
        't': timestamp.millisecondsSinceEpoch,
        's': sender,
        'b': body,
        'k': type.index,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        index: json['i'] as int,
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(json['t'] as int),
        sender: json['s'] as String?,
        body: json['b'] as String? ?? '',
        type: MessageType.values[json['k'] as int],
      );

  @override
  String toString() =>
      'ChatMessage(#$index, $timestamp, ${sender ?? "system"}, ${type.name})';
}
