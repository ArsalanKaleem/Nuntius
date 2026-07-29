import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import '../../features/analytics/analytics_engine.dart';
import '../../features/parser/whatsapp_parser.dart';
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

  /// Largest file accepted. A WhatsApp export without media is plain text, so
  /// 200 MB is far beyond any real chat and well within what the parser can
  /// hold in memory.
  static const maxBytes = 200 * 1024 * 1024;

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
    if (length > maxBytes) {
      throw const ChatImportException(
        'That file is larger than 200 MB. Export the chat without media and '
        'try again.',
        recoverable: false,
      );
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
      port.send(const ImportProgress(ImportPhase.reading, 0));

      final file = File(args.path);
      String raw;
      try {
        raw = await file.readAsString();
      } on FileSystemException {
        Isolate.exit(
          port,
          const ChatImportException('That file could not be opened.'),
        );
      } on FormatException {
        // Not valid UTF-8 — fall back to a lenient decode rather than failing,
        // because some older Android exports carry stray bytes.
        raw = String.fromCharCodes(await file.readAsBytes());
      }

      port.send(const ImportProgress(ImportPhase.parsing, 0.1));

      final chat = const WhatsAppParser().parse(
        raw,
        sourceName: args.path.split(Platform.pathSeparator).last,
        sourceBytes: args.bytes,
        onProgress: (p) => port.send(
          ImportProgress(ImportPhase.parsing, 0.1 + p * 0.5),
        ),
      );

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
    } catch (error) {
      Isolate.exit(
        port,
        ChatImportException('Could not read that chat: $error'),
      );
    }
  }
}

class _WorkerArgs {
  const _WorkerArgs(this.sendPort, this.path, this.bytes);
  final SendPort sendPort;
  final String path;
  final int bytes;
}
