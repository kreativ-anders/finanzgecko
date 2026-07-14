import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../utils/formatting.dart';
import '../theme.dart';

/// One band of a stacked-area chart: a labelled, coloured series with one
/// value per period (bottom-to-top stacking order is the list order).
class StackedSeries {
  final String label;
  final Color color;

  /// One value per period, same length/order as [AppStackedAreaChart.periodLabels].
  final List<double> values;

  const StackedSeries({required this.label, required this.color, required this.values});
}

/// A small stacked-area chart: shows how a total splits across categories over
/// time (e.g. net worth by Kontotyp across months), so allocation drift is
/// visible in a way a single-month snapshot can't show.
///
/// Stacking is done by drawing each series' cumulative line filled to zero,
/// back-to-front (largest cumulative first), so each visible band sits between
/// its own cumulative and the one below it. Values are assumed non-negative
/// (callers clamp), which keeps the stack monotonic.
class AppStackedAreaChart extends StatelessWidget {
  const AppStackedAreaChart({
    super.key,
    required this.periodLabels,
    required this.series,
    this.height = 180,
    this.currency = '',
  });

  final List<String> periodLabels;
  final List<StackedSeries> series;
  final double height;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final n = periodLabels.length;
    final active = series.where((s) => s.values.any((v) => v > 0)).toList();
    if (n < 2 || active.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('Noch keine Daten.', style: TextStyle(color: kMuted, fontStyle: FontStyle.italic)),
        ),
      );
    }

    // Cumulative sums per period: cumulative[j][i] = sum of series 0..j at i.
    final cumulative = <List<double>>[];
    for (var j = 0; j < active.length; j++) {
      final running = <double>[];
      for (var i = 0; i < n; i++) {
        final below = j == 0 ? 0.0 : cumulative[j - 1][i];
        running.add(below + active[j].values[i]);
      }
      cumulative.add(running);
    }

    final totals = cumulative.last;
    final maxY = totals.reduce((a, b) => a > b ? a : b);
    final axisMaxY = maxY <= 0 ? 1.0 : maxY * 1.08;

    // Back-to-front: largest cumulative first so smaller ones paint on top,
    // leaving each band's own colour visible between two cumulative lines.
    final bars = <LineChartBarData>[];
    for (var j = active.length - 1; j >= 0; j--) {
      final color = active[j].color;
      bars.add(
        LineChartBarData(
          spots: [for (var i = 0; i < n; i++) FlSpot(i.toDouble(), cumulative[j][i])],
          isCurved: false,
          color: color,
          barWidth: 1,
          dotData: const FlDotData(show: false),
          // Solid fill via a single-colour gradient — matches AppLineChart's
          // belowBarData usage, which is known to work with this fl_chart.
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0.9)],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (n - 1).toDouble(),
              minY: 0,
              maxY: axisMaxY,
              lineTouchData: const LineTouchData(enabled: false),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(show: false),
              lineBarsData: bars,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(periodLabels.first, style: const TextStyle(color: kMuted, fontSize: 11)),
            Text(periodLabels.last, style: const TextStyle(color: kMuted, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 12),
        // Legend: colour swatch, label, and the latest-period share so the
        // chart is readable without a hover layer.
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (var j = 0; j < active.length; j++) _LegendItem(series: active[j], latest: active[j].values.last, total: totals.last),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.series, required this.latest, required this.total});

  final StackedSeries series;
  final double latest;
  final double total;

  @override
  Widget build(BuildContext context) {
    final share = total > 0 ? latest / total * 100 : 0.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: series.color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(series.label, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 6),
        Text(fmtPercent(share), style: const TextStyle(color: kMuted, fontSize: 12)),
      ],
    );
  }
}
