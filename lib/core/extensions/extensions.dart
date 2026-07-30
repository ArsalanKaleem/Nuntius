import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

extension DateTimeX on DateTime {
  DateTime get dateOnly => DateTime(year, month, day);

  String get shortDate => DateFormat.yMMMd().format(this);
  String get longDate => DateFormat.yMMMMEEEEd().format(this);
  String get monthYear => DateFormat.yMMM().format(this);
  String get timeOfDay => DateFormat.jm().format(this);

  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  /// Key used for the calendar heatmap and per-day tallies.
  int get dayKey => year * 10000 + month * 100 + day;

  static DateTime fromDayKey(int key) =>
      DateTime(key ~/ 10000, (key ~/ 100) % 100, key % 100);
}

extension DurationX on Duration {
  /// "2m 14s", "3h 20m", "4d" — short enough for a stat tile.
  String get humanized {
    if (inSeconds < 60) return '${inSeconds}s';
    if (inMinutes < 60) {
      final s = inSeconds % 60;
      return s == 0 ? '${inMinutes}m' : '${inMinutes}m ${s}s';
    }
    if (inHours < 24) {
      final m = inMinutes % 60;
      return m == 0 ? '${inHours}h' : '${inHours}h ${m}m';
    }
    final h = inHours % 24;
    return h == 0 ? '${inDays}d' : '${inDays}d ${h}h';
  }
}

extension IterableX<T> on Iterable<T> {
  T? get firstOrNullSafe => isEmpty ? null : first;

  Iterable<T> takeUpTo(int n) => length <= n ? this : take(n);
}

extension WidgetX on Widget {
  Widget padded([double all = 20]) =>
      Padding(padding: EdgeInsets.all(all), child: this);

  Widget paddedH([double h = 20]) =>
      Padding(padding: EdgeInsets.symmetric(horizontal: h), child: this);
}
