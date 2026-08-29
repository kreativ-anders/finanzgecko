import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../utils/analysis.dart';
import '../../utils/formatting.dart';
import '../theme.dart';

/// Shared fl_chart chrome switches: these charts draw their own labels and legends instead.
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

/// Deterministic forward projection ([monthlyDelta] per step) that takes precedence over [AppLineChart.showTrend].
class ChartForecast {
  final double monthlyDelta;
  final int months;
  final String endLabel;

  const ChartForecast({required this.monthlyDelta, required this.months, this.endLabel = ''});
}

const _kValueLabelStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w600);

/// Real pixel width of [text], measured rather than guessed, so value labels never clip or overlap.
double _measureLabelWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  return painter.width;
}

/// Small line chart: null values stay real gaps, and a dashed zero-line appears when values cross zero.
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

/// Shades the area under the line — used by the dashboard hero chart.
  final bool filled;

/// Direct-labels the lowest and highest point instead of drawing a full y-axis.
  final bool showMinMax;

/// Adds a dashed least-squares trend line one period past the last point; ignored when [forecast] is set.
  final bool showTrend;

/// Deterministic projection from a known monthly rate (the Fixposten net).
  final ChartForecast? forecast;

  /// Adds a mouse-hover crosshair + tooltip showing the period and value.
  final bool showHover;

/// Currency for the min/max and hover labels; a plain rounded number if empty.
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

// INFO: OLS over (index, value); gaps keep their real time-distance, exponential would assume steady growth.
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
// Min/max labels need real pixel headroom above/below the line, not just clearance for the stroke.
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

// A flat or noisy line should not claim a direction, so small moves count as neutral.
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
// Hover is handled by _HoverLayer below, not by fl_chart.
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

// Screen-reader summary standing in for the visual line; the chart itself is excludeSemantics.
    final semanticBuffer = StringBuffer(
      'Verlauf von ${points.first.label} bis ${points.last.label}: '
      'von ${_fmtValue(values.first)} auf ${_fmtValue(values.last)}.',
    );
    if (hasTrend) {
      final totalChange = trendSlope * lastIndex;
      final threshold = (max - min).abs() * 0.05;
      final direction = totalChange.abs() <= threshold ? 'stabil' : (totalChange > 0 ? 'steigend' : 'fallend');
      semanticBuffer.write(' Trend $direction.');
    }
    if (useForecast) {
      semanticBuffer.write(' Prognose: ${_fmtValue(forecastEndValue!)}.');
    }

    return Semantics(
      label: semanticBuffer.toString(),
      excludeSemantics: true,
      child: SizedBox(
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

// Placed by hand: fl_chart tooltips only ever draw above the spot, which crowds the min label.
                        Positioned label(int index, bool above) {
                          final xFraction = chartMaxX == 0 ? 0.0 : index / chartMaxX;
                          final value = points[index].value!;
                          final yFraction = (axisMaxY - value) / (axisMaxY - axisMinY);
                          final text = _fmtValue(value);
                          const gap = 8.0;
                          const blockHeight = 16.0;
                          final estWidth = _measureLabelWidth(context, text, _kValueLabelStyle) + 6;
                          final maxLeft = (w - estWidth).clamp(0.0, w);
                          final left = (xFraction * w - estWidth / 2).clamp(0.0, maxLeft);
                          final maxTop = (h - blockHeight).clamp(0.0, h);
                          final rawTop = above ? yFraction * h - gap - blockHeight : yFraction * h + gap;
                          return Positioned(
                            left: left,
                            top: rawTop.clamp(0.0, maxTop),
// So this decorative label never steals a hover event meant for the chart underneath.
                            child: IgnorePointer(
                              child: Text(text, style: _kValueLabelStyle.copyWith(color: kMuted)),
                            ),
                          );
                        }

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(child: lineChart),
                            if (showMinMax) label(maxIndex, true),
                            if (showMinMax && minIndex != maxIndex) label(minIndex, false),
// In the forecast color so the projected endpoint does not read as a recorded value.
                            if (useForecast)
                              () {
                                final value = forecastEndValue!;
                                final text = _fmtValue(value);
                                final yFraction = (axisMaxY - value) / (axisMaxY - axisMinY);
                                const gap = 8.0;
                                const blockHeight = 16.0;
                                final estWidth = _measureLabelWidth(context, text, _kValueLabelStyle) + 6;
                                final left = (w - estWidth).clamp(0.0, w);
                                final maxTop = (h - blockHeight).clamp(0.0, h);
                                final rawTop = yFraction * h - gap - blockHeight;
                                return Positioned(
                                  left: left,
                                  top: rawTop.clamp(0.0, maxTop),
                                  child: IgnorePointer(
                                    child: Text(text, style: _kValueLabelStyle.copyWith(color: forecastColor)),
                                  ),
                                );
                              }(),
// Painted last so the crosshair and tooltip sit above the min/max labels.
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
      ),
    );
  }
}

/// Hand-built hover for [AppLineChart]: fl_chart dropped hover state unpredictably between nearby positions.
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
