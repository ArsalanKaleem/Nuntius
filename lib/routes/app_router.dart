import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/dashboard/dashboard_screen.dart';
import '../features/import_chat/import_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/onboarding/splash_screen.dart';
import '../features/home/home_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/wrapped/wrapped_screen.dart';

abstract final class Routes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const import = '/import';
  static const dashboard = '/dashboard';
  static const wrapped = '/wrapped';
  static const reports = '/reports';
  static const settings = '/settings';
}

final appRouter = GoRouter(
  initialLocation: Routes.splash,
  routes: [
    GoRoute(
      path: Routes.splash,
      builder: (_, __) => const SplashScreen(),
    ),
    GoRoute(
      path: Routes.onboarding,
      builder: (_, __) => const OnboardingScreen(),
    ),
    GoRoute(
      path: Routes.home,
      builder: (_, __) => const HomeScreen(),
    ),
    GoRoute(
      path: Routes.import,
      builder: (_, __) => const ImportScreen(),
    ),
    GoRoute(
      path: Routes.dashboard,
      builder: (_, __) => const DashboardScreen(),
    ),
    GoRoute(
      path: Routes.wrapped,
      // Wrapped is a full-screen story, so it comes up from the bottom rather
      // than sliding in like a normal page.
      pageBuilder: (_, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const WrappedScreen(),
        transitionsBuilder: (context, animation, _, child) => SlideTransition(
          position: Tween(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      ),
    ),
    GoRoute(
      path: Routes.reports,
      builder: (_, __) => const ReportsScreen(),
    ),
    GoRoute(
      path: Routes.settings,
      builder: (_, __) => const SettingsScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('That screen does not exist.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go(Routes.home),
              child: const Text('Go home'),
            ),
          ],
        ),
      ),
    ),
  ),
);
