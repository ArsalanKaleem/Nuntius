import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/file_service.dart';
import '../../core/services/image_export_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/eyebrow.dart';
import '../../models/chat_analytics.dart';
import 'wrapped_card_view.dart';
import 'wrapped_cards.dart';

/// Preview-and-share sheet for a single Wrapped card.
///
/// The preview is the real card at the real aspect ratio, so the PNG that gets
/// shared is exactly what is on screen — just rendered at 1080px wide.
class ShareSheet extends ConsumerStatefulWidget {
  const ShareSheet({
    super.key,
    required this.card,
    required this.analytics,
  });

  final WrappedCard card;
  final ChatAnalytics analytics;

  static Future<void> show(
    BuildContext context, {
    required WrappedCard card,
    required ChatAnalytics analytics,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => ShareSheet(card: card, analytics: analytics),
      );

  @override
  ConsumerState<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<ShareSheet> {
  final _boundaryKey = GlobalKey();
  ShareFormat _format = ShareFormat.story;
  bool _working = false;

  Future<void> _share() async {
    setState(() => _working = true);
    try {
      await ImageExportService(const FileService()).share(
        boundaryKey: _boundaryKey,
        format: _format,
        chatTitle: widget.analytics.chatTitle,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('That image could not be created. $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxPreviewHeight = MediaQuery.sizeOf(context).height * 0.46;
    final previewWidth =
        (maxPreviewHeight * _format.aspectRatio).clamp(200.0, 300.0);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader('Share this card'),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: SizedBox(
                    width: previewWidth,
                    height: previewWidth / _format.aspectRatio,
                    child: WrappedCardView(
                      card: widget.card,
                      analytics: widget.analytics,
                      compact: true,
                      // Counters must be settled before capture, so the
                      // preview shows final values rather than animating.
                      active: false,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              children: [
                for (final format in ShareFormat.values)
                  ChoiceChip(
                    label: Text(format.label),
                    selected: _format == format,
                    onSelected: (_) => setState(() => _format = format),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_format.width} × ${_format.height} PNG',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _working ? null : _share,
              icon: _working
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share_rounded),
              label: Text(_working ? 'Preparing' : 'Share image'),
            ),
          ],
        ),
      ),
    );
  }
}
