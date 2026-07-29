import 'package:flutter/material.dart';

/// A grid whose rows are as tall as their tallest child.
///
/// This exists because `GridView.count` needs a `childAspectRatio`, which fixes
/// every cell to one height decided at build time. Any card whose content is
/// taller than that guess overflows — and card content here is not predictable:
/// a name can be one line or two, an award blurb can wrap differently, and the
/// user's text-scale setting multiplies all of it. Every "BOTTOM OVERFLOWED BY
/// n PIXELS" stripe in this app came from that one guess being wrong.
///
/// Rows are laid out with [IntrinsicHeight] plus [Expanded] children, so each
/// row measures its own content and all cards in that row match the tallest.
/// The trade-off is that intrinsic measurement costs an extra layout pass per
/// row, which is fine for the tens of cards a dashboard tab shows and would not
/// be fine for a long scrolling list.
///
/// Children must not use [Expanded] or [Spacer] internally, since there is no
/// longer a fixed height for them to expand into.
class AutoGrid extends StatelessWidget {
  const AutoGrid({
    super.key,
    required this.children,
    this.columns = 2,
    this.spacing = 12,
    this.runSpacing = 12,
    this.minColumnWidth = 150,
  });

  final List<Widget> children;

  /// Preferred column count. Reduced automatically when the available width
  /// cannot give each column [minColumnWidth] — which is what keeps two-column
  /// cards from crushing on a small phone at a large text scale.
  final int columns;

  final double spacing;
  final double runSpacing;
  final double minColumnWidth;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        var count = columns;
        while (count > 1 &&
            (available - spacing * (count - 1)) / count < minColumnWidth) {
          count--;
        }

        final rows = <Widget>[];
        for (var start = 0; start < children.length; start += count) {
          final end = (start + count).clamp(0, children.length);
          final rowChildren = children.sublist(start, end);

          rows.add(
            Padding(
              padding: EdgeInsets.only(
                bottom: end >= children.length ? 0 : runSpacing,
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < count; i++) ...[
                      if (i > 0) SizedBox(width: spacing),
                      Expanded(
                        // The last row can be short; empty cells keep the
                        // remaining cards at the same width as the rows above
                        // instead of stretching them across the gap.
                        child: i < rowChildren.length
                            ? rowChildren[i]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }

        return Column(children: rows);
      },
    );
  }
}
