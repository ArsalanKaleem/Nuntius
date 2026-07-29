/// Small shared value types used across the analytics models.

/// A label with a number attached — the shape of almost every leaderboard row,
/// chart bar and "top N" list in the app.
class NamedValue implements Comparable<NamedValue> {
  const NamedValue(this.name, this.value, {this.detail});
  final String name;
  final num value;
  final String? detail;

  @override
  int compareTo(NamedValue other) => other.value.compareTo(value);

  @override
  String toString() => '$name: $value';
}

/// A winner of a "who does X most" award, with the runner-up context that makes
/// the claim feel earned rather than arbitrary.
class Award {
  const Award({
    required this.title,
    required this.winner,
    required this.value,
    required this.blurb,
    this.emoji = '🏆',
  });

  final String title;
  final String winner;
  final String value;
  final String blurb;
  final String emoji;
}

/// A point in the relationship timeline.
class TimelinePoint {
  const TimelinePoint(this.period, this.count, {this.label});
  final DateTime period;
  final int count;
  final String? label;
}

class DateCount {
  const DateCount(this.date, this.count);
  final DateTime date;
  final int count;
}

class Streak {
  const Streak({this.start, this.end, this.days = 0});
  final DateTime? start;
  final DateTime? end;
  final int days;

  static const none = Streak();
  bool get exists => days > 0 && start != null && end != null;
}
