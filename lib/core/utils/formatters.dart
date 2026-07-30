import 'package:intl/intl.dart';

abstract final class Fmt {
  static final _thousands = NumberFormat.decimalPattern();

  /// 1234 -> "1,234"
  static String n(num value) => _thousands.format(value);

  /// 1234 -> "1.2K". Used where space is tight (Wrapped cards, chips).
  static String compact(num value) {
    if (value.abs() < 1000) return value.toStringAsFixed(0);
    if (value.abs() < 1000000) {
      final v = value / 1000;
      return '${_trim(v)}K';
    }
    if (value.abs() < 1000000000) {
      final v = value / 1000000;
      return '${_trim(v)}M';
    }
    return '${_trim(value / 1000000000)}B';
  }

  static String _trim(double v) {
    final s = v.toStringAsFixed(v.abs() < 10 ? 1 : 0);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  static String percent(double fraction, {int decimals = 1}) =>
      '${(fraction * 100).toStringAsFixed(decimals)}%';

  static String ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    return switch (n % 10) {
      1 => '${n}st',
      2 => '${n}nd',
      3 => '${n}rd',
      _ => '${n}th',
    };
  }

  /// 0 -> "12 AM", 13 -> "1 PM"
  static String hour(int h) {
    final suffix = h < 12 ? 'AM' : 'PM';
    final display = h % 12 == 0 ? 12 : h % 12;
    return '$display $suffix';
  }

  static String hourRange(int h) => '${hour(h)}–${hour((h + 1) % 24)}';

  static const weekdayNames = <String>[
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  static const weekdayShort = <String>[
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  static const monthShort = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// 1-based weekday (DateTime.monday == 1)
  static String weekday(int w) => weekdayNames[(w - 1).clamp(0, 6)];

  /// 1-based month
  static String month(int m) => monthShort[(m - 1).clamp(0, 11)];

  static String bytes(int size) {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// "Jan 4, 2021 – Mar 18, 2024"
  static String dateRange(DateTime from, DateTime to) =>
      '${DateFormat.yMMMd().format(from)} – ${DateFormat.yMMMd().format(to)}';

  /// Shortens a display name so leaderboards do not wrap.
  static String name(String value, {int max = 18}) =>
      value.length <= max ? value : '${value.substring(0, max - 1)}…';
}
