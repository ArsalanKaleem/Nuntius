import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'providers/providers.dart';
import 'repositories/chat_repository.dart';
import 'repositories/settings_repository.dart';
import 'routes/app_router.dart';

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Replaces the grey/red default error box with something readable that
      // also shows the message. Nothing is uploaded — this only makes a failure
      // legible instead of a blank screen, so a bug can actually be reported.
      ErrorWidget.builder = (details) => _FriendlyError(details: details);

      // Everything below is local. There is no network client anywhere in this
      // app, no analytics SDK and no crash reporter — see PRIVACY.md.
      await Hive.initFlutter();
      final reportsBox = await ChatRepository.openBox();
      final prefs = await SharedPreferences.getInstance();

      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      runApp(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            reportsBoxProvider.overrideWithValue(reportsBox),
          ],
          child: const NuntiusApp(),
        ),
      );
    },
    // An error thrown from an async callback — a file read, an isolate, a tap
    // handler that returns a Future — never reaches FlutterError.onError. Left
    // unhandled on Android these terminate the app. Logging keeps the app
    // alive and leaves a trace in `flutter logs` / logcat.
    (error, stack) {
      debugPrint('Uncaught async error: $error');
      debugPrintStack(stackTrace: stack);
    },
  );
}

class NuntiusApp extends ConsumerWidget {
  const NuntiusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final speed = settings.animationSpeed;

    // The animation setting used to be read only by AnimatedCounter, which is
    // why changing it appeared to do nothing: every page transition, progress
    // bar and implicit animation in the app has its own hard-coded duration.
    //
    // `timeDilation` is the framework-wide multiplier those durations pass
    // through, so setting it here makes one choice govern the whole app —
    // including route transitions, which no widget-level setting can reach. It
    // must stay above zero, so "Off" is expressed separately, through the
    // accessibility flag below.
    timeDilation = speed.multiplier <= 0 ? 1.0 : speed.multiplier;

    return MaterialApp.router(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      routerConfig: appRouter,
      builder: (context, child) {
        final media = MediaQuery.of(context);

        // Honour the system text size, but stop runaway scaling from breaking
        // the big-number layouts.
        final scale = media.textScaler.clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.6,
        );

        return MediaQuery(
          data: media.copyWith(
            textScaler: scale,
            // "Off" is expressed as the same flag the OS sets for reduce
            // motion, so a single check covers both and Flutter's own widgets
            // (route transitions, switches, refresh indicators) obey it too.
            disableAnimations:
                media.disableAnimations || speed == AnimationSpeed.off,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

/// Shown in place of any widget that throws while building.
class _FriendlyError extends StatelessWidget {
  const _FriendlyError({required this.details});
  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundDark,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('😕', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 16),
            const Text(
              'Something on this screen could not be drawn',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'The rest of the app is still working — go back and try again.',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
            const SizedBox(height: 18),
            if (kDebugMode)
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    '${details.exception}',
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
