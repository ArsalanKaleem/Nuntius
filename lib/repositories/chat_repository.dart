import 'dart:io';

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
      originalName: chat.sourceName,
    );

    await _box.put(id, report.encode());
    return report;
  }

  /// Resolves the readable path of a saved export, or null when the copy has
  /// gone missing.
  ///
  /// The stored [ChatReport.filePath] is only consulted as a fallback for
  /// reports written by older builds. The live answer comes from the id, since
  /// that is the only part of the location guaranteed to still be valid after
  /// the app is reinstalled or updated.
  Future<String?> resolvePath(ChatReport report) async {
    if (await _files.hasExport(report.id)) {
      return _files.exportPath(report.id);
    }

    // Legacy entries: try the absolute path recorded at import time, and if it
    // still works, leave it be — reopening will succeed and the next save uses
    // the new scheme.
    final legacy = File(report.filePath);
    if (await legacy.exists() && await legacy.length() > 0) {
      return report.filePath;
    }
    return null;
  }

  Future<void> delete(String id) async {
    await _files.deleteExport(id);

    // Older reports may still have a copy at the absolute path they recorded.
    final report = byId(id);
    if (report != null) {
      final legacy = File(report.filePath);
      if (await legacy.exists()) await legacy.delete();
    }

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