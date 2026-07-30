import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// One candidate file found inside an archive.
class ArchiveEntry {
  const ArchiveEntry({required this.name, required this.size});

  /// Path as stored in the archive, which may include folders.
  final String name;
  final int size;

  /// Just the file name, for display.
  String get displayName => p.basename(name);
}

class ArchiveException implements Exception {
  const ArchiveException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Opens the `.zip` WhatsApp actually hands you.
///
/// Sharing a chat from WhatsApp produces a zip, not a loose `.txt` — with media
/// it holds the transcript plus every photo, and without media it usually holds
/// a single text file. Making the user unzip it by hand first was an avoidable
/// chore, and on iOS it is genuinely awkward.
///
/// Everything here reads the archive as a stream rather than decoding it into
/// memory. A with-media export can be hundreds of megabytes of photos, but the
/// only thing worth extracting is the one text file inside it, so the images
/// are never materialised — the central directory is read to find the entries,
/// and only the chosen entry's bytes are inflated to disk.
///
/// Targets `archive: ^3.6.1`. The 4.x line renamed these entry points.
class ArchiveService {
  const ArchiveService();

  /// Every local zip file starts with this signature.
  ///
  /// Detection is by content, not by extension, for the same reason the picker
  /// accepts any file: a zip arriving from Drive or a messaging app is often
  /// renamed or has no extension at all.
  static const _zipMagic = [0x50, 0x4B, 0x03, 0x04];

  Future<bool> looksLikeZip(String path) async {
    final file = File(path);
    if (!await file.exists()) return false;

    final handle = await file.open();
    try {
      final head = await handle.read(4);
      if (head.length < 4) return false;
      for (var i = 0; i < 4; i++) {
        if (head[i] != _zipMagic[i]) return false;
      }
      return true;
    } finally {
      await handle.close();
    }
  }

  /// Lists the entries that could plausibly be a chat export.
  ///
  /// Sorted largest first: in a with-media archive the transcript is the only
  /// text file, and in an archive holding several chats the biggest one is
  /// almost always the one being looked for.
  Future<List<ArchiveEntry>> listTextEntries(String zipPath) async {
    final input = InputFileStream(zipPath);
    try {
      final archive = ZipDecoder().decodeBuffer(input);
      final entries = <ArchiveEntry>[];

      for (final file in archive.files) {
        if (!file.isFile) continue;

        final name = file.name;
        final base = p.basename(name);

        // Skip the metadata folders zip tools leave behind, which would
        // otherwise show up as plausible-looking entries.
        if (base.startsWith('.') || name.startsWith('__MACOSX/')) continue;
        if (!base.toLowerCase().endsWith('.txt')) continue;

        entries.add(ArchiveEntry(name: name, size: file.size));
      }

      entries.sort((a, b) => b.size.compareTo(a.size));
      return entries;
    } on ArchiveException {
      rethrow;
    } catch (e) {
      throw ArchiveException(
        'That zip could not be opened. If it is password protected, unzip it '
        'yourself first and pick the text file. ($e)',
      );
    } finally {
      await input.close();
    }
  }

  /// Inflates a single entry to a temporary file and returns it.
  Future<File> extract(String zipPath, String entryName) async {
    final input = InputFileStream(zipPath);
    try {
      final archive = ZipDecoder().decodeBuffer(input);

      for (final file in archive.files) {
        if (!file.isFile || file.name != entryName) continue;

        final dir = await getTemporaryDirectory();

        // Only the base name is used for the output path. An archive can
        // contain entries like `../../somewhere/else.txt`, and joining that
        // onto a directory would write outside it.
        final target = File(p.join(dir.path, 'unzipped-${p.basename(entryName)}'));

        final output = OutputFileStream(target.path);
        try {
          file.writeContent(output);
        } finally {
          await output.close();
        }
        return target;
      }

      throw ArchiveException('That file is no longer inside the zip.');
    } on ArchiveException {
      rethrow;
    } catch (e) {
      throw ArchiveException('That file could not be extracted. ($e)');
    } finally {
      await input.close();
    }
  }
}
