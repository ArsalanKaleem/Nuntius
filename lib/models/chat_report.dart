import 'dart:convert';

/// The persisted index entry for an imported chat.
///
/// Design note: full analytics are **not** serialised. The original export is
/// copied into the app's private documents directory and re-analysed on open
/// (a few hundred milliseconds in an isolate, with a progress indicator). That
/// keeps storage tiny, avoids a large hand-written serialisation layer that
/// would drift from the models, and means a fixed or improved analyzer applies
/// retroactively to every saved chat. Only the headline numbers shown in the
/// reports list are cached here.
class ChatReport {
  const ChatReport({
    required this.id,
    required this.title,
    required this.filePath,
    required this.importedAt,
    required this.messageCount,
    required this.participantNames,
    required this.firstAt,
    required this.lastAt,
    required this.sourceBytes,
    required this.friendshipScore,
  });

  final String id;
  final String title;

  /// Absolute path inside the app's documents directory. Never leaves the app
  /// sandbox and is removed by "Delete everything".
  final String filePath;
  final DateTime importedAt;
  final int messageCount;
  final List<String> participantNames;
  final DateTime firstAt;
  final DateTime lastAt;
  final int sourceBytes;
  final double friendshipScore;

  bool get isGroupChat => participantNames.length > 2;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'filePath': filePath,
        'importedAt': importedAt.toIso8601String(),
        'messageCount': messageCount,
        'participants': participantNames,
        'firstAt': firstAt.toIso8601String(),
        'lastAt': lastAt.toIso8601String(),
        'sourceBytes': sourceBytes,
        'friendshipScore': friendshipScore,
      };

  factory ChatReport.fromJson(Map<String, dynamic> json) => ChatReport(
        id: json['id'] as String,
        title: json['title'] as String,
        filePath: json['filePath'] as String,
        importedAt: DateTime.parse(json['importedAt'] as String),
        messageCount: json['messageCount'] as int,
        participantNames:
            (json['participants'] as List).map((e) => e as String).toList(),
        firstAt: DateTime.parse(json['firstAt'] as String),
        lastAt: DateTime.parse(json['lastAt'] as String),
        sourceBytes: json['sourceBytes'] as int,
        friendshipScore: (json['friendshipScore'] as num).toDouble(),
      );

  String encode() => jsonEncode(toJson());

  static ChatReport decode(String raw) =>
      ChatReport.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
