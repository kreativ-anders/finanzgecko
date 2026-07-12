import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

class ChartPoint {
  final String label;
  final double? value;

  const ChartPoint(this.label, this.value);
}

/// Small, non-interactive line chart mirroring the previous hand-rolled SVG
/// version: gaps (null values) are drawn as real gaps, not connected, and a
/// dashed zero-line appears when values cross zero (e.g. credit accounts).
class AppLineChart extends StatelessWidget {
  const AppLineChart({super.key, required this.points, this.color = kPrimary, this.height = 140, this.filled = false});

  final List<ChartPoint> points;
  final Color color;
  final double height;

  /// Shades the area under the line — used for the dashboard hero chart so
  /// the range reads as a trend rather than a bare line between two points.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final values = points.map((p) => p.value).whereType<double>().toList();
    if (points.isEmpty || values.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('Noch keine Daten.', style: TextStyle(color: kMuted, fontStyle: FontStyle.italic))),
      );
    }

    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final range = (max - min) == 0 ? 1.0 : (max - min);
    final padY = range * 0.12;

    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        points[i].value != null ? FlSpot(i.toDouble(), points[i].value!) : FlSpot.nullSpot,
    ];

    return SizedBox(
      height: height,
      child: Column(
        children: [
          Expanded(
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (points.length - 1).toDouble().clamp(0, double.infinity),
                minY: min - padY,
                maxY: max + padY,
                lineTouchData: const LineTouchData(enabled: false),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(show: false),
                extraLinesData: (min < 0 && max > 0)
                    ? ExtraLinesData(
                        horizontalLines: [
                          HorizontalLine(y: 0, color: kBorder, strokeWidth: 1, dashArray: const [4, 4]),
                        ],
                      )
                    : const ExtraLinesData(),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: color,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    isStrokeJoinRound: true,
                    dotData: FlDotData(
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(radius: 3, color: color, strokeWidth: 0),
                    ),
                    belowBarData: BarAreaData(
                      show: filled,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.0)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(points.first.label, style: const TextStyle(color: kMuted, fontSize: 11)),
              Text(points.last.label, style: const TextStyle(color: kMuted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
