import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import '../../features/analytics/analytics_engine.dart';
import '../../features/parser/whatsapp_parser.dart';
import '../../features/parser/whatsapp_patterns.dart';
import '../../models/chat_analytics.dart';
import '../../models/parsed_chat.dart';

enum ImportPhase { reading, parsing, analyzing, done }

class ImportProgress {
  const ImportProgress(this.phase, this.value);
  final ImportPhase phase;

  /// 0..1 across the whole import, not just the current phase.
  final double value;

  String get label => switch (phase) {
    ImportPhase.reading => 'Reading the file',
    ImportPhase.parsing => 'Reading messages',
    ImportPhase.analyzing => 'Finding patterns',
    ImportPhase.done => 'Done',
  };
}

class ImportResult {
  const ImportResult(this.chat, this.analytics);
  final ParsedChat chat;
  final ChatAnalytics analytics;
}

class ChatImportException implements Exception {
  const ChatImportException(this.message, {this.recoverable = true});
  final String message;
  final bool recoverable;

  @override
  String toString() => message;
}

/// What the import screen shows before committing to a full analysis.
class ChatPreview {
  const ChatPreview({
    required this.fileName,
    required this.bytes,
    required this.looksValid,
    required this.dateOrder,
    required this.participants,
    required this.firstTimestamp,
    required this.sampledMessages,
  });

  final String fileName;
  final int bytes;
  final bool looksValid;
  final DateOrder? dateOrder;

  /// Names found in the sampled portion — usually all of them for a one-to-one
  /// chat, possibly a subset for a large group.
  final List<String> participants;
  final DateTime? firstTimestamp;

  /// How many messages were in the sample, not in the whole file.
  final int sampledMessages;
}

/// Runs parsing and analysis on a background isolate.
///
/// Both steps happen in the *same* isolate: the parsed messages never cross an
/// isolate boundary twice, and the result comes back through `Isolate.exit`,
/// which hands over the memory rather than copying it. On a 250k-message export
/// that is the difference between a smooth progress bar and a stalled one.
class ImportService {
  const ImportService();

  /// There is no size limit.
  ///
  /// The earlier version refused anything over 200 MB, which was a limit
  /// invented to protect a design that read the whole export into one string
  /// with `readAsString`. That is the expensive part: a 200 MB export costs
  /// roughly 400 MB as a Dart string, on top of the messages built from it, and
  /// the string is thrown away immediately afterwards.
  ///
  /// [import] instead streams the file from disk twice — once to decide the date
  /// format, once to build messages — and never holds more than one line of raw
  /// text. Peak memory is now set by the message list alone, which is what the
  /// user actually asked to analyse, so a cap on file size no longer buys
  /// anything. Reading a large file off disk twice costs a second or two and is
  /// reported through [onProgress].
  /// Reads the first chunk of a file to show a preview without paying for a
  /// full parse. A 40 MB export takes a moment; deciding whether the user
  /// picked the right file should not.
  Future<ChatPreview> peek(String path) async {
    final file = File(path);
    final name = path.split(Platform.pathSeparator).last;
    final length = (await file.exists()) ? await file.length() : 0;

    if (length == 0) {
      return ChatPreview(
        fileName: name,
        bytes: 0,
        looksValid: false,
        dateOrder: null,
        participants: const [],
        firstTimestamp: null,
        sampledMessages: 0,
      );
    }

    const sampleBytes = 256 * 1024;
    final raw = await _readHead(file, sampleBytes);

    if (!looksLikeWhatsAppExport(raw)) {
      return ChatPreview(
        fileName: name,
        bytes: length,
        looksValid: false,
        dateOrder: null,
        participants: const [],
        firstTimestamp: null,
        sampledMessages: 0,
      );
    }

    final sample = const WhatsAppParser().parse(raw, sourceName: name);
    return ChatPreview(
      fileName: name,
      bytes: length,
      looksValid: sample.messages.isNotEmpty,
      dateOrder: sample.dateOrder,
      participants: sample.participants,
      firstTimestamp: sample.messages.isEmpty ? null : sample.firstAt,
      sampledMessages: sample.messages.length,
    );
  }

  static Future<String> _readHead(File file, int maxBytes) async {
    final handle = await file.open();
    try {
      final length = await file.length();
      final bytes = await handle.read(maxBytes < length ? maxBytes : length);
      try {
        // allowMalformed, because cutting at a fixed byte offset can slice a
        // multi-byte character in half.
        return const Utf8Decoder(allowMalformed: true).convert(bytes);
      } on FormatException {
        return String.fromCharCodes(bytes);
      }
    } finally {
      await handle.close();
    }
  }

