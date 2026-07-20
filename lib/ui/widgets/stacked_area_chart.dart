import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../utils/formatting.dart';
import '../theme.dart';
import 'line_chart.dart' show kChartBorderHidden, kChartGridHidden, kChartLineTouchDisabled, kChartTitlesHidden;

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
    this.showHover = false,
  });

  final List<String> periodLabels;
  final List<StackedSeries> series;
  final double height;
  final String currency;

  /// Adds a mouse-hover crosshair + tooltip listing every active series'
  /// value at the hovered period — mirrors [AppLineChart.showHover].
  final bool showHover;

  @override
  Widget build(BuildContext context) {
    final n = periodLabels.length;
    assert(
      series.every((s) => s.values.length == n),
      'StackedSeries.values must have periodLabels.length ($n) entries for each series',
    );
    final active = series.where((s) => s.values.any((v) => v > 0)).toList();
    if (n < 2 || active.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Noch keine Daten.',
            style: TextStyle(color: kMuted, fontStyle: FontStyle.italic),
          ),
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
            gradient: LinearGradient(colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0.9)]),
          ),
        ),
      );
    }

    final chart = LineChart(
      LineChartData(
        minX: 0,
        maxX: (n - 1).toDouble(),
        minY: 0,
        maxY: axisMaxY,
        lineTouchData: kChartLineTouchDisabled,
        gridData: kChartGridHidden,
        borderData: kChartBorderHidden,
        titlesData: kChartTitlesHidden,
        lineBarsData: bars,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: !showHover
              ? chart
              : LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(child: chart),
                      Positioned.fill(
                        child: _StackedHoverLayer(
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          periodLabels: periodLabels,
                          active: active,
                          totals: totals,
                          currency: currency,
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
            Text(periodLabels.first, style: TextStyle(color: kMuted, fontSize: 11)),
            Text(periodLabels.last, style: TextStyle(color: kMuted, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 12),
        // Legend: colour swatch, label, and the latest-period share — stays
        // readable on its own even with showHover off.
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (var j = 0; j < active.length; j++)
              ChartLegendItem(
                color: active[j].color,
                label: active[j].label,
                trailing: fmtPercent(totals.last > 0 ? active[j].values.last / totals.last * 100 : 0.0),
              ),
          ],
        ),
      ],
    );
  }
}

/// Mouse-hover crosshair + multi-series tooltip for [AppStackedAreaChart],
/// built the same way as [AppLineChart]'s own hover layer (`MouseRegion` +
/// `setState`, not fl_chart's touch system — see that file's rationale,
/// which applies here too since this is also a continuous x-position).
/// Unlike the line chart there's no single y-value to anchor to (multiple
/// stacked bands), so the tooltip's vertical position is fixed near the top
/// and only its horizontal position follows the cursor.
class _StackedHoverLayer extends StatefulWidget {
  const _StackedHoverLayer({
    required this.width,
    required this.height,
    required this.periodLabels,
    required this.active,
    required this.totals,
    required this.currency,
  });

  final double width;
  final double height;
  final List<String> periodLabels;
  final List<StackedSeries> active;

  /// Cumulative total per period (same order/length as [periodLabels]) —
  /// the tooltip's per-series share is each series' value at the hovered
  /// period divided by this.
  final List<double> totals;
  final String currency;

  @override
  State<_StackedHoverLayer> createState() => _StackedHoverLayerState();
}

class _StackedHoverLayerState extends State<_StackedHoverLayer> {
  int? _hoverIndex;

  void _updateHover(Offset localPosition) {
    if (widget.width <= 0) return;
    final lastIndex = widget.periodLabels.length - 1;
    final fraction = (localPosition.dx / widget.width).clamp(0.0, 1.0);
    final index = (fraction * lastIndex).round().clamp(0, lastIndex);
    if (_hoverIndex != index) setState(() => _hoverIndex = index);
  }

  void _clearHover() {
    if (_hoverIndex != null) setState(() => _hoverIndex = null);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) => _updateHover(event.localPosition),
      onExit: (_) => _clearHover(),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: _hoverIndex == null ? null : _buildIndicator(_hoverIndex!),
      ),
    );
  }

  Widget _buildIndicator(int index) {
    final lastIndex = widget.periodLabels.length - 1;
    final xFraction = lastIndex == 0 ? 0.0 : index / lastIndex;
    final x = xFraction * widget.width;

    // Only series with a nonzero value at this period are worth listing.
    final rows = widget.active.where((s) => s.values[index] > 0).toList();
    final total = widget.totals[index];

    const tooltipWidth = 220.0;
    const valueColumnWidth = 78.0;
    const percentColumnWidth = 40.0;
    const gap = 10.0;
    final maxLeft = (widget.width - tooltipWidth).clamp(0.0, widget.width);
    final tooltipLeft = (x - tooltipWidth / 2).clamp(0.0, maxLeft);

    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: x - 0.5,
            top: 0,
            bottom: 0,
            width: 1,
            child: Container(color: kMuted.withValues(alpha: 0.35)),
          ),
          Positioned(
            left: tooltipLeft,
            top: gap,
            width: tooltipWidth,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: kBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.periodLabels[index],
                    style: TextStyle(color: kTextPrimary, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  // Value and percent each get a fixed-width, right-aligned
                  // column so both line up across rows regardless of label
                  // length — a bare trailing Text after a flexible label
                  // left a ragged, row-to-row-varying gap instead.
                  for (final s in rows)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(2)),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              s.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: kMuted, fontSize: 11),
                            ),
                          ),
                          SizedBox(
                            width: valueColumnWidth,
                            child: Text(
                              widget.currency.isEmpty
                                  ? s.values[index].toStringAsFixed(0)
                                  : fmtMoney(s.values[index], widget.currency),
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                          SizedBox(
                            width: percentColumnWidth,
                            child: Text(
                              fmtPercent(total > 0 ? s.values[index] / total * 100 : 0.0),
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: kMuted, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A "colour swatch + label + trailing value" row — the compact, hover-free
/// legend shared by the dashboard's small inline charts (this one,
/// [AppDonutChart]) so both present categorical color keys identically.
class ChartLegendItem extends StatelessWidget {
  const ChartLegendItem({super.key, required this.color, required this.label, required this.trailing});

  final Color color;
  final String label;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 6),
        Text(trailing, style: TextStyle(color: kMuted, fontSize: 12)),
      ],
    );
  }
}
