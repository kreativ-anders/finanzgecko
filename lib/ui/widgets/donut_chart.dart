import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../utils/formatting.dart';
import '../theme.dart';
import 'stacked_area_chart.dart' show ChartLegendItem;

class DonutSegment {
  final String label;
  final double value;
  final Color color;

  const DonutSegment({required this.label, required this.value, required this.color});
}

class AppDonutChart extends StatelessWidget {
  const AppDonutChart({super.key, required this.segments, this.height = 140});

  final List<DonutSegment> segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    final positive = segments.where((s) => s.value > 0).toList();
    final total = positive.fold<double>(0, (sum, s) => sum + s.value);

    if (total <= 0) {
      return SizedBox(
        height: height,
        child: const Center(
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
          width: height,
          height: height,
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
                child: ChartLegendItem(color: s.color, label: s.label, trailing: fmtPercent(s.value / total * 100)),
              ),
          ],
        ),
      ],
    );
  }
}
