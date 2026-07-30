import '../../../core/extensions/extensions.dart';
import '../../../models/chat_analytics.dart';
import '../../../models/stat_types.dart';
import '../analysis_context.dart';
import 'streaks.dart';

/// When the chat happens: by hour, weekday, month, year and calendar day.
class ActivityAnalyzer {
  final List<int> _hours = List<int>.filled(24, 0);
  final List<int> _weekdays = List<int>.filled(7, 0);
  final List<int> _months = List<int>.filled(12, 0);
  final Map<int, int> _perDay = {};
  final Map<int, int> _perMonth = {}; // yyyymm
  final Map<int, int> _perYear = {};

  Duration _longestSilence = Duration.zero;
  DateTime? _silenceStart;

  void add(MessageContext ctx) {
    final t = ctx.message.timestamp;
    _hours[t.hour]++;
    _weekdays[t.weekday - 1]++;
    _months[t.month - 1]++;

    final dayKey = t.dayKey;
    _perDay[dayKey] = (_perDay[dayKey] ?? 0) + 1;

    final monthKey = t.year * 100 + t.month;
    _perMonth[monthKey] = (_perMonth[monthKey] ?? 0) + 1;
    _perYear[t.year] = (_perYear[t.year] ?? 0) + 1;

    final gap = ctx.sincePrevious;
    if (gap != null && gap > _longestSilence) {
      _longestSilence = gap;
      _silenceStart = ctx.previous!.timestamp;
    }
  }

  ActivityStats build() {
    final busiestDayKey = _argMax(_perDay);
    final busiestDayCount = busiestDayKey == null ? 0 : _perDay[busiestDayKey]!;

    final monthKeys = _perMonth.keys.toList()..sort();
    final yearKeys = _perYear.keys.toList()..sort();

    return ActivityStats(
      hourHistogram: _hours,
      weekdayHistogram: _weekdays,
      monthHistogram: _months,
      perDay: _perDay,
      monthlyTrend: [
        for (final key in monthKeys)
          TimelinePoint(
            DateTime(key ~/ 100, key % 100),
            _perMonth[key]!,
          ),
      ],
      yearlyTrend: [
        for (final key in yearKeys)
          TimelinePoint(DateTime(key), _perYear[key]!),
      ],
      busiestDay: DateCount(
        busiestDayKey == null
            ? DateTime.now()
            : DateTimeX.fromDayKey(busiestDayKey),
        busiestDayCount,
      ),
      busiestHour: _argMaxIndex(_hours),
      busiestWeekday: _argMaxIndex(_weekdays) + 1,
      busiestMonth: _argMaxIndex(_months) + 1,
      longestStreak: Streaks.longest(_perDay.keys.toSet()),
      currentStreak: Streaks.current(_perDay.keys.toSet()),
      longestSilence: _longestSilence,
      longestSilenceStart: _silenceStart,
    );
  }

  int get activeDays => _perDay.length;

  static int? _argMax(Map<int, int> map) {
    int? best;
    var bestValue = -1;
    map.forEach((key, value) {
      if (value > bestValue) {
        best = key;
        bestValue = value;
      }
    });
    return best;
  }

  static int _argMaxIndex(List<int> values) {
    var best = 0;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > values[best]) best = i;
    }
    return best;
  }
}
