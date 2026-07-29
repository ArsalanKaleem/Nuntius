import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../providers/providers.dart';
import '../../routes/app_router.dart';
import '../reports/pdf_report_service.dart';
import 'tabs/activity_tab.dart';
import 'tabs/moments_tab.dart';
import 'tabs/overview_tab.dart';
import 'tabs/people_tab.dart';
import 'tabs/search_tab.dart';
import 'tabs/words_tab.dart';

/// The dashboard shell.
///
/// The header does not collapse on scroll, and that is deliberate. The first
/// version used a `SliverAppBar` with a `FlexibleSpaceBar` title above a
/// `TabBar`: because the flexible space measures from the bottom of the *whole*
/// app bar, and that includes the tab strip, the chat title was painted on top
/// of the tab labels. Correcting it by hand-tuning `titlePadding` and
/// `expandedHeight` against `kTextTabBarHeight` works right up until a longer
/// chat name, a taller status bar or a different text scale shifts the
/// arithmetic by a few pixels. A fixed header costs about forty pixels of
/// vertical space and cannot collide with anything.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _exporting = false;

  Future<void> _exportPdf() async {
    final session = ref.read(sessionProvider);
    if (session == null) return;
    setState(() => _exporting = true);
    try {
      await const PdfReportService().shareReport(session.analytics);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('The report could not be created. $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final theme = Theme.of(context);

    if (session == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          title: 'No chat open',
          message: 'Import an export to see the numbers behind it.',
          actionLabel: 'Import a chat',
          onAction: () => context.go(Routes.import),
        ),
      );
    }

    final analytics = session.analytics;
    final conversation = analytics.conversation;

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text(analytics.chatTitle, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: 'Export a PDF report',
              onPressed: _exporting ? null : _exportPdf,
              icon: _exporting
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.picture_as_pdf_outlined),
            ),
            IconButton(
              tooltip: 'Open Wrapped',
              onPressed: () => context.push(Routes.wrapped),
              icon: const Icon(Icons.auto_awesome_rounded),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${Fmt.compact(conversation.totalMessages)} messages · '
                      '${Fmt.n(conversation.totalDays)} days · '
                      '${Fmt.dateRange(conversation.firstAt, conversation.lastAt)}',
                  style: theme.textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerColor: theme.colorScheme.outline,
              labelColor: AppColors.accent,
              indicatorColor: AppColors.accent,
              unselectedLabelColor: theme.textTheme.bodyMedium?.color,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Activity'),
                Tab(text: 'People'),
                Tab(text: 'Words'),
                Tab(text: 'Moments'),
                Tab(text: 'Search'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  OverviewTab(analytics: analytics),
                  ActivityTab(analytics: analytics),
                  PeopleTab(analytics: analytics),
                  WordsTab(analytics: analytics),
                  MomentsTab(analytics: analytics),
                  SearchTab(chat: session.chat),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
