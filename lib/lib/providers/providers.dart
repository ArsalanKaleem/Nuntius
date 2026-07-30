import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/file_service.dart';
import '../core/services/import_service.dart';
import '../models/chat_analytics.dart';
import '../models/chat_report.dart';
import '../models/parsed_chat.dart';
import '../repositories/chat_repository.dart';
import '../repositories/settings_repository.dart';

/// Overridden in `main()` once the plugins have initialised, so nothing in the
/// tree ever has to await storage.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override in main()'),
);

final reportsBoxProvider = Provider<Box<String>>(
  (ref) => throw UnimplementedError('Override in main()'),
);

final fileServiceProvider = Provider<FileService>((ref) => const FileService());

final importServiceProvider =
    Provider<ImportService>((ref) => const ImportService());

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(
    ref.watch(reportsBoxProvider),
    ref.watch(fileServiceProvider),
  ),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(sharedPreferencesProvider)),
);

// ---------------------------------------------------------------- settings

class SettingsController extends StateNotifier<AppSettings> {
  SettingsController(this._repo) : super(_repo.read());
  final SettingsRepository _repo;

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _repo.write(state);
  }

  Future<void> setAnimationSpeed(AnimationSpeed speed) async {
    state = state.copyWith(animationSpeed: speed);
    await _repo.write(state);
  }

  Future<void> completeOnboarding() async {
    state = state.copyWith(onboardingComplete: true);
    await _repo.write(state);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsController, AppSettings>(
  (ref) => SettingsController(ref.watch(settingsRepositoryProvider)),
);

/// Multiplier applied to every animation duration in the app.
final animationScaleProvider = Provider<double>(
  (ref) => ref.watch(settingsProvider).animationSpeed.multiplier,
);

// ----------------------------------------------------------------- reports

final reportsProvider =
    StateNotifierProvider<ReportsController, List<ChatReport>>(
  (ref) => ReportsController(ref.watch(chatRepositoryProvider)),
);

class ReportsController extends StateNotifier<List<ChatReport>> {
  ReportsController(this._repo) : super(_repo.all());
  final ChatRepository _repo;

  void refresh() => state = _repo.all();

  Future<void> delete(String id) async {
    await _repo.delete(id);
    refresh();
  }

  Future<void> deleteAll() async {
    await _repo.deleteAll();
    refresh();
  }
}

// ------------------------------------------------------------ live session

/// The chat currently open in the dashboard, Wrapped and report screens.
///
/// Analytics are held in memory for the session rather than serialised: they
/// are cheap to recompute and expensive to keep in sync as the models evolve.
@immutable
class AnalysisSession {
  const AnalysisSession({
    required this.chat,
    required this.analytics,
    this.report,
  });

  final ParsedChat chat;
  final ChatAnalytics analytics;

  /// Null for the sample chat and for previews that were never saved.
  final ChatReport? report;
}

final sessionProvider = StateProvider<AnalysisSession?>((ref) => null);

// -------------------------------------------------------------- import flow

@immutable
class ImportState {
  const ImportState({this.progress, this.error, this.busy = false});
  final ImportProgress? progress;
  final String? error;
  final bool busy;

  static const idle = ImportState();
}

class ImportController extends StateNotifier<ImportState> {
  ImportController(this._ref) : super(ImportState.idle);
  final Ref _ref;

  /// Imports a picked file. [persist] is false for the sample chat, which
  /// should not clutter the saved reports list.
  Future<AnalysisSession?> importFile(
    String path, {
    bool persist = true,
  }) async {
    if (state.busy) return null;
    state = const ImportState(busy: true);
    try {
      final result = await _ref.read(importServiceProvider).import(
            path,
            onProgress: (p) {
              if (mounted) state = ImportState(busy: true, progress: p);
            },
          );

      ChatReport? report;
      if (persist) {
        report = await _ref.read(chatRepositoryProvider).save(
              sourcePath: path,
              chat: result.chat,
              analytics: result.analytics,
            );
        _ref.read(reportsProvider.notifier).refresh();
      }

      final session = AnalysisSession(
        chat: result.chat,
        analytics: result.analytics,
        report: report,
      );
      _ref.read(sessionProvider.notifier).state = session;
      if (mounted) state = ImportState.idle;
      return session;
    } on ChatImportException catch (e) {
      if (mounted) state = ImportState(error: e.message);
      return null;
    } catch (e) {
      if (mounted) {
        state = ImportState(
          error: 'Something went wrong reading that chat. $e',
        );
      }
      return null;
    }
  }

  /// Re-reads and re-analyses a saved report.
  ///
  /// Two things here are about not crashing rather than about reopening:
  ///
  ///  * The re-entrancy guard. Both the home cards and the reports list call
  ///    this from an async `onTap`, and a second tap while the first is still
  ///    running used to spawn a second isolate that raced the first to write
  ///    `sessionProvider` — with the loser's `Isolate.exit` arriving after its
  ///    ports had been torn down.
  ///  * The catch-all. This method previously caught only
  ///    [ChatImportException], so anything else — a missing stored file, a
  ///    permission error, a decode failure — escaped an async callback with no
  ///    handler above it, which on Android takes the process down rather than
  ///    showing an error. It also left `busy` stuck true, disabling the buttons
  ///    for the rest of the session.
  Future<AnalysisSession?> openReport(ChatReport report) async {
    if (state.busy) return null;
    state = const ImportState(busy: true);
    try {
      final result = await _ref.read(importServiceProvider).import(
            report.filePath,
            // Keeps the reopened chat titled the way it was first imported:
            // the stored copy is named after the report id, not the chat.
            displayName: report.originalName,
            onProgress: (p) {
              if (mounted) state = ImportState(busy: true, progress: p);
            },
          );
      final session = AnalysisSession(
        chat: result.chat,
        analytics: result.analytics,
        report: report,
      );
      _ref.read(sessionProvider.notifier).state = session;
      if (mounted) state = ImportState.idle;
      return session;
    } on ChatImportException catch (e) {
      if (mounted) state = ImportState(error: e.message);
      return null;
    } catch (e) {
      if (mounted) {
        state = ImportState(error: 'That chat could not be reopened. $e');
      }
      return null;
    }
  }

  /// Copies the bundled demo export to a temporary file and imports it, so the
  /// sample runs through exactly the same code path as a real chat.
  Future<AnalysisSession?> importSample() async {
    final raw = await rootBundle.loadString('assets/sample/sample_chat.txt');
    final file = await _ref.read(fileServiceProvider).writeTemporary(
          'WhatsApp Chat with Sample Chat.txt',
          utf8.encode(raw), // UTF-8, so the emoji in the sample survive the round trip
        );
    return importFile(file.path, persist: false);
  }

  void clearError() => state = ImportState.idle;
}

final importControllerProvider =
    StateNotifierProvider<ImportController, ImportState>(
  (ref) => ImportController(ref),
);
