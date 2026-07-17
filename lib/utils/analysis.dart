/// Pure, UI-free analysis helpers for the dashboard and capture screens.
///
/// Everything here is deterministic and side-effect free so it can be unit
/// tested without a Flutter binding (see test/analysis_test.dart). The widgets
/// delegate their math here rather than computing inline.
library;

/// Whole calendar months from period [a] to [b], both "YYYY-MM".
/// Negative if [b] precedes [a].
int monthsBetweenPeriods(String a, String b) {
  final pa = a.split('-');
  final pb = b.split('-');
  return (int.parse(pb[0]) - int.parse(pa[0])) * 12 + (int.parse(pb[1]) - int.parse(pa[1]));
}

/// Months from [period] ("YYYY-MM") to the end of its calendar year. December
/// has nowhere to go within the year, so it returns a full 12 (project a year
/// ahead) rather than 0.
int monthsToYearEnd(String period) {
  final remaining = 12 - int.parse(period.split('-')[1]);
  return remaining <= 0 ? 12 : remaining;
}

/// [period] ("YYYY-MM") advanced by [months] (year rollover handled by
/// [DateTime]'s own month-overflow normalization).
String addMonthsToPeriod(String period, int months) {
  final parts = period.split('-');
  final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]) + months);
  return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}';
}

/// Ordinary least-squares fit of [ys] against [xs] (same length, x need not be
/// contiguous — a gap in the series is just a larger step between two x
/// values). Null with fewer than two points or a degenerate fit. The general
/// form behind [trendSlopePerMonth]; also used directly wherever the caller's
/// x-axis isn't a plain 0..n-1 index (e.g. a chart with gaps).
({double slope, double intercept})? olsTrend(List<double> xs, List<double> ys) {
  final n = xs.length;
  if (n < 2) return null;
  var xMean = 0.0;
  var yMean = 0.0;
  for (var i = 0; i < n; i++) {
    xMean += xs[i];
    yMean += ys[i];
  }
  xMean /= n;
  yMean /= n;
  var numerator = 0.0;
  var denominator = 0.0;
  for (var i = 0; i < n; i++) {
    final dx = xs[i] - xMean;
    numerator += dx * (ys[i] - yMean);
    denominator += dx * dx;
  }
  if (denominator == 0) return null;
  final slope = numerator / denominator;
  return (slope: slope, intercept: yMean - slope * xMean);
}

/// Ordinary least-squares slope (change per step) of [values] against their
/// indices 0..n-1 — the observed per-month trend. Null with fewer than two
/// values or a degenerate fit.
double? trendSlopePerMonth(List<double> values) =>
    olsTrend([for (var i = 0; i < values.length; i++) i.toDouble()], values)?.slope;

/// Blends a statistical [trendRate] with a [planRate] prior (the Fixposten
/// net). The trend is primary; the plan only stabilizes small samples and its
/// weight decays as [trendPoints] grows past [priorStrength]. The plan is NOT
/// added to the trend (that would double-count the recurring part the trend
/// already contains) — both are estimates of the same monthly rate. Returns
/// null when neither basis is available.
double? projectionRate({double? planRate, double? trendRate, required int trendPoints, double priorStrength = 3}) {
  if (trendRate != null && planRate != null) {
    final wTrend = trendPoints / (trendPoints + priorStrength);
    return wTrend * trendRate + (1 - wTrend) * planRate;
  }
  return trendRate ?? planRate;
}

/// Splits a net-worth change [delta] into the part explained by planned
/// contributions ([monthlyNet] × [monthGap]) and the residual attributed to
/// market/other movement. Both are estimates.
({double contributions, double market}) contributionMarketSplit({
  required double delta,
  required double monthlyNet,
  required int monthGap,
}) {
  final contributions = monthlyNet * monthGap;
  return (contributions: contributions, market: delta - contributions);
}

/// True when [entered] is at least 10× larger or smaller than [previous] — the
/// signature of a mistyped digit. False when either side is zero (no basis).
bool isBalanceAnomaly(double entered, double previous) {
  if (entered == 0 || previous == 0) return false;
  final ratio = entered.abs() / previous.abs();
  return ratio >= 10 || ratio <= 0.1;
}

/// A single month-over-month change, tagged with the later period.
class MonthChange {
  final String period;
  final double delta;

  const MonthChange(this.period, this.delta);
}

/// Summary statistics over a net-worth time series.
class NetWorthStats {
  /// Largest month-over-month gain (or least-negative change).
  final MonthChange best;

  /// Largest month-over-month loss (or least-positive change).
  final MonthChange worst;

  /// Mean of all month-over-month changes.
  final double averageChange;

