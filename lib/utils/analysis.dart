/// Pure, deterministic, UI-free analysis helpers — see dev/ai/analysis.md.
library;

/// Whole calendar months from period [a] to [b] (both "YYYY-MM"), negative if [b] precedes [a].
int monthsBetweenPeriods(String a, String b) {
  final pa = a.split('-');
  final pb = b.split('-');
  return (int.parse(pb[0]) - int.parse(pa[0])) * 12 + (int.parse(pb[1]) - int.parse(pa[1]));
}

/// Months from [period] to the end of its calendar year; December returns a full 12, not 0.
int monthsToYearEnd(String period) {
  final remaining = 12 - int.parse(period.split('-')[1]);
  return remaining <= 0 ? 12 : remaining;
}

/// [period] advanced by [months], year rollover handled by [DateTime]'s month-overflow normalization.
String addMonthsToPeriod(String period, int months) {
  final parts = period.split('-');
  final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]) + months);
  return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}';
}

/// Ordinary least-squares fit of [ys] against [xs]; null with fewer than two points or a degenerate fit.
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

/// OLS slope of [values] against their indices — the observed per-month trend, null on a degenerate fit.
double? trendSlopePerMonth(List<double> values) =>
    olsTrend([for (var i = 0; i < values.length; i++) i.toDouble()], values)?.slope;

/// Blends a statistical [trendRate] with a [planRate] prior whose weight decays as [trendPoints] grows.
// WARNING: the plan is not added to the trend — both estimate the same monthly rate, adding double-counts it.
double? projectionRate({double? planRate, double? trendRate, required int trendPoints, double priorStrength = 3}) {
  if (trendRate != null && planRate != null) {
    final wTrend = trendPoints / (trendPoints + priorStrength);
    return wTrend * trendRate + (1 - wTrend) * planRate;
  }
  return trendRate ?? planRate;
}

/// Splits a net-worth change [delta] into planned contributions and the residual market/other movement.
({double contributions, double market}) contributionMarketSplit({
  required double delta,
  required double monthlyNet,
  required int monthGap,
}) {
  final contributions = monthlyNet * monthGap;
  return (contributions: contributions, market: delta - contributions);
}

/// True when [entered] is at least 10× off [previous] — the signature of a mistyped digit.
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
  /// Largest gain, or least-negative change.
  final MonthChange best;

  /// Largest loss, or least-positive change.
  final MonthChange worst;

  final double averageChange;

  /// Months whose change was strictly positive.
  final int monthsUp;

  final int changeCount;

  /// Net growth from the first recorded total to the last.
  final double totalGrowth;

  /// What [totalGrowth] is measured from.
  final String startPeriod;

  final double peak;
  final String peakPeriod;

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
  });

  /// Share of considered months that grew, in 0..1.
  double get upShare => changeCount == 0 ? 0 : monthsUp / changeCount;
}

/// [NetWorthStats] from a period-ordered [series]; null below two points, [series] assumed sorted ascending.
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
  );
}

/// The dashboard-wide time-range presets; the German labels live in the UI.
enum HistoryRange { ytd, twelveMonths, lastYear, all }

/// The subset of [all] within [range]; [now] is injectable so calendar-relative ranges stay testable.
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

/// Ranges worth offering: a narrower preset appears only when it yields a distinct, non-empty window.
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

/// The initial range: "Dieses Jahr" when it is a distinct option, otherwise "Alle".
HistoryRange defaultRange(List<HistoryRange> available) =>
    available.contains(HistoryRange.ytd) ? HistoryRange.ytd : HistoryRange.all;

/// Sort order for the dashboard's Konto-Karten grid; `standard` keeps the caller's existing order.
enum AccountSortOrder { standard, nameAsc, amountDesc, amountAsc, changeDesc, changeAsc }

/// Sorts [items] per [order]; a null amount/change sorts last and ties preserve the original order.
// INFO: generic rather than importing the Account model, so this file stays dependency-free.
List<T> sortAccounts<T>(
  List<T> items,
  AccountSortOrder order, {
  required String Function(T item) nameFor,
  required double? Function(T item) amountFor,
  required double? Function(T item) changeFor,
}) {
  if (order == AccountSortOrder.standard) return items;

  int compareNullsLast(double? a, double? b, {required bool descending}) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return descending ? b.compareTo(a) : a.compareTo(b);
  }

  int keyCompare(T a, T b) => switch (order) {
    AccountSortOrder.standard => 0,
    AccountSortOrder.nameAsc => nameFor(a).toLowerCase().compareTo(nameFor(b).toLowerCase()),
    AccountSortOrder.amountDesc => compareNullsLast(amountFor(a), amountFor(b), descending: true),
    AccountSortOrder.amountAsc => compareNullsLast(amountFor(a), amountFor(b), descending: false),
    AccountSortOrder.changeDesc => compareNullsLast(changeFor(a), changeFor(b), descending: true),
    AccountSortOrder.changeAsc => compareNullsLast(changeFor(a), changeFor(b), descending: false),
  };

  final indexed = items.indexed.toList()
    ..sort((a, b) {
      final byKey = keyCompare(a.$2, b.$2);
      return byKey != 0 ? byKey : a.$1.compareTo(b.$1);
    });
  return [for (final (_, item) in indexed) item];
}
