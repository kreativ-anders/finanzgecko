import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../utils/analysis.dart';
import '../../utils/formatting.dart';
import '../theme.dart';

/// The dashboard's small inline charts (this file, [AppStackedAreaChart])
/// draw their own labels/legends instead of fl_chart's built-in chrome, so
/// all of it is switched off identically in both — shared here rather than
/// each widget repeating the same four properties.
const kChartLineTouchDisabled = LineTouchData(enabled: false);
const kChartGridHidden = FlGridData(show: false);
// FlBorderData's constructor isn't const (unlike its three siblings above).
final kChartBorderHidden = FlBorderData(show: false);
const kChartTitlesHidden = FlTitlesData(show: false);

class ChartPoint {
  final String label;
  final double? value;

  const ChartPoint(this.label, this.value);
}

/// A deterministic forward projection for [AppLineChart]: extend the line
/// [months] steps past the last real point, each step adding [monthlyDelta]
/// (e.g. the current Fixposten net per month). Unlike the least-squares
/// [AppLineChart.showTrend] line, this doesn't fit past noise — it applies a
/// known, explainable monthly rate. [endLabel] is the period shown at the
/// projected endpoint. Takes precedence over [showTrend] when set.
class ChartForecast {
  final double monthlyDelta;
  final int months;
  final String endLabel;

  const ChartForecast({required this.monthlyDelta, required this.months, this.endLabel = ''});
}

/// Small, non-interactive line chart mirroring the previous hand-rolled SVG
/// version: gaps (null values) are drawn as real gaps, not connected, and a
/// dashed zero-line appears when values cross zero (e.g. credit accounts).
class AppLineChart extends StatelessWidget {
  const AppLineChart({
    super.key,
    required this.points,
    this.color = kPrimary,
    this.height = 140,
    this.filled = false,
    this.showMinMax = false,
    this.showTrend = false,
    this.showHover = false,
    this.forecast,
    this.currency = '',
  });

  final List<ChartPoint> points;
  final Color color;
  final double height;

  /// Shades the area under the line — used for the dashboard hero chart so
  /// the range reads as a trend rather than a bare line between two points.
  final bool filled;

  /// Direct-labels the lowest and highest point instead of a full y-axis —
  /// stays lean while still answering "what's the range been".
  final bool showMinMax;

  /// Adds a dashed least-squares trend line, projected one period past the
  /// last real point. Needs at least 2 points; a no-op otherwise. Ignored
  /// when [forecast] is set.
  final bool showTrend;

  /// A deterministic forward projection from a known monthly rate (the
  /// Fixposten net). When set, replaces the [showTrend] regression line.
  final ChartForecast? forecast;

  /// Adds a mouse-hover crosshair + tooltip showing the period and value.
  final bool showHover;

  /// Currency for the min/max and hover labels (fmtMoney); a plain rounded
  /// number if empty.
  final String currency;

  String _fmtValue(double value) => currency.isEmpty ? value.toStringAsFixed(0) : fmtMoney(value, currency);

  @override
  Widget build(BuildContext context) {
    final values = points.map((p) => p.value).whereType<double>().toList();
    if (points.isEmpty || values.isEmpty) {
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

    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);

    var minIndex = -1;
    var maxIndex = -1;
    for (var i = 0; i < points.length; i++) {
      final v = points[i].value;
      if (v == null) continue;
      if (minIndex == -1 || v < points[minIndex].value!) minIndex = i;
      if (maxIndex == -1 || v > points[maxIndex].value!) maxIndex = i;
    }

    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        points[i].value != null ? FlSpot(i.toDouble(), points[i].value!) : FlSpot.nullSpot,
    ];

    // Least-squares regression over (index, value) — the simplest defensible
    // trend for a short, noisy series. Exponential would assume a constant
    // growth rate that net worth (which can be zero or negative) doesn't
    // actually have. x stays the point's original index (gaps keep their
    // real time-distance instead of being compacted away) — see
    // utils/analysis.dart's olsTrend for the shared regression math.
    double? trendSlope;
    double? trendIntercept;
    if (showTrend && forecast == null && values.length >= 2) {
      final xs = <double>[];
      final ys = <double>[];
      for (var i = 0; i < points.length; i++) {
        final v = points[i].value;
        if (v == null) continue;
        xs.add(i.toDouble());
        ys.add(v);
      }
      final fit = olsTrend(xs, ys);
      trendSlope = fit?.slope;
      trendIntercept = fit?.intercept;
    }

