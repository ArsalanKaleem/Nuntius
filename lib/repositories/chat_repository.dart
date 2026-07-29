import 'package:hive/hive.dart';

import '../core/constants/app_constants.dart';
import '../core/services/file_service.dart';
import '../models/chat_analytics.dart';
import '../models/chat_report.dart';
import '../models/parsed_chat.dart';

/// Stores imported chats.
///
/// Reports are kept as JSON strings in a Hive box rather than through generated
/// type adapters: the schema is small, it avoids a build_runner step, and it
/// means a new field never breaks an existing install.
class ChatRepository {
  ChatRepository(this._box, this._files);

  final Box<String> _box;
  final FileService _files;

  static Future<Box<String>> openBox() =>
      Hive.openBox<String>(StorageKeys.reportsBox);

  List<ChatReport> all() {
    final reports = <ChatReport>[];
    for (final raw in _box.values) {
      try {
        reports.add(ChatReport.decode(raw));
      } on FormatException {
        // A corrupted entry should not take the whole list down with it.
        continue;
      }
    }
    reports.sort((a, b) => b.importedAt.compareTo(a.importedAt));
    return reports;
  }

  ChatReport? byId(String id) {
    final raw = _box.get(id);
    return raw == null ? null : ChatReport.decode(raw);
  }

  /// Copies the export into app storage and records the headline numbers.
  Future<ChatReport> save({
    required String sourcePath,
    required ParsedChat chat,
    required ChatAnalytics analytics,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final storedPath = await _files.storeExport(sourcePath, id);

    final report = ChatReport(
      id: id,
      title: analytics.chatTitle,
      filePath: storedPath,
      importedAt: DateTime.now(),
      messageCount: analytics.conversation.totalMessages,
      participantNames: chat.participants,
      firstAt: analytics.conversation.firstAt,
      lastAt: analytics.conversation.lastAt,
      sourceBytes: chat.sourceBytes,
      friendshipScore: analytics.scores.friendship,
    );

    await _box.put(id, report.encode());
    return report;
  }

  Future<void> delete(String id) async {
    final report = byId(id);
    if (report != null) await _files.deleteExport(report.filePath);
    await _box.delete(id);
  }

  /// Wipes every imported chat and every stored file. Backs the
  /// "Delete everything" button in Settings.
  Future<void> deleteAll() async {
    await _box.clear();
    await _files.deleteEverything();
  }

  int get count => _box.length;
}
