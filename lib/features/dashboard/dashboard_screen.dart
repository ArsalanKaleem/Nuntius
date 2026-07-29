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
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              pinned: true,
              expandedHeight: 178,
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
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsetsDirectional.only(
                  start: 20,
                  bottom: 14,
                  end: 100,
                ),
                title: Text(
                  analytics.chatTitle,
                  style: theme.textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                background: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 92, 20, 54),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${Fmt.compact(conversation.totalMessages)} messages · '
                        '${Fmt.n(conversation.totalDays)} days',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Fmt.dateRange(conversation.firstAt, conversation.lastAt),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              bottom: TabBar(
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
            ),
          ],
          body: TabBarView(
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
      ),
    );
  }
}
