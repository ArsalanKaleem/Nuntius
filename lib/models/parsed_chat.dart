import 'chat_message.dart';

/// How the export was formatted. Surfaced in the import preview so a user with
/// an unusual locale can tell at a glance whether the dates were read the way
/// they expect.
enum DateOrder { dayFirst, monthFirst, yearFirst }

class ParseWarning {
  const ParseWarning(this.message, {this.lineNumber, this.sample});
  final String message;
  final int? lineNumber;
  final String? sample;

  @override
  String toString() =>
      lineNumber == null ? message : 'Line $lineNumber: $message';
}

/// The result of reading an export file. Holds every message plus the metadata
/// the import preview shows before the user commits to analysing.
class ParsedChat {
  ParsedChat({
    required this.messages,
    required this.participants,
    required this.dateOrder,
    required this.sourceName,
    required this.sourceBytes,
    required this.skippedLines,
    this.warnings = const [],
  });

  final List<ChatMessage> messages;

  /// Every distinct author, ordered by first appearance.
  final List<String> participants;
  final DateOrder dateOrder;
  final String sourceName;
  final int sourceBytes;

  /// Lines the parser could not attach to any message. A handful is normal
  /// (blank lines); a large number means the format was not recognised.
  final int skippedLines;
  final List<ParseWarning> warnings;

  bool get isEmpty => messages.isEmpty;

  DateTime get firstAt => messages.first.timestamp;
  DateTime get lastAt => messages.last.timestamp;

  /// Group chats get different copy and extra leaderboard rows.
  bool get isGroupChat => participants.length > 2;

  int get messageCount => messages.length;

  Duration get span => lastAt.difference(firstAt);

  ParsedChat copyWith({List<ChatMessage>? messages}) => ParsedChat(
        messages: messages ?? this.messages,
        participants: participants,
        dateOrder: dateOrder,
        sourceName: sourceName,
        sourceBytes: sourceBytes,
        skippedLines: skippedLines,
        warnings: warnings,
      );
}
