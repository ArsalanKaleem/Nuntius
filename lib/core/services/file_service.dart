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
}