  /// Number of months whose change was strictly positive.
  final int monthsUp;

  /// Total number of month-over-month changes considered.
  final int changeCount;

  /// Change from the first recorded total to the last (net growth so far).
  final double totalGrowth;

  /// The first recorded period, i.e. what [totalGrowth] is measured from.
  final String startPeriod;

  /// Highest total ever recorded, and the period it occurred in.
  final double peak;
  final String peakPeriod;

  /// The most recent total in the series.
  final double current;

  const NetWorthStats({
    required this.best,
    required this.worst,
    required this.averageChange,
    required this.monthsUp,
    required this.changeCount,
    required this.totalGrowth,
    required this.startPeriod,
    required this.peak,
    required this.peakPeriod,
    required this.current,
  });

  /// Share of considered months that grew, in 0..1.
  double get upShare => changeCount == 0 ? 0 : monthsUp / changeCount;

  /// How far the current total sits below the all-time high, in 0..1 (0 = at
  /// the peak). Zero when the peak is non-positive (no meaningful reference).
  double get drawdownFromPeak => peak > 0 ? ((peak - current) / peak).clamp(0.0, 1.0).toDouble() : 0.0;
}

/// Computes [NetWorthStats] from a period-ordered [series] of totals. Returns
/// null with fewer than two points (no change to measure). [series] is assumed
/// sorted ascending by period.
NetWorthStats? computeNetWorthStats(List<({String period, double total})> series) {
  if (series.length < 2) return null;
  MonthChange? best;
  MonthChange? worst;
  var sum = 0.0;
  var monthsUp = 0;
  var count = 0;
  var peak = series.first.total;
  var peakPeriod = series.first.period;
  for (var i = 1; i < series.length; i++) {
    final delta = series[i].total - series[i - 1].total;
    final change = MonthChange(series[i].period, delta);
    sum += delta;
    count++;
    if (delta > 0) monthsUp++;
    if (best == null || delta > best.delta) best = change;
    if (worst == null || delta < worst.delta) worst = change;
    if (series[i].total > peak) {
      peak = series[i].total;
      peakPeriod = series[i].period;
    }
  }
  return NetWorthStats(
    best: best!,
    worst: worst!,
    averageChange: sum / count,
    monthsUp: monthsUp,
    changeCount: count,
    totalGrowth: series.last.total - series.first.total,
    startPeriod: series.first.period,
    peak: peak,
    peakPeriod: peakPeriod,
    current: series.last.total,
  );
}

/// The dashboard-wide time-range presets. German labels live in the UI; the
/// filtering logic here is pure and testable.
enum HistoryRange { ytd, twelveMonths, lastYear, all }

/// The subset of [all] ("YYYY-MM", ascending) that falls within [range].
/// [now] is injectable so the calendar-relative ranges are testable.
List<String> periodsForRange(List<String> all, HistoryRange range, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final currentYear = ref.year;
  int yearOf(String p) => int.parse(p.split('-')[0]);
  int monthOf(String p) => int.parse(p.split('-')[1]);
  switch (range) {
    case HistoryRange.twelveMonths:
      final cutoff = DateTime(ref.year, ref.month - 11);
      return all.where((p) => !DateTime(yearOf(p), monthOf(p)).isBefore(cutoff)).toList();
    case HistoryRange.ytd:
      return all.where((p) => yearOf(p) == currentYear).toList();
    case HistoryRange.lastYear:
      return all.where((p) => yearOf(p) == currentYear - 1).toList();
    case HistoryRange.all:
      return all;
  }
}

/// Ranges worth offering: each narrower preset appears only when it yields a
/// distinct, non-empty window (deduped against "Alle" and each other). "Alle"
/// is always present and last.
List<HistoryRange> availableRanges(List<String> all, {DateTime? now}) {
  if (all.isEmpty) return const [HistoryRange.all];
  String sig(List<String> r) => r.isEmpty ? '' : '${r.first}|${r.last}|${r.length}';
  final allSig = sig(periodsForRange(all, HistoryRange.all, now: now));
  final seen = <String>{};
  final result = <HistoryRange>[];
  for (final range in const [HistoryRange.ytd, HistoryRange.twelveMonths, HistoryRange.lastYear]) {
    final s = sig(periodsForRange(all, range, now: now));
    if (s.isEmpty || s == allSig || !seen.add(s)) continue;
    result.add(range);
  }
  result.add(HistoryRange.all);
  return result;
}

/// The initial range: "Dieses Jahr" when it's a distinct option, otherwise
/// "Alle".
HistoryRange defaultRange(List<HistoryRange> available) =>
    available.contains(HistoryRange.ytd) ? HistoryRange.ytd : HistoryRange.all;