    final lastIndex = points.length - 1;

    // Deterministic forward projection from a known monthly rate (the
    // Fixposten net), anchored at the last real value. Takes precedence over
    // the regression trend, which is skipped entirely when a forecast is set.
    final fc = forecast;
    double? lastRealValue;
    for (var i = points.length - 1; i >= 0; i--) {
      if (points[i].value != null) {
        lastRealValue = points[i].value;
        break;
      }
    }
    final useForecast = fc != null && fc.months > 0 && lastRealValue != null;
    final forecastEndX = useForecast ? (lastIndex + fc.months).toDouble() : null;
    final forecastEndValue = useForecast ? lastRealValue + fc.monthlyDelta * fc.months : null;

    final hasTrend = trendSlope != null && trendIntercept != null;
    final projectedX = (lastIndex + 1).toDouble();
    final projectedY = hasTrend ? trendIntercept + trendSlope * projectedX : null;

    var chartMin = min;
    var chartMax = max;
    if (projectedY != null) {
      if (projectedY < chartMin) chartMin = projectedY;
      if (projectedY > chartMax) chartMax = projectedY;
    }
    if (forecastEndValue != null) {
      if (forecastEndValue < chartMin) chartMin = forecastEndValue;
      if (forecastEndValue > chartMax) chartMax = forecastEndValue;
    }
    final range = (chartMax - chartMin) == 0 ? 1.0 : (chartMax - chartMin);
    // Min/max labels need real pixel headroom above/below the line, not just
    // enough to avoid clipping the stroke.
    final padY = range * (showMinMax ? 0.30 : 0.12);

