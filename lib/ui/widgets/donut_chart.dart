import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

class DonutSegment {
  final String label;
  final double value;
  final Color color;

  const DonutSegment({required this.label, required this.value, required this.color});
}

class AppDonutChart extends StatelessWidget {
  const AppDonutChart({super.key, required this.segments});

  final List<DonutSegment> segments;

  @override
  Widget build(BuildContext context) {
    final positive = segments.where((s) => s.value > 0).toList();
    final total = positive.fold<double>(0, (sum, s) => sum + s.value);

    if (total <= 0) {
      return const SizedBox(
        height: 140,
        child: Center(
          child: Text(
            'Noch keine Daten.',
            style: TextStyle(color: kMuted, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 24,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: PieChart(
            PieChartData(
              sections: [
                for (final s in positive)
                  PieChartSectionData(value: s.value, color: s.color, radius: 30, showTitle: false),
              ],
              centerSpaceRadius: 40,
              sectionsSpace: 1,
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in positive)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${s.label} — ${((s.value / total) * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
