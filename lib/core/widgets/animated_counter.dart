import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../utils/formatters.dart';

/// Counts up to [value] when it first appears.
///
/// Respects both the in-app animation speed setting and the platform
/// "reduce motion" accessibility preference: with either one off, the final
/// number is rendered immediately rather than animated.
class AnimatedCounter extends ConsumerWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.compact = false,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 1400),
    this.curve = Curves.easeOutExpo,
  });

  final num value;
  final TextStyle? style;
  final bool compact;
  final String prefix;
  final String suffix;
  final Duration duration;
  final Curve curve;

  String _format(num v) {
    final body = compact ? Fmt.compact(v) : Fmt.n(v.round());
    return '$prefix$body$suffix';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(animationScaleProvider);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    if (scale == 0 || reduceMotion) {
      return Text(
        _format(value),
        style: style,
        semanticsLabel: '$prefix${Fmt.n(value.round())}$suffix',
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration * scale,
      curve: curve,
      builder: (context, animated, _) => Text(
        _format(animated),
        style: style,
        // Screen readers get the final value straight away — no point reading
        // out a number that is still climbing.
        semanticsLabel: '$prefix${Fmt.n(value.round())}$suffix',
      ),
    );
  }
}
