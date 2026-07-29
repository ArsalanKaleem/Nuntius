enum InsightTone { celebratory, curious, playful, warm, factual }

/// A rule-generated line of commentary.
///
/// [weight] decides ordering: the engine produces more insights than the UI
/// shows and the heaviest ones float to the top of the dashboard and into
/// Wrapped. Nothing here calls a network — every line comes from a threshold
/// crossing on a real statistic.
class Insight {
  const Insight({
    required this.text,
    required this.emoji,
    required this.tone,
    this.weight = 1.0,
    this.detail,
  });

  final String text;
  final String emoji;
  final InsightTone tone;
  final double weight;
  final String? detail;
}
