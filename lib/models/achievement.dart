/// Unlockable badges. Every badge is derived from a threshold on a real stat,
/// and [progress] is kept even when locked so the UI can show how close the
/// chat came.
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.unlocked,
    required this.progress,
    this.holder,
  });

  final String id;
  final String title;
  final String description;
  final String emoji;
  final bool unlocked;

  /// 0..1
  final double progress;

  /// Who earned it, for per-person badges.
  final String? holder;
}
