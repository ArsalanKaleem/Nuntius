/// Tunable constants for the analytics engine. Every threshold that would
/// otherwise be a magic number in a analyzer lives here so the numbers the app
/// reports can be explained and adjusted in one place.
abstract final class AnalyticsConfig {
  /// A gap larger than this starts a new "conversation session". Used for
  /// conversation starters/enders and momentum.
  static const sessionGap = Duration(hours: 6);

  /// Replies slower than this are treated as a new conversation, not a reply,
  /// so overnight gaps do not poison the average response time.
  static const maxReplyGap = Duration(hours: 3);

  /// Two messages from the same person further apart than this count as a
  /// double text rather than one thought split over two bubbles.
  static const doubleTextGap = Duration(minutes: 2);

  /// Words shorter than this are ignored by the word cloud.
  static const minWordLength = 3;

  static const topWordCount = 60;
  static const topEmojiCount = 24;
  static const topPhraseCount = 20;

  /// Message-count milestones celebrated in the timeline.
  static const messageMilestones = <int>[
    100, 1000, 5000, 10000, 25000, 50000, 100000, 250000,
  ];
}

abstract final class AppInfo {
  static const name = 'Nuntius';
  static const tagline = 'Discover your conversations like never before.';
  static const privacyLine = 'Your chats never leave your device.';
  static const version = '1.0.0';
}

abstract final class StorageKeys {
  static const reportsBox = 'nuntius_reports';
  static const settingsBox = 'nuntius_settings';
  static const themeMode = 'theme_mode';
  static const animationSpeed = 'animation_speed';
  static const onboardingComplete = 'onboarding_complete';
  static const exportFormat = 'export_format';
}
