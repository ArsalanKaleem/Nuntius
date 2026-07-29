import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/widgets/tick_progress.dart';
import '../../providers/providers.dart';
import '../../routes/app_router.dart';

class _Page {
  const _Page({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.icon,
    required this.gradient,
  });

  final String eyebrow;
  final String title;
  final String body;
  final IconData icon;
  final LinearGradient gradient;
}

const _pages = <_Page>[
  _Page(
    eyebrow: 'Private by design',
    title: 'Nothing leaves this phone',
    body: 'Nuntius has no account, no server and no network permission. Your '
        'export is read on this device and stays here.',
    icon: Icons.lock_outline_rounded,
    gradient: AppGradients.forest,
  ),
  _Page(
    eyebrow: 'Processed on device',
    title: 'Years of messages, read in seconds',
    body: 'Import the .txt file WhatsApp gives you. Nuntius counts every '
        'message, emoji, reply and silence without uploading a thing.',
    icon: Icons.bolt_rounded,
    gradient: AppGradients.mint,
  ),
  _Page(
    eyebrow: 'Made to share',
    title: 'Your year in one conversation',
    body: 'Swipe through your Wrapped, save the cards you like, and export a '
        'full report when you want the detail.',
    icon: Icons.auto_awesome_rounded,
    gradient: AppGradients.violet,
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(settingsProvider.notifier).completeOnboarding();
    if (mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final page = _pages[_index];
    final isLast = _index == _pages.length - 1;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        decoration: BoxDecoration(gradient: page.gradient),
        child: Stack(
          children: [
            const Positioned.fill(child: FloatingShapes(seed: 3)),
            SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _finish,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                      ),
                      child: const Text('Skip'),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: _pages.length,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (context, i) {
                        final p = _pages[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.16),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Icon(p.icon,
                                    size: 34, color: Colors.white),
                              ),
                              const SizedBox(height: 32),
                              Text(
                                p.eyebrow.toUpperCase(),
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(color: Colors.white70),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                p.title,
                                style: theme.textTheme.displaySmall
                                    ?.copyWith(color: Colors.white),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                p.body,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: Colors.white.withOpacity(0.85),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                    child: Column(
                      children: [
                        TickProgress(
                          count: _pages.length,
                          current: _index,
                          accent: Colors.white,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primaryDark,
                          ),
                          onPressed: () {
                            if (isLast) {
                              _finish();
                            } else {
                              _controller.nextPage(
                                duration: const Duration(milliseconds: 380),
                                curve: Curves.easeOutCubic,
                              );
                            }
                          },
                          child: Text(isLast ? 'Get started' : 'Next'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
