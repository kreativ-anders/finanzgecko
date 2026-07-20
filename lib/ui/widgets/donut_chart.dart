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

class AppDonutChart extends StatefulWidget {
  const AppDonutChart({super.key, required this.segments, this.height = 140});

  final List<DonutSegment> segments;
  final double height;

  @override
  State<AppDonutChart> createState() => _AppDonutChartState();
}

class _AppDonutChartState extends State<AppDonutChart> {
  int? _hoverIndex;

  @override
  Widget build(BuildContext context) {
    final positive = widget.segments.where((s) => s.value > 0).toList();
    final total = positive.fold<double>(0, (sum, s) => sum + s.value);

    if (total <= 0) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            'Noch keine Daten.',
            style: TextStyle(color: kMuted, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    final hoverIndex = _hoverIndex;
    final hovered = (hoverIndex != null && hoverIndex < positive.length) ? positive[hoverIndex] : null;

    return Wrap(
      spacing: 24,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: widget.height,
          height: widget.height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: [
                    for (var i = 0; i < positive.length; i++)
                      PieChartSectionData(
                        value: positive[i].value,
                        color: positive[i].color,
                        radius: i == hoverIndex ? 34 : 30,
                        showTitle: false,
                      ),
                  ],
                  centerSpaceRadius: 40,
                  sectionsSpace: 1,
                  // A PieChart's touch resolution is a discrete "which wedge
                  // was hit", not a continuous position — none of the
                  // interpolation drift that made AppLineChart hand-roll its
                  // own hover instead of fl_chart's, so fl_chart's own touch
                  // system is used directly here. The center space left by
                  // centerSpaceRadius doubles as the hovered segment's label.
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      final index = response?.touchedSection?.touchedSectionIndex;
                      final next = (index != null && index >= 0) ? index : null;
                      if (next != _hoverIndex) setState(() => _hoverIndex = next);
                    },
                  ),
                ),
              ),
              if (hovered != null)
                IgnorePointer(
                  child: SizedBox(
                    width: 76,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hovered.label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: kMuted),
                        ),
                        Text(
                          fmtPercent(hovered.value / total * 100),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
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
