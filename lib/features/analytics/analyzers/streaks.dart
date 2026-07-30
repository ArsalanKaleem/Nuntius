import '../../../core/extensions/extensions.dart';
import '../../../models/stat_types.dart';

/// Longest and current runs of consecutive active days.
///
/// Works on the set of day keys (yyyymmdd as int) rather than on messages, so
/// the cost is proportional to the number of *days* in the chat, not the
/// number of messages.
abstract final class Streaks {
  static Streak longest(Set<int> dayKeys) {
    if (dayKeys.isEmpty) return Streak.none;
    final days = dayKeys.map((k) => DateTimeX.fromDayKey(k)).toList()..sort();

    var bestLength = 1;
    var bestStart = days.first;
    var bestEnd = days.first;
    var runLength = 1;
    var runStart = days.first;

    for (var i = 1; i < days.length; i++) {
      final expected = days[i - 1].add(const Duration(days: 1));
      if (_isSameCalendarDay(days[i], expected)) {
        runLength++;
      } else {
        runLength = 1;
        runStart = days[i];
      }
      if (runLength > bestLength) {
        bestLength = runLength;
        bestStart = runStart;
        bestEnd = days[i];
      }
    }
    return Streak(start: bestStart, end: bestEnd, days: bestLength);
  }

  /// The run that the chat ended on. Framed as "you talked every day for N
  /// days, right up to the last message" rather than as a live counter,
  /// because an imported export is a snapshot, not a feed.
  static Streak current(Set<int> dayKeys) {
    if (dayKeys.isEmpty) return Streak.none;
    final days = dayKeys.map((k) => DateTimeX.fromDayKey(k)).toList()..sort();
    var length = 1;
    var start = days.last;
    for (var i = days.length - 1; i > 0; i--) {
      final expected = days[i].subtract(const Duration(days: 1));
      if (_isSameCalendarDay(days[i - 1], expected)) {
        length++;
        start = days[i - 1];
      } else {
        break;
      }
    }
    return Streak(start: start, end: days.last, days: length);
  }

  /// Compares by calendar date, ignoring the time component and any DST shift
  /// that `add(Duration(days: 1))` may introduce.
  static bool _isSameCalendarDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
