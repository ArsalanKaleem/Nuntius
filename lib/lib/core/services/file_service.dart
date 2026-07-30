import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Owns everything Nuntius writes to disk.
///
/// All of it lives inside the app's private documents directory: on iOS that is
/// the app container, on Android it is app-private internal storage. Nothing is
/// written to shared storage, nothing is uploaded, and [deleteEverything]
/// removes all of it.
class FileService {
  const FileService();

  static const _chatsFolder = 'chats';

  Future<Directory> _chatsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, _chatsFolder));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Copies a picked export into app storage so the report survives the
  /// original file being moved or deleted.
  Future<String> storeExport(String sourcePath, String id) async {
    final dir = await _chatsDir();
    final target = File(p.join(dir.path, '$id.txt'));
    await File(sourcePath).copy(target.path);
    return target.path;
  }

  Future<void> deleteExport(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Future<void> deleteEverything() async {
    final dir = await _chatsDir();
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  Future<int> totalStoredBytes() async {
    final dir = await _chatsDir();
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list()) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  /// Writes a generated file (PDF, PNG, CSV) to a temporary location for the
  /// share sheet. Temporary files are cleaned up by the OS.
  Future<File> writeTemporary(String filename, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, filename));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Copies a picked file's byte stream to a local temporary file and returns
  /// its path.
  ///
  /// This is the bridge for cloud-backed pickers. When the user chooses a file
  /// from Google Drive, OneDrive or another document provider, Android hands
  /// back a `content://` URI rather than a filesystem path, and there may be no
  /// local copy at all until something reads it. `dart:io` cannot open a
  /// content URI, so the file is spooled through here first.
  ///
  /// The copy is written in chunks as they arrive rather than collected into a
  /// list first, so importing a very large chat from Drive does not need the
  /// whole export in memory before parsing has even started.
  Future<File> spoolToTemporary(
      String filename,
      Stream<List<int>> bytes, {
        void Function(int bytesWritten)? onProgress,
      }) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'import-$filename'));
    final sink = file.openWrite();
    var written = 0;
    try {
      await for (final chunk in bytes) {
        sink.add(chunk);
        written += chunk.length;
        onProgress?.call(written);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    return file;
  }
}
