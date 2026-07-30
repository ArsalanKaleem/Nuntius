import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/extensions/extensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/glass_card.dart';
import '../../models/chat_report.dart';
import '../../providers/providers.dart';
import '../../routes/app_router.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String? _opening;

  Future<void> _open(ChatReport report) async {
    setState(() => _opening = report.id);
    final session =
    await ref.read(importControllerProvider.notifier).openReport(report);
    if (!mounted) return;
    setState(() => _opening = null);

    if (session == null) {
      final error = ref.read(importControllerProvider).error;
      final missing =
          await ref.read(chatRepositoryProvider).resolvePath(report) == null;
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error ?? 'That chat could not be reopened.',
          ),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          // When the stored copy really is gone, the only useful thing left to
          // do with the entry is clear it, so offer that rather than leaving a
          // row that fails every time it is tapped.
          action: missing
              ? SnackBarAction(
            label: 'Remove',
            textColor: Colors.white,
            onPressed: () =>
                ref.read(reportsProvider.notifier).delete(report.id),
          )
              : null,
        ),
      );
      ref.read(importControllerProvider.notifier).clearError();
      return;
    }
    context.go(Routes.dashboard);
  }

  Future<void> _confirmDelete(ChatReport report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this chat?'),
        content: Text(
          'The copy of ${report.title} stored by Nuntius will be deleted. '
              'Your original export and the chat itself are untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => context.pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await ref.read(reportsProvider.notifier).delete(report.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reports = ref.watch(reportsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Your chats')),
      body: reports.isEmpty
          ? EmptyState(
        title: 'Nothing saved yet',
        message:
        'Chats you import are kept here, on this device only, so you '
            'can open them again without hunting for the file.',
        actionLabel: 'Import a chat',
        onAction: () => context.go(Routes.import),
      )
          : ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        itemCount: reports.length,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ReportCard(
            report: reports[i],
            busy: _opening == reports[i].id,
            onOpen: () => _open(reports[i]),
            onDelete: () => _confirmDelete(reports[i]),
          ),
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.busy,
    required this.onOpen,
    required this.onDelete,
  });

  final ChatReport report;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SurfaceCard(
      onTap: busy ? null : onOpen,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.title,
                  style: theme.textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${Fmt.compact(report.messageCount)} messages · '
                      '${report.participantNames.length} people',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  Fmt.dateRange(report.firstAt, report.lastAt),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Score ${report.friendshipScore.round()}',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: AppColors.accent),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Added ${report.importedAt.shortDate}',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              tooltip: 'Delete',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
    );
  }
}