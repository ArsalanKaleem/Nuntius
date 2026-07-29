import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/animated_counter.dart';
import '../../core/widgets/confetti.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/tick_progress.dart';
import '../../core/widgets/word_cloud.dart';
import '../../models/chat_analytics.dart';
import '../../providers/providers.dart';
import 'wrapped_cards.dart';

/// Renders one Wrapped card. Shared by the story PageView and the share-image
/// preview, so what gets exported is the same widget the user swiped through.
class WrappedCardView extends ConsumerWidget {
  const WrappedCardView({
    super.key,
    required this.card,
    required this.analytics,
    this.active = true,
    this.compact = false,
  });

  final WrappedCard card;
  final ChatAnalytics analytics;

  /// False while the card is off-screen, so counters and confetti do not fire
  /// before anyone sees them.
  final bool active;

  /// Tighter type for the share-sheet preview.
  final bool compact;

  double get _scale => compact ? 0.62 : 1.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animations = ref.watch(animationScaleProvider) > 0;

    return DecoratedBox(
      decoration: BoxDecoration(gradient: card.gradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FloatingShapes(seed: card.id.hashCode, animate: active && animations),
          if (card.layout == WrappedLayout.score && active && animations)
            const Positioned.fill(child: Confetti()),
          Padding(
            padding: EdgeInsets.all(compact ? 20 : 32),
            child: SafeArea(
              top: !compact,
              bottom: !compact,
              child: _content(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context) {
    final theme = Theme.of(context);
    final eyebrowStyle = theme.textTheme.labelSmall?.copyWith(
      color: Colors.white70,
      fontSize: 11 * _scale,
    );
    final bodyStyle = theme.textTheme.bodyLarge?.copyWith(
      color: Colors.white.withOpacity(0.88),
      fontSize: 16 * _scale,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              card.emoji ?? '💬',
              style: TextStyle(fontSize: 26 * _scale),
            ),
            const Spacer(),
            Text(
              analytics.chatTitle.toUpperCase(),
              style: eyebrowStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        const Spacer(),
        Text(card.eyebrow.toUpperCase(), style: eyebrowStyle),
        SizedBox(height: 12 * _scale),
        _headline(context),
        SizedBox(height: 20 * _scale),
        _detail(context),
        const Spacer(),
        Text(card.body, style: bodyStyle),
        SizedBox(height: 14 * _scale),
        Row(
          children: [
            Text(
              'Nuntius',
              style: eyebrowStyle?.copyWith(color: Colors.white54),
            ),
            const Spacer(),
            Text(
              'Made on device',
              style: eyebrowStyle?.copyWith(color: Colors.white38),
            ),
          ],
        ),
      ],
    );
  }

  Widget _headline(BuildContext context) {
    switch (card.layout) {
      case WrappedLayout.intro:
        return Text(
          card.headline,
          style: AppTypography.wrappedNumeral(46 * _scale),
          maxLines: 3,
        );

      case WrappedLayout.emoji:
        return Text(
          card.value ?? '💬',
          style: TextStyle(fontSize: 110 * _scale),
        );

      case WrappedLayout.score:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AnimatedCounter(
              value: card.numericValue ?? 0,
              style: AppTypography.wrappedNumeral(104 * _scale),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: 14 * _scale),
              child: Text(
                '/100',
                style: AppTypography.wrappedNumeral(28 * _scale)
                    .copyWith(color: Colors.white54),
              ),
            ),
          ],
        );

      case WrappedLayout.stat:
        if (card.numericValue != null) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedCounter(
              value: card.numericValue!,
              style: AppTypography.wrappedNumeral(96 * _scale),
            ),
          );
        }
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            card.value ?? card.headline,
            style: AppTypography.wrappedNumeral(58 * _scale),
          ),
        );

      case WrappedLayout.leaderboard:
      case WrappedLayout.wordCloud:
        return Text(
          card.headline,
          style: AppTypography.wrappedNumeral(40 * _scale),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );
    }
  }

  /// The area under the headline. Most cards leave it empty; the ones that
  /// need a chart, a bar list or a cloud fill it here.
  Widget _detail(BuildContext context) {
    final theme = Theme.of(context);

    switch (card.layout) {
      case WrappedLayout.stat:
        if (card.numericValue != null) {
          return Text(
            card.headline,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white.withOpacity(0.9),
              fontSize: 20 * _scale,
            ),
          );
        }
        return const SizedBox.shrink();

      case WrappedLayout.leaderboard:
        final people = analytics.participants.take(5).toList();
        final top = people.isEmpty ? 1 : people.first.messageCount;
        return Column(
          children: [
            for (final p in people)
              Padding(
                padding: EdgeInsets.only(bottom: 10 * _scale),
                child: Row(
                  children: [
                    SizedBox(
                      width: 92 * _scale,
                      child: Text(
                        Fmt.name(p.name, max: 12),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14 * _scale,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: top == 0 ? 0 : p.messageCount / top,
                          minHeight: 10 * _scale,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation(
                            Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10 * _scale),
                    Text(
                      Fmt.percent(p.share, decimals: 0),
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13 * _scale,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );

      case WrappedLayout.wordCloud:
        return WordCloud(
          words: analytics.language.topWords,
          maxWords: compact ? 22 : 32,
          minFontSize: 12 * _scale,
          maxFontSize: 34 * _scale,
        );

      case WrappedLayout.score:
        return GlassCard(
          blur: false,
          padding: EdgeInsets.all(16 * _scale),
          child: Column(
            children: [
              _ScoreRow(
                label: 'Consistency',
                value: analytics.scores.consistency,
                scale: _scale,
              ),
              _ScoreRow(
                label: 'Balance',
                value: analytics.scores.balance,
                scale: _scale,
              ),
              _ScoreRow(
                label: 'Responsiveness',
                value: analytics.scores.responsiveness,
                scale: _scale,
              ),
              _ScoreRow(
                label: 'Warmth',
                value: analytics.scores.warmth,
                scale: _scale,
                last: true,
              ),
            ],
          ),
        );

      case WrappedLayout.intro:
      case WrappedLayout.emoji:
        return const SizedBox.shrink();
    }
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.label,
    required this.value,
    required this.scale,
    this.last = false,
  });

  final String label;
  final double value;
  final double scale;
  final bool last;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : 12 * scale),
        child: Row(
          children: [
            SizedBox(
              width: 116 * scale,
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12 * scale,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (value / 100).clamp(0.0, 1.0),
                  minHeight: 7 * scale,
                  backgroundColor: Colors.white24,
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.lightGreen),
                ),
              ),
            ),
            SizedBox(width: 10 * scale),
            SizedBox(
              width: 30 * scale,
              child: Text(
                value.round().toString(),
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12 * scale,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}
