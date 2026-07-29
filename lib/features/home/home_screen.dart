import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/eyebrow.dart';
import '../../core/widgets/glass_card.dart';
import '../../providers/providers.dart';
import '../../routes/app_router.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reports = ref.watch(reportsProvider);
    final importing = ref.watch(importControllerProvider).busy;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: theme.brightness == Brightness.dark
              ? AppGradients.ambient(AppColors.secondary)
              : null,
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
                  child: Row(
                    children: [
                      const Spacer(),
                      IconButton(
                        onPressed: () => context.push(Routes.settings),
                        icon: const Icon(Icons.settings_outlined),
                        tooltip: 'Settings',
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('Nuntius'),
                      const SizedBox(height: 12),
                      Text('Chat', style: theme.textTheme.displayLarge),
                      Text(
                        'Wrapped',
                        style: theme.textTheme.displayLarge
                            ?.copyWith(color: AppColors.accent),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 320,
                        child: Text(
                          AppInfo.tagline,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      const SizedBox(height: 36),
                      FilledButton.icon(
                        onPressed: importing
                            ? null
                            : () => context.push(Routes.import),
                        icon: const Icon(Icons.file_upload_outlined),
                        label: const Text('Import WhatsApp chat'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => context.push(Routes.reports),
                        icon: const Icon(Icons.folder_outlined),
                        label: Text(
                          reports.isEmpty
                              ? 'Previous reports'
                              : 'Previous reports (${reports.length})',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: importing
                            ? null
                            : () async {
                                final session = await ref
                                    .read(importControllerProvider.notifier)
                                    .importSample();
                                if (session != null && context.mounted) {
                                  context.push(Routes.dashboard);
                                }
                              },
                        icon: const Icon(Icons.play_circle_outline_rounded),
                        label: const Text('Try the sample chat'),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
              if (reports.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader('Pick up where you left off'),
                        for (final report in reports.take(3))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: SurfaceCard(
                              padding: const EdgeInsets.all(16),
                              onTap: () async {
                                final session = await ref
                                    .read(importControllerProvider.notifier)
                                    .openReport(report);
                                if (session != null && context.mounted) {
                                  context.push(Routes.dashboard);
                                }
                              },
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color:
                                          AppColors.accent.withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      report.friendshipScore.round().toString(),
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(color: AppColors.accent),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          report.title,
                                          style: theme.textTheme.titleMedium,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${Fmt.compact(report.messageCount)} '
                                          'messages · '
                                          '${Fmt.dateRange(report.firstAt, report.lastAt)}',
                                          style: theme.textTheme.bodyMedium,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: PrivacyBadge(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