  Future<ImportResult> import(
      String path, {
        void Function(ImportProgress)? onProgress,
      }) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const ChatImportException('That file is no longer available.');
    }
    final length = await file.length();
    if (length == 0) {
      throw const ChatImportException('That file is empty.');
    }
    final receivePort = ReceivePort();
    final errorPort = ReceivePort();
    final completer = Completer<ImportResult>();

    late final StreamSubscription<dynamic> subscription;
    late final StreamSubscription<dynamic> errorSubscription;

    Future<void> cleanUp() async {
      await subscription.cancel();
      await errorSubscription.cancel();
      receivePort.close();
      errorPort.close();
    }

    subscription = receivePort.listen((dynamic message) async {
      switch (message) {
        case ImportProgress p:
          onProgress?.call(p);
        case ImportResult r:
          if (!completer.isCompleted) completer.complete(r);
          await cleanUp();
        case ChatImportException e:
          if (!completer.isCompleted) completer.completeError(e);
          await cleanUp();
      }
    });

    // Catches anything the isolate did not catch itself, so a crash surfaces
    // as a dialog rather than a spinner that never stops.
    errorSubscription = errorPort.listen((dynamic error) async {
      if (!completer.isCompleted) {
        completer.completeError(
          const ChatImportException(
            'Something went wrong while reading that chat. It may be '
                'corrupted or in an unsupported format.',
          ),
        );
      }
      await cleanUp();
    });

    await Isolate.spawn(
      _worker,
      _WorkerArgs(receivePort.sendPort, path, length),
      onError: errorPort.sendPort,
      errorsAreFatal: true,
      debugName: 'nuntius-import',
    );

    return completer.future;
  }

  /// Entry point for the background isolate.
  static Future<void> _worker(_WorkerArgs args) async {
    final port = args.sendPort;
    try {
      final file = File(args.path);
      final name = args.path.split(Platform.pathSeparator).last;
      final total = args.bytes;

      // Pass one: work out whether the export is day-first, month-first or
      // year-first. The probe holds three counters and at most 400 sampled
      // dates, so this pass costs the same on a 2-million-message chat as on a
      // 200-message one.
      port.send(const ImportProgress(ImportPhase.reading, 0));
      final probe = DateOrderProbe();
      await _forEachLine(
        file,
        total: total,
        onLine: probe.add,
        onProgress: (fraction) => port.send(
          ImportProgress(ImportPhase.reading, fraction * 0.25),
        ),
      );

      final warnings = <ParseWarning>[];
      final order = probe.resolve(warnings);

      // Pass two: build the messages.
      port.send(const ImportProgress(ImportPhase.parsing, 0.25));
      final parser = ChatLineParser(
        order: order,
        sourceName: name,
        sourceBytes: total,
        warnings: warnings,
      );
      await _forEachLine(
        file,
        total: total,
        onLine: parser.add,
        onProgress: (fraction) => port.send(
          ImportProgress(ImportPhase.parsing, 0.25 + fraction * 0.35),
        ),
      );

      final chat = parser.finish();

      if (chat.messages.isEmpty) {
        Isolate.exit(
          port,
          const ChatImportException(
            'No messages found. Make sure you picked the .txt file from a '
                'WhatsApp export, not a .zip or a screenshot.',
          ),
        );
      }

      port.send(const ImportProgress(ImportPhase.analyzing, 0.6));

      final analytics = const AnalyticsEngine().analyze(
        chat,
        onProgress: (p) => port.send(
          ImportProgress(ImportPhase.analyzing, 0.6 + p * 0.4),
        ),
      );

      // Hands the result over without copying it.
      Isolate.exit(port, ImportResult(chat, analytics));
    } on FileSystemException {
      Isolate.exit(
        port,
        const ChatImportException(
          'That file could not be opened. If it came from a cloud folder, '
              'download it to the device and try again.',
        ),
      );
    } catch (error) {
      Isolate.exit(
        port,
        ChatImportException('Could not read that chat: $error'),
      );
    }
  }

  /// Streams [file] line by line, calling [onLine] for each.
  ///
  /// Three details matter here:
  ///
  ///  * `Utf8Decoder(allowMalformed: true)` is chunk-aware, so a multi-byte
  ///    character split across two reads is reassembled rather than corrupted,
  ///    and a stray byte from an old Android export replaces itself with U+FFFD
  ///    instead of throwing.
  ///  * Bidi and zero-width marks are stripped here rather than downstream.
  ///    iOS exports begin many lines with U+200E, which would otherwise defeat
  ///    the anchored date patterns that both the probe and the parser rely on.
  ///  * Progress is measured in bytes consumed, not lines seen, because the
  ///    line count is unknown until the file has been read.
  static Future<void> _forEachLine(
      File file, {
        required int total,
        required void Function(String line) onLine,
        required void Function(double fraction) onProgress,
      }) async {
    var bytesSeen = 0;
    var lastReported = -1;

    final lines = file
        .openRead()
        .map((chunk) {
      bytesSeen += chunk.length;
      return chunk;
    })
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter());

    await for (final line in lines) {
      onLine(line.replaceAll(WhatsAppPatterns.invisibles, ''));

      // Throttled to whole percentage points: a 200 MB file has millions of
      // lines, and posting a message per line would cost more than the parse.
      if (total > 0) {
        final percent = (bytesSeen * 100 ~/ total).clamp(0, 100);
        if (percent != lastReported) {
          lastReported = percent;
          onProgress(percent / 100);
        }
      }
    }
    onProgress(1);
  }
}

class _WorkerArgs {
  const _WorkerArgs(this.sendPort, this.path, this.bytes);
  final SendPort sendPort;
  final String path;
  final int bytes;
}
