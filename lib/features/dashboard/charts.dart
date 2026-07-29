import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';

/// Thin wrappers over fl_chart so the dashboard files stay about the data and
/// the chart configuration lives in one place.
class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({
    super.key,
    required this.values,
    required this.labelAt,
    this.height = 180,
    this.color = AppColors.accent,
    this.highlightIndex,
    this.labelEvery = 1,
  });

  final List<int> values;

  /// Label for the bar at [index]; return an empty string to hide it.
  final String Function(int index) labelAt;
  final double height;
  final Color color;

  /// Drawn in full colour while the rest are dimmed — used for the busiest
  /// hour, day or month.
  final int? highlightIndex;
  final int labelEvery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxValue = values.isEmpty
        ? 1
        : values.reduce((a, b) => a > b ? a : b).clamp(1, 1 << 30);

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: maxValue * 1.15,
          alignment: BarChartAlignment.spaceBetween,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => theme.colorScheme.surface,
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                '${labelAt(group.x)}\n${Fmt.n(rod.toY.round())}',
                theme.textTheme.bodyMedium!
                    .copyWith(color: theme.colorScheme.onSurface),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index % labelEvery != 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      labelAt(index),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(letterSpacing: 0, fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < values.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: values[i].toDouble(),
                    width: 200 / values.length.clamp(1, 40),
                    borderRadius: BorderRadius.circular(4),
                    color: highlightIndex == null || highlightIndex == i
                        ? color
                        : color.withOpacity(0.35),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// The month-by-month relationship timeline.
class TrendLineChart extends StatelessWidget {
  const TrendLineChart({
    super.key,
    required this.values,
    required this.labelAt,
    this.height = 200,
    this.color = AppColors.accent,
  });

  final List<int> values;
  final String Function(int index) labelAt;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (values.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Not enough history for a trend yet.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    final step = (values.length / 5).ceil().clamp(1, values.length);

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: 0,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: theme.colorScheme.outline,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: step.toDouble(),
                getTitlesWidget: (value, meta) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    labelAt(value.round()),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(letterSpacing: 0, fontSize: 10),
                  ),
                ),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => theme.colorScheme.surface,
              getTooltipItems: (spots) => [
                for (final spot in spots)
                  LineTooltipItem(
                    '${labelAt(spot.x.round())}\n${Fmt.n(spot.y.round())}',
                    theme.textTheme.bodyMedium!
                        .copyWith(color: theme.colorScheme.onSurface),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < values.length; i++)
                  FlSpot(i.toDouble(), values[i].toDouble()),
              ],
              isCurved: true,
              curveSmoothness: 0.25,
              barWidth: 3,
              color: color,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color.withOpacity(0.28), color.withOpacity(0)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// GitHub-style calendar heatmap of daily message counts.
class CalendarHeatmap extends StatelessWidget {
  const CalendarHeatmap({
    super.key,
    required this.perDay,
    required this.from,
    required this.to,
    this.color = AppColors.accent,
  });

  /// Day key (yyyymmdd) -> count.
  final Map<int, int> perDay;
  final DateTime from;
  final DateTime to;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = _startOfWeek(DateTime(from.year, from.month, from.day));
    final end = DateTime(to.year, to.month, to.day);
    final weeks = (end.difference(start).inDays / 7).ceil() + 1;

    final maxCount = perDay.values.isEmpty
        ? 1
        : perDay.values.reduce((a, b) => a > b ? a : b);

    const cell = 11.0;
    const gap = 3.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var w = 0; w < weeks; w++)
                Padding(
                  padding: const EdgeInsets.only(right: gap),
                  child: Column(
                    children: [
                      for (var d = 0; d < 7; d++)
                        Builder(
                          builder: (context) {
                            final day = start.add(Duration(days: w * 7 + d));
                            if (day.isAfter(end)) {
                              return const SizedBox(
                                width: cell,
                                height: cell + gap,
                              );
                            }
                            final key =
                                day.year * 10000 + day.month * 100 + day.day;
                            final count = perDay[key] ?? 0;
                            final intensity =
                                count == 0 ? 0.0 : (count / maxCount);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: gap),
                              child: Tooltip(
                                message: '${day.day}/${day.month}/${day.year}'
                                    ' · $count',
                                child: Container(
                                  width: cell,
                                  height: cell,
                                  decoration: BoxDecoration(
                                    // Square-rooted so a single very busy day
                                    // does not flatten the rest to invisible.
                                    color: count == 0
                                        ? theme.colorScheme.outline
                                        : color.withOpacity(
                                            0.18 +
                                                0.82 *
                                                    _curve(intensity),
                                          ),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text('Quiet', style: theme.textTheme.labelSmall),
            const SizedBox(width: 8),
            for (var i = 0; i < 5; i++)
              Padding(
                padding: const EdgeInsets.only(right: 3),
                child: Container(
                  width: cell,
                  height: cell,
                  decoration: BoxDecoration(
                    color: i == 0
                        ? theme.colorScheme.outline
                        : color.withOpacity(0.18 + 0.82 * (i / 4)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Text('Busy', style: theme.textTheme.labelSmall),
          ],
        ),
      ],
    );
  }

  static double _curve(double v) => v <= 0 ? 0 : (v * (2 - v));

  static DateTime _startOfWeek(DateTime date) =>
      date.subtract(Duration(days: date.weekday - 1));
}
