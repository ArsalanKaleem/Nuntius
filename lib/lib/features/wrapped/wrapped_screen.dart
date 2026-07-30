import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/empty_state.dart';
import '../../core/widgets/tick_progress.dart';
import '../../providers/providers.dart';
import '../../routes/app_router.dart';
import 'share_sheet.dart';
import 'wrapped_card_view.dart';
import 'wrapped_cards.dart';

/// The Wrapped story: one card per screen, swiped like Stories.
class WrappedScreen extends ConsumerStatefulWidget {
  const WrappedScreen({super.key});

  @override
  ConsumerState<WrappedScreen> createState() => _WrappedScreenState();
}

class _WrappedScreenState extends ConsumerState<WrappedScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Cards are full-bleed gradients; the status bar sits on top of them.
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    if (session == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          title: 'No chat open',
          message: 'Import a chat to see your Wrapped.',
          actionLabel: 'Import a chat',
          onAction: () => context.go(Routes.import),
        ),
      );
    }

    final analytics = session.analytics;
    final cards = WrappedStory.build(analytics);

    // The story drops any card it has no data for, so a chat of a dozen
    // messages can legitimately produce none at all. `clamp(0, -1)` throws, so
    // this used to take the app down rather than say there was nothing to show.
    if (cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          title: 'Not enough here yet',
          message: 'This chat is too short to build a Wrapped from. The '
              'dashboard still has everything that could be measured.',
          actionLabel: 'Back to the dashboard',
          onAction: () => context.pop(),
        ),
      );
    }

    final card = cards[_index.clamp(0, cards.length - 1)];

    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: cards.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => WrappedCardView(
              card: cards[i],
              analytics: analytics,
              active: i == _index,
            ),
          ),

          // Tap the right side to advance, the left to go back — the gesture
          // people already use in Stories. Swiping still works.
          Positioned.fill(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => _jump(-1, cards.length),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => _jump(1, cards.length),
                  ),
                ),
              ],
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white),
                        tooltip: 'Close',
                      ),
                      Expanded(
                        child: TickProgress(
                          count: cards.length,
                          current: _index,
                        ),
                      ),
                      IconButton(
                        onPressed: () => ShareSheet.show(
                          context,
                          card: card,
                          analytics: analytics,
                        ),
                        icon: const Icon(Icons.ios_share_rounded,
                            color: Colors.white),
                        tooltip: 'Share this card',
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (_index == cards.length - 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                            ),
                            onPressed: () => ShareSheet.show(
                              context,
                              card: card,
                              analytics: analytics,
                            ),
                            icon: const Icon(Icons.ios_share_rounded),
                            label: const Text('Share'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                            ),
                            onPressed: () => context.pop(),
                            child: const Text('See the detail'),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _jump(int delta, int count) {
    final target = _index + delta;
    if (target < 0 || target >= count) return;
    _controller.animateToPage(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }
}
