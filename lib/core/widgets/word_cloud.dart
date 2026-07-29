import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/stat_types.dart';
import '../theme/app_colors.dart';

/// A flowing word cloud.
///
/// Deliberately a wrapped flow rather than a spiral-packed cloud: spiral
/// packing looks impressive in a screenshot and terrible on a phone, where the
/// smallest words end up unreadable and rotated. Size and weight still carry
/// the frequency, so the information survives.
class WordCloud extends StatelessWidget {
  const WordCloud({
    super.key,
    required this.words,
    this.maxWords = 40,
    this.onLight = false,
    this.minFontSize = 13,
    this.maxFontSize = 40,
    this.onTap,
  });

  final List<NamedValue> words;
  final int maxWords;
  final bool onLight;
  final double minFontSize;
  final double maxFontSize;
  final void Function(String word)? onTap;

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) {
      return Text(
        'Not enough text to build a word cloud yet.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    final shown = words.take(maxWords).toList();
    final maxCount = shown.first.value.toDouble();
    final minCount = shown.last.value.toDouble();
    final range = math.max(1.0, maxCount - minCount);

    // Shuffled with a fixed seed so the layout is varied but stable: the same
    // chat always produces the same cloud, which matters for shared images.
    final ordered = List<NamedValue>.from(shown)
      ..shuffle(math.Random(shown.length * 31));

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 6,
      children: [
        for (final word in ordered)
          _Word(
            word: word,
            scale: ((word.value - minCount) / range).clamp(0.0, 1.0),
            minFontSize: minFontSize,
            maxFontSize: maxFontSize,
            onLight: onLight,
            onTap: onTap,
          ),
      ],
    );
  }
}

class _Word extends StatelessWidget {
  const _Word({
    required this.word,
    required this.scale,
    required this.minFontSize,
    required this.maxFontSize,
    required this.onLight,
    this.onTap,
  });

  final NamedValue word;
  final double scale;
  final double minFontSize;
  final double maxFontSize;
  final bool onLight;
  final void Function(String word)? onTap;

  @override
  Widget build(BuildContext context) {
    // Square-rooted so the biggest word does not dwarf everything else.
    final size = minFontSize + math.sqrt(scale) * (maxFontSize - minFontSize);
    final weight = scale > 0.6
        ? FontWeight.w800
        : (scale > 0.3 ? FontWeight.w700 : FontWeight.w500);

    final color = onLight
        ? Color.lerp(
            AppColors.greyDark,
            AppColors.primaryDark,
            0.3 + scale * 0.7,
          )!
        : Color.lerp(
            Colors.white.withOpacity(0.55),
            AppColors.accent,
            scale,
          )!;

    final text = Text(
      word.name,
      style: TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: 1.15,
      ),
    );

    return Semantics(
      label: '${word.name}, used ${word.value} times',
      excludeSemantics: true,
      child: onTap == null
          ? text
          : GestureDetector(onTap: () => onTap!(word.name), child: text),
    );
  }
}