    final mainBar = LineChartBarData(
      spots: spots,
      isCurved: false,
      color: color,
      barWidth: 2.5,
      isStrokeCapRound: true,
      isStrokeJoinRound: true,
      dotData: FlDotData(
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: showMinMax && (index == minIndex || index == maxIndex) ? 4 : 3,
          color: color,
          strokeWidth: 0,
        ),
      ),
      belowBarData: BarAreaData(
        show: filled,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.0)],
        ),
      ),
    );

    // Direction reads at a glance: a flat/noisy line shouldn't claim to be
    // trending, so small moves relative to the observed swing count as neutral.
    Color trendDirectionColor() {
      final totalChange = trendSlope! * lastIndex;
      final threshold = (max - min).abs() * 0.05;
      if (totalChange.abs() <= threshold) return kTrendNeutral;
      return totalChange > 0 ? kTrendUp : kTrendDown;
    }

    final trendColor = hasTrend ? trendDirectionColor() : kTrendNeutral;
    final trendBar = hasTrend
        ? LineChartBarData(
            spots: [FlSpot(0, trendIntercept), FlSpot(projectedX, projectedY!)],
            isCurved: false,
            color: trendColor,
            barWidth: 1.5,
            dashArray: const [3, 4],
            dotData: FlDotData(
              checkToShowDot: (spot, bar) => spot.x == projectedX,
              getDotPainter: (spot, percent, bar, index) =>
                  FlDotCirclePainter(radius: 3, color: kSurface, strokeWidth: 1.5, strokeColor: trendColor),
            ),
          )
        : null;

    // Dashed forward projection driven by the known monthly rate, anchored at
    // the last real point. Direction color mirrors the regression trend logic.
    final forecastColor = useForecast
        ? () {
            final totalChange = fc.monthlyDelta * fc.months;
            final threshold = (max - min).abs() * 0.05;
            if (totalChange.abs() <= threshold) return kTrendNeutral;
            return totalChange > 0 ? kTrendUp : kTrendDown;
          }()
        : kTrendNeutral;
    final forecastBar = useForecast
        ? LineChartBarData(
            spots: [FlSpot(lastIndex.toDouble(), lastRealValue), FlSpot(forecastEndX!, forecastEndValue!)],
            isCurved: false,
            color: forecastColor,
            barWidth: 1.5,
            dashArray: const [3, 4],
            dotData: FlDotData(
              checkToShowDot: (spot, bar) => spot.x == forecastEndX,
              getDotPainter: (spot, percent, bar, index) =>
                  FlDotCirclePainter(radius: 3, color: kSurface, strokeWidth: 1.5, strokeColor: forecastColor),
            ),
          )
        : null;

    final chartMaxX = (useForecast ? forecastEndX! : (hasTrend ? projectedX : lastIndex.toDouble())).clamp(
      0.0,
      double.infinity,
    );
    final axisMinY = chartMin - padY;
    final axisMaxY = chartMax + padY;

    final lineChart = LineChart(
      LineChartData(
        minX: 0,
        maxX: chartMaxX,
        minY: axisMinY,
        maxY: axisMaxY,
        // fl_chart's own touch/tooltip system is intentionally unused — see
        // _HoverLayer below, which handles hover entirely on its own.
        lineTouchData: kChartLineTouchDisabled,
        gridData: kChartGridHidden,
        borderData: kChartBorderHidden,
        titlesData: kChartTitlesHidden,
        extraLinesData: (min < 0 && max > 0)
            ? ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(y: 0, color: kBorder, strokeWidth: 1, dashArray: const [4, 4]),
                ],
              )
            : const ExtraLinesData(),
        lineBarsData: [mainBar, ?trendBar, ?forecastBar],
      ),
    );

    return SizedBox(
      height: height,
      child: Column(
        children: [
          Expanded(
            child: (!showMinMax && !showHover)
                ? lineChart
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final h = constraints.maxHeight;

                      // Direct value labels for the min/max points, placed by
                      // hand (rather than fl_chart's touch-tooltip, which only
                      // ever draws above the spot) so the max label can sit
                      // above the line and the min label below it, each with
                      // its own clear gap instead of crowding the vertex.
                      Positioned label(int index, bool above) {
                        final xFraction = chartMaxX == 0 ? 0.0 : index / chartMaxX;
                        final value = points[index].value!;
                        final yFraction = (axisMaxY - value) / (axisMaxY - axisMinY);
                        final text = _fmtValue(value);
                        const gap = 8.0;
                        const blockHeight = 16.0;
                        final estWidth = text.length * 6.8 + 6;
                        final maxLeft = (w - estWidth).clamp(0.0, w);
                        final left = (xFraction * w - estWidth / 2).clamp(0.0, maxLeft);
                        final maxTop = (h - blockHeight).clamp(0.0, h);
                        final rawTop = above ? yFraction * h - gap - blockHeight : yFraction * h + gap;
                        return Positioned(
                          left: left,
                          top: rawTop.clamp(0.0, maxTop),
                          // So this decorative label never steals a hover
                          // event meant for the chart underneath it.
                          child: IgnorePointer(
                            child: Text(
                              text,
                              style: TextStyle(color: kMuted, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        );
                      }

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(child: lineChart),
                          if (showMinMax) label(maxIndex, true),
                          if (showMinMax && minIndex != maxIndex) label(minIndex, false),
                          // Value at the projected endpoint — the "where do I
                          // land" figure — in the forecast color so it reads as
                          // a projection, not a recorded value. Anchored to the
                          // right edge since the endpoint sits at maxX.
                          if (useForecast)
                            () {
                              final value = forecastEndValue!;
                              final text = _fmtValue(value);
                              final yFraction = (axisMaxY - value) / (axisMaxY - axisMinY);
                              const gap = 8.0;
                              const blockHeight = 16.0;
                              final estWidth = text.length * 6.8 + 6;
                              final left = (w - estWidth).clamp(0.0, w);
                              final maxTop = (h - blockHeight).clamp(0.0, h);
                              final rawTop = yFraction * h - gap - blockHeight;
                              return Positioned(
                                left: left,
                                top: rawTop.clamp(0.0, maxTop),
                                child: IgnorePointer(
                                  child: Text(
                                    text,
                                    style: TextStyle(color: forecastColor, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              );
                            }(),
                          // Painted last so its crosshair/tooltip sit above
                          // everything, including the min/max labels.
                          if (showHover)
                            Positioned.fill(
                              child: _HoverLayer(
                                width: w,
                                height: h,
                                chartMaxX: chartMaxX,
                                lastIndex: lastIndex,
                                axisMinY: axisMinY,
                                axisMaxY: axisMaxY,
                                points: points,
                                fmtValue: _fmtValue,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
          const SizedBox(height: 4),
          if (useForecast)
            Row(
              children: [
                Text(points.first.label, style: TextStyle(color: kMuted, fontSize: 11)),
                Expanded(flex: lastIndex > 0 ? lastIndex : 1, child: const SizedBox()),
                Text(
                  fc.endLabel.isEmpty ? 'Prognose' : '${fc.endLabel} (Prognose)',
                  style: TextStyle(color: kMuted, fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],
            )
          else if (hasTrend)
            Row(
              children: [
                Text(points.first.label, style: TextStyle(color: kMuted, fontSize: 11)),
                Expanded(flex: lastIndex, child: const SizedBox()),
                Text(points.last.label, style: TextStyle(color: kMuted, fontSize: 11)),
                const Expanded(flex: 1, child: SizedBox()),
                Text(
                  'Prognose',
                  style: TextStyle(color: kMuted, fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(points.first.label, style: TextStyle(color: kMuted, fontSize: 11)),
                Text(points.last.label, style: TextStyle(color: kMuted, fontSize: 11)),
              ],
            ),
        ],
      ),
    );
  }
}

/// Mouse-hover crosshair + tooltip for [AppLineChart], built directly on
/// [MouseRegion]/[setState] rather than fl_chart's own touch system — that
/// system routes hover through an implicitly-animated widget tree that
/// turned out to drop hover state unpredictably between nearby positions.
/// This is a few more lines but every state transition is one explicit
/// setState, so it's actually possible to reason about.
class _HoverLayer extends StatefulWidget {
  const _HoverLayer({
    required this.width,
    required this.height,
    required this.chartMaxX,
    required this.lastIndex,
    required this.axisMinY,
    required this.axisMaxY,
    required this.points,
    required this.fmtValue,
  });

  final double width;
  final double height;
  final double chartMaxX;
  final int lastIndex;
  final double axisMinY;
  final double axisMaxY;
  final List<ChartPoint> points;
  final String Function(double) fmtValue;

  @override
  State<_HoverLayer> createState() => _HoverLayerState();
}

class _HoverLayerState extends State<_HoverLayer> {
  int? _hoverIndex;

  void _updateHover(Offset localPosition) {
    if (widget.width <= 0) return;
    final fraction = (localPosition.dx / widget.width).clamp(0.0, 1.0);
    final rawIndex = (fraction * widget.chartMaxX).round();
    final index = rawIndex.clamp(0, widget.lastIndex);
    // Gaps (null values) don't get an indicator — nothing to show.
    final next = widget.points[index].value == null ? null : index;
    if (_hoverIndex != next) setState(() => _hoverIndex = next);
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
    final value = widget.points[index].value!;
    final xFraction = widget.chartMaxX == 0 ? 0.0 : index / widget.chartMaxX;
    final x = xFraction * widget.width;
    final yRange = widget.axisMaxY - widget.axisMinY;
    final yFraction = yRange == 0 ? 0.5 : (widget.axisMaxY - value) / yRange;
    final y = yFraction * widget.height;

    const tooltipWidth = 112.0;
    const gap = 10.0;
    final maxLeft = (widget.width - tooltipWidth).clamp(0.0, widget.width);
    final tooltipLeft = (x - tooltipWidth / 2).clamp(0.0, maxLeft);
    // Flip below the point if there's no room above.
    const estTooltipHeight = 46.0;
    final above = y - gap - estTooltipHeight >= 0;
    final tooltipTop = above ? y - gap - estTooltipHeight : y + gap;

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
            top: tooltipTop.clamp(0.0, (widget.height - estTooltipHeight).clamp(0.0, widget.height)),
            width: tooltipWidth,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                    widget.fmtValue(value),
                    style: TextStyle(color: kTextPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  Text(widget.points[index].label, style: TextStyle(color: kMuted, fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
