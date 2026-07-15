import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants.dart';
import '../../models/account.dart';
import '../../state/app_state.dart';
import '../../utils/analysis.dart';
import '../../utils/formatting.dart';
import '../app_view.dart';
import '../theme.dart';
import '../widgets/banners.dart';
import '../widgets/donut_chart.dart';
import '../widgets/line_chart.dart';
import '../widgets/section_card.dart';
import '../widgets/stacked_area_chart.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key, required this.onNavigate});

  final ValueChanged<AppView> onNavigate;

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  // Dashboard-wide time window. Affects the headline, the Verlauf chart and its
  // projection, the composition chart, the distribution donut, and the
  // Kennzahlen — everything time-based. Null until the user picks one; a
  // sensible default ("Dieses Jahr" when available) is derived from the data.
  // Range filtering itself is pure and lives in utils/analysis.dart
  // (availableRanges / periodsForRange / defaultRange) so it's unit-testable.
  HistoryRange? _preset;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final onNavigate = widget.onNavigate;
    final allPeriods = app.allPeriodsSorted();
    final backupReminder = app.getBackupReminder();
    final assetReminder = app.getAssetReminder();
    final totals = app.computeSubscriptionTotals();
    final updateReminder = app.getUpdateReminder();

    final banners = <Widget>[
      if (updateReminder != null)
        InfoBanner(message: updateReminder, actionLabel: 'Jetzt erfassen', onAction: () => onNavigate(AppView.entries)),
      if (app.subscriptions.isNotEmpty && totals.net < 0)
        OverspendBanner(
          expenseText: fmtMoney(totals.totalExpense, app.baseCurrency),
          incomeText: fmtMoney(totals.totalIncome, app.baseCurrency),
          onCheck: () => onNavigate(AppView.subscriptions),
        ),
      if (backupReminder.overdue)
        InfoBanner(
          message: backupReminder.message,
          actionLabel: 'Jetzt exportieren',
          onAction: () => onNavigate(AppView.settings),
        ),
      if (assetReminder != null)
        InfoBanner(message: assetReminder, actionLabel: 'Jetzt prüfen', onAction: () => onNavigate(AppView.assets)),
    ];

    // Resolve the active window once and thread it through every time-based
    // card below, so the filter genuinely drives the whole dashboard.
    final available = availableRanges(allPeriods);
    final preset = (_preset != null && available.contains(_preset)) ? _preset! : defaultRange(available);
    final filtered = allPeriods.isEmpty ? <String>[] : periodsForRange(allPeriods, preset);
    final includesLatest = filtered.isNotEmpty && filtered.last == allPeriods.last;

    // Distinct currencies actually held in the window's latest month — the
    // Währungsaufteilung card only makes sense with more than one.
    final latestCurrencies = <String>{};
    if (filtered.isNotEmpty) {
      for (final b in app.balancesInPeriod(filtered.last)) {
        if (b.amountBase <= 0) continue;
        final acc = app.findAccount(b.accountId);
        if (acc != null) latestCurrencies.add(acc.currency);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...banners,
          if (allPeriods.isEmpty) ...[
            _EmptyDashboard(onNavigate: onNavigate),
            cardGap,
            _SummaryRow(
              children: [
                _SubscriptionsSection(totals: totals, app: app, onNavigate: onNavigate),
                _AssetsSection(app: app, onNavigate: onNavigate),
              ],
            ),
          ] else ...[
            _TotalsOverview(
              periods: filtered,
              app: app,
              options: available,
              selected: preset,
              onRangeChanged: (p) => setState(() => _preset = p),
            ),
            cardGap,
            _HistoryCard(periods: filtered, app: app, includesLatest: includesLatest),
            cardGap,
            _SummaryRow(
              children: [
                _DistributionSection(app: app, latestPeriod: filtered.last, onNavigate: onNavigate),
                _SubscriptionsSection(totals: totals, app: app, onNavigate: onNavigate),
                _AssetsSection(app: app, onNavigate: onNavigate),
              ],
            ),
            cardGap,
            if (filtered.length >= 2) ...[
              _CompositionCard(app: app, periods: filtered),
              cardGap,
              _StatsCard(app: app, periods: filtered),
              cardGap,
            ],
            if (latestCurrencies.length >= 2) ...[
              _CurrencyExposureCard(app: app, latestPeriod: filtered.last),
              cardGap,
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Konten', style: Theme.of(context).textTheme.titleLarge),
                OutlinedButton(
                  onPressed: () => onNavigate(AppView.entries),
                  child: noSelect(const Text('Einträge verwalten')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _AccountCards(app: app),
          ],
        ],
      ),
    );
  }
}

class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard({required this.onNavigate});

  final ValueChanged<AppView> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Text('Noch kein Vermögen erfasst', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('Leg zuerst ein Konto an und trag deinen ersten Kontostand ein.', style: TextStyle(color: kMuted)),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: () => onNavigate(AppView.accounts), child: noSelect(const Text('Konto anlegen'))),
        ],
      ),
    );
  }
}

class _TotalsOverview extends StatefulWidget {
  const _TotalsOverview({
    required this.periods,
    required this.app,
    required this.options,
    required this.selected,
    required this.onRangeChanged,
  });

  final List<String> periods;
  final AppState app;

  /// The dashboard-wide range filter, rendered on the "erfasst" caption line.
  final List<HistoryRange> options;
  final HistoryRange selected;
  final ValueChanged<HistoryRange> onRangeChanged;

  @override
  State<_TotalsOverview> createState() => _TotalsOverviewState();
}

class _TotalsOverviewState extends State<_TotalsOverview> {
  bool _includeAssets = false;

  double _totalForPeriod(String period) =>
      widget.app.balancesInPeriod(period).fold<double>(0, (sum, b) => sum + b.amountBase);

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final periods = widget.periods;
    final latestPeriod = periods.last;
    final prevPeriod = periods.length > 1 ? periods[periods.length - 2] : null;

    final currentTotal = _totalForPeriod(latestPeriod);
    final prevTotal = prevPeriod != null ? _totalForPeriod(prevPeriod) : null;
    final delta = prevTotal != null ? currentTotal - prevTotal : null;
    final pct = (delta != null && prevTotal != null && prevTotal != 0) ? (delta / prevTotal) * 100 : null;
    final entriesInLatest = app.balancesInPeriod(latestPeriod).length;
    final hasForeignCurrencyInTotal = app.balancesInPeriod(latestPeriod).any((b) {
      final matches = app.accounts.where((a) => a.id == b.accountId);
      return matches.isNotEmpty && matches.first.currency != app.baseCurrency;
    });

    // Vermögenswerte (Sachwerte) have no monthly history, so including them
    // only adds a constant to the headline — the month-over-month delta and
    // the contribution/market split (both account-based) are unaffected.
    final assetsTotal = app.assets.fold<double>(0, (sum, a) => sum + a.value);
    final hasAssets = app.assets.isNotEmpty;
    final withAssets = _includeAssets && hasAssets;
    final displayTotal = currentTotal + (withAssets ? assetsTotal : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label row: caption with the "inkl. Sachwerte" switch right next
              // to it — the switch changes the total, so it sits by the caption.
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      withAssets
                          ? 'GESAMTVERMÖGEN INKL. SACHWERTE · STAND ${periodLabel(latestPeriod).toUpperCase()}'
                          : 'GESAMTVERMÖGEN · STAND ${periodLabel(latestPeriod).toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: kMuted, fontSize: 12, letterSpacing: 1),
                    ),
                  ),
                  if (hasAssets) ...[
                    const SizedBox(width: 12),
                    const Text('inkl. Sachwerte', style: TextStyle(color: kMuted, fontSize: 13)),
                    const SizedBox(width: 8),
                    Switch(
                      value: _includeAssets,
                      onChanged: (v) => setState(() => _includeAssets = v),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                fmtMoney(displayTotal, app.baseCurrency),
                maxLines: 1,
                style: const TextStyle(color: kPrimary, fontSize: 44, fontWeight: FontWeight.bold),
              ),
              if (delta != null)
                Text(
                  '${delta >= 0 ? '+' : ''}${fmtMoney(delta, app.baseCurrency)}'
                  '${pct != null ? ' (${delta >= 0 ? '+' : ''}${fmtPercent(pct)})' : ''}'
                  ' ggü. ${periodLabel(prevPeriod!)}',
                  style: TextStyle(color: delta >= 0 ? kPrimary : kDanger, fontWeight: FontWeight.w600),
                )
              else
                const Text('Noch kein Vergleichsmonat', style: TextStyle(color: kMuted)),
              // Split the change into what you added vs. what the market did:
              // contributions are estimated from the Fixposten net (scaled by
              // the month gap), the rest is market/other movement. Estimate —
              // shown only when there are Fixposten to base it on.
              if (delta != null && prevPeriod != null && app.subscriptions.isNotEmpty) ...[
                const SizedBox(height: 4),
                Builder(builder: (context) {
                  final split = contributionMarketSplit(
                    delta: delta,
                    monthlyNet: app.computeSubscriptionTotals().net,
                    monthGap: monthsBetweenPeriods(prevPeriod, latestPeriod),
                  );
                  final cur = app.baseCurrency;
                  String signed(double v) => '${v >= 0 ? '+' : ''}${fmtMoney(v, cur)}';
                  return Text(
                    'geschätzt: davon ~${signed(split.contributions)} eingezahlt · ~${signed(split.market)} Markt & Sonstiges',
                    style: const TextStyle(color: kMuted, fontSize: 12),
                  );
                }),
              ],
              const SizedBox(height: 4),
              // The "erfasst" caption shares its row with the dashboard-wide
              // range filter (right-aligned) — no separate floating filter row.
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      withAssets
                          ? 'Für diesen Monat sind $entriesInLatest von ${app.accounts.length} Konten erfasst · plus ${fmtMoney(assetsTotal, app.baseCurrency)} Sachwerte.'
                          : 'Für diesen Monat sind $entriesInLatest von ${app.accounts.length} Konten erfasst.',
                      style: const TextStyle(color: kMuted, fontSize: 13),
                    ),
                  ),
                  if (widget.options.length > 1) ...[
                    const SizedBox(width: 16),
                    const Text('Zeitraum', style: TextStyle(color: kMuted, fontSize: 13)),
                    const SizedBox(width: 12),
                    _PresetSelector(options: widget.options, selected: widget.selected, onChanged: widget.onRangeChanged),
                  ],
                ],
              ),
              if (hasForeignCurrencyInTotal) ...[
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 13, color: kMuted),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Enthält Konten in Fremdwährung: Die Summe kann durch Rundung beim Wechselkurs um wenige Cent von der '
                        'Summe der einzeln angezeigten Kontostände abweichen.',
                        style: TextStyle(color: kMuted, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

extension on HistoryRange {
  String get label => switch (this) {
    HistoryRange.ytd => 'Dieses Jahr',
    HistoryRange.twelveMonths => '12 Monate',
    HistoryRange.lastYear => 'Letztes Jahr',
    HistoryRange.all => 'Alle',
  };
}

/// The "Verlauf" card: total net worth over the active window (set by the
/// dashboard-wide filter), with a forward projection. Plots whatever [periods]
/// window it's handed; [includesLatest] says whether that window reaches the
/// most recent entry (only then is a projection drawn).
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.periods, required this.app, required this.includesLatest});

  final List<String> periods;
  final AppState app;
  final bool includesLatest;

  double _totalForPeriod(String period) =>
      app.balancesInPeriod(period).fold<double>(0, (sum, b) => sum + b.amountBase);

  /// "YYYY-MM" [months] after [period] (DateTime handles year rollover).
  String _periodPlus(String period, int months) {
    final parts = period.split('-');
    final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]) + months);
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = periods;
    final chartData = [for (final p in filtered) ChartPoint(periodLabel(p), _totalForPeriod(p))];
    final values = [for (final p in filtered) _totalForPeriod(p)];

    // The projection is primarily statistical: a least-squares trend of the
    // actual net-worth history (which already reflects the variable spending
    // that swings month to month), stabilized by the Fixposten net as a prior
    // whose weight decays as history accumulates. See utils/analysis.dart.
    // Only drawn when the window reaches the latest entry — never from a stale
    // anchor (so it disappears on "Letztes Jahr").
    final net = app.computeSubscriptionTotals().net;
    final months = (includesLatest && filtered.isNotEmpty) ? monthsToYearEnd(filtered.last) : 0;

    final planRate = net != 0 ? net : null;
    final trendRate = trendSlopePerMonth(values);
    final trendPoints = filtered.length;
    final rate = projectionRate(planRate: planRate, trendRate: trendRate, trendPoints: trendPoints);

    final forecast = (months > 0 && rate != null)
        ? ChartForecast(
            monthlyDelta: rate,
            months: months,
            endLabel: periodLabel(_periodPlus(filtered.last, months)),
          )
        : null;

    return SectionCard(
      title: 'Verlauf',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppLineChart(
            points: chartData,
            color: kPrimary,
            filled: true,
            showMinMax: true,
            forecast: forecast,
            showHover: true,
            currency: app.baseCurrency,
          ),
          if (forecast != null) ...[
            const SizedBox(height: 8),
            Builder(builder: (context) {
              final rate = forecast.monthlyDelta;
              final delta = rate * forecast.months;
              final total = _totalForPeriod(filtered.last) + delta;
              final cur = app.baseCurrency;
              String signed(double v) => '${v >= 0 ? '+' : ''}${fmtMoney(v, cur)}';
              final String basis;
              if (trendRate != null && planRate != null) {
                basis = 'Prognose aus $trendPoints Monaten Verlauf, mit Fixposten geglättet';
              } else if (trendRate != null) {
                basis = 'Prognose aus $trendPoints Monaten Verlauf';
              } else {
                basis = 'Prognose aus den Fixposten (noch wenig Verlauf)';
              }
              return Text(
                '$basis: ${signed(rate)}/Monat → ${fmtMoney(total, cur)} bis ${forecast.endLabel} (${signed(delta)}).',
                style: const TextStyle(color: kMuted, fontSize: 12),
              );
            }),
          ],
        ],
      ),
    );
  }
}

/// Net worth split by Kontotyp across every recorded month — a stacked area so
/// allocation drift (e.g. a growing Depot share) is visible over time, which
/// the single-month donut can't show.
class _CompositionCard extends StatelessWidget {
  const _CompositionCard({required this.app, required this.periods});

  final AppState app;

  /// All periods with data, sorted ascending.
  final List<String> periods;

  double _tagTotalInPeriod(String tag, String period) {
    var sum = 0.0;
    for (final b in app.balancesInPeriod(period)) {
      final acc = app.findAccount(b.accountId);
      if (acc != null && acc.tag == tag) sum += b.amountBase;
    }
    // Negative balances (e.g. an overdrawn account) can't stack sensibly, so
    // the composition shows positive holdings only.
    return sum < 0 ? 0 : sum;
  }

  @override
  Widget build(BuildContext context) {
    // Tags actually in use, ordered by the canonical kTags order, with any
    // custom tags appended so nothing is dropped.
    final used = app.accounts.map((a) => a.tag).toSet();
    final orderedTags = <String>[
      for (final t in kTags)
        if (used.contains(t)) t,
      for (final t in used)
        if (!kTags.contains(t)) t,
    ];

    final series = [
      for (final tag in orderedTags)
        StackedSeries(
          label: tag,
          color: colorFromHex(tagColorHex(tag)),
          values: [for (final p in periods) _tagTotalInPeriod(tag, p)],
        ),
    ];

    return SectionCard(
      title: 'Zusammensetzung über Zeit',
      child: AppStackedAreaChart(
        periodLabels: [for (final p in periods) periodLabel(p)],
        series: series,
        currency: app.baseCurrency,
      ),
    );
  }
}

/// Share of net worth by currency for the latest month of the active window —
/// surfaces foreign-currency exposure that the base-currency total hides. Only
/// shown by the dashboard when more than one currency is actually held.
class _CurrencyExposureCard extends StatelessWidget {
  const _CurrencyExposureCard({required this.app, required this.latestPeriod});

  final AppState app;
  final String latestPeriod;

  @override
  Widget build(BuildContext context) {
    final byCurrency = <String, double>{};
    for (final b in app.balancesInPeriod(latestPeriod)) {
      final acc = app.findAccount(b.accountId);
      if (acc == null || b.amountBase <= 0) continue;
      byCurrency[acc.currency] = (byCurrency[acc.currency] ?? 0) + b.amountBase;
    }
    final total = byCurrency.values.fold<double>(0, (sum, v) => sum + v);
    final entries = byCurrency.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final cur = app.baseCurrency;
    return SectionCard(
      title: 'Währungsaufteilung',
      child: Wrap(
        spacing: 32,
        runSpacing: 12,
        children: [
          for (final e in entries)
            _SummaryItem(
              label: e.key,
              value: fmtPercent(total > 0 ? e.value / total * 100 : 0.0),
              subValue: fmtMoney(e.value, cur),
              color: e.key == cur ? kPrimary : kTrendUp,
            ),
        ],
      ),
    );
  }
}

/// Compact stats over the full net-worth history: best/worst month, average
/// monthly change, and how often it grew. Hidden with fewer than two months.
class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.app, required this.periods});

  final AppState app;

  /// All periods with data, sorted ascending.
  final List<String> periods;

  double _totalForPeriod(String period) =>
      app.balancesInPeriod(period).fold<double>(0, (sum, b) => sum + b.amountBase);

  @override
  Widget build(BuildContext context) {
    final series = [for (final p in periods) (period: p, total: _totalForPeriod(p))];
    final stats = computeNetWorthStats(series);
    if (stats == null) return const SizedBox.shrink();
    final cur = app.baseCurrency;
    String signed(double v) => '${v >= 0 ? '+' : ''}${fmtMoney(v, cur)}';
    return SectionCard(
      title: 'Kennzahlen',
      child: Wrap(
        spacing: 32,
        runSpacing: 12,
        children: [
          _SummaryItem(
            label: 'Gesamtveränderung',
            value: signed(stats.totalGrowth),
            subValue: 'seit ${periodLabel(stats.startPeriod)}',
            color: stats.totalGrowth >= 0 ? kPrimary : kDanger,
          ),
          _SummaryItem(
            label: 'Bester Monat',
            value: signed(stats.best.delta),
            subValue: periodLabel(stats.best.period),
            color: stats.best.delta >= 0 ? kPrimary : kDanger,
          ),
          _SummaryItem(
            label: 'Schwächster Monat',
            value: signed(stats.worst.delta),
            subValue: periodLabel(stats.worst.period),
            color: stats.worst.delta >= 0 ? kPrimary : kDanger,
          ),
          _SummaryItem(
            label: 'Ø Veränderung/Monat',
            value: signed(stats.averageChange),
            subValue: '${stats.changeCount} Monate',
            color: stats.averageChange >= 0 ? kPrimary : kDanger,
          ),
          _SummaryItem(
            label: 'Monate im Plus',
            value: '${stats.monthsUp}/${stats.changeCount}',
            subValue: fmtPercent(stats.upShare * 100),
            color: kPrimary,
          ),
          _SummaryItem(
            label: 'Höchststand',
            value: fmtMoney(stats.peak, cur),
            subValue: periodLabel(stats.peakPeriod),
            color: kPrimary,
          ),
          _SummaryItem(
            label: 'Unter Höchststand',
            value: stats.drawdownFromPeak > 0 ? '-${fmtPercent(stats.drawdownFromPeak * 100)}' : '±0 %',
            subValue: stats.drawdownFromPeak > 0 ? 'vs. ${periodLabel(stats.peakPeriod)}' : 'am Höchststand',
            color: stats.drawdownFromPeak > 0 ? kDanger : kPrimary,
          ),
        ],
      ),
    );
  }
}

class _PresetSelector extends StatelessWidget {
  const _PresetSelector({required this.options, required this.selected, required this.onChanged});

  final List<HistoryRange> options;
  final HistoryRange selected;
  final ValueChanged<HistoryRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final preset in options)
          _PresetChip(label: preset.label, selected: preset == selected, onTap: () => onChanged(preset)),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? kPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? kPrimary : kBorder),
        ),
        child: noSelect(
          Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF04140D) : kMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _DistributionSection extends StatelessWidget {
  const _DistributionSection({required this.app, required this.latestPeriod, required this.onNavigate});

  final AppState app;
  final String latestPeriod;
  final ValueChanged<AppView> onNavigate;

  @override
  Widget build(BuildContext context) {
    final byTag = <String, double>{};
    for (final b in app.balancesInPeriod(latestPeriod)) {
      final matches = app.accounts.where((a) => a.id == b.accountId);
      if (matches.isEmpty) continue;
      final acc = matches.first;
      byTag[acc.tag] = (byTag[acc.tag] ?? 0) + b.amountBase;
    }
    final donutSegments = [
      for (final entry in byTag.entries)
        DonutSegment(label: entry.key, value: entry.value, color: colorFromHex(tagColorHex(entry.key))),
    ];

    final positiveTags = byTag.entries.where((e) => e.value > 0).toList();
    final tagTotal = positiveTags.fold<double>(0, (sum, e) => sum + e.value);
    final topEntry = positiveTags.isEmpty ? null : positiveTags.reduce((a, b) => a.value > b.value ? a : b);
    final topShare = (topEntry != null && tagTotal > 0) ? topEntry.value / tagTotal : null;
    final showConcentrationNote =
        positiveTags.length >= 2 && topShare != null && topShare >= kConcentrationRiskThreshold;

    return SectionCard(
      title: 'Verteilung nach Kontotyp',
      expandChild: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppDonutChart(segments: donutSegments),
          if (showConcentrationNote) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 14, color: kDanger),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Hoher Anteil in einer Kategorie: ${topEntry!.key} macht ${fmtPercent(topShare * 100)} deines Vermögens aus.',
                    style: const TextStyle(color: kDanger, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          const Spacer(),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: () => onNavigate(AppView.accounts),
              child: noSelect(const Text('Konten verwalten')),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lays summary cards out side by side once there's enough width, falling
/// back to a stack on narrower windows so nothing gets squeezed unreadably.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final child in children) ...[child, cardGap],
            ]..removeLast(),
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                Expanded(child: children[i]),
                if (i < children.length - 1) const SizedBox(width: 20),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AccountCards extends StatelessWidget {
  const _AccountCards({required this.app});

  final AppState app;

  static const double _spacing = 16;
  static const double _minCardWidth = 220;
  static const int _maxColumns = 4;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = ((constraints.maxWidth + _spacing) / (_minCardWidth + _spacing)).floor().clamp(1, _maxColumns);
        final cardWidth = (constraints.maxWidth - _spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: _spacing,
          runSpacing: _spacing,
          children: [
            for (final acc in app.accounts)
              SizedBox(
                width: cardWidth,
                child: _AccountCard(acc: acc, app: app),
              ),
          ],
        );
      },
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.acc, required this.app});

  final Account acc;
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final accPeriods = app.balances.where((b) => b.accountId == acc.id).map((b) => b.period).toSet().toList()..sort();
    final points = [
      for (final p in accPeriods)
        ChartPoint(periodLabel(p), app.balances.firstWhere((b) => b.accountId == acc.id && b.period == p).amountBase),
    ];
    final latest = app.latestBalanceForAccount(acc.id);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: colorFromHex(acc.color), shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    acc.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                _TagChip(tag: acc.tag),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              acc.bank,
              style: const TextStyle(color: kMuted, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              latest != null ? fmtMoney(latest.amountBase, app.baseCurrency) : '—',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            // Month-over-month change for this account, so each card shows
            // direction at a glance, not just the current figure.
            if (latest != null)
              Builder(builder: (context) {
                final prev = app.previousBalance(acc.id, latest.period);
                if (prev == null) return const SizedBox.shrink();
                final delta = latest.amountBase - prev.amountBase;
                return Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '${delta >= 0 ? '+' : ''}${fmtMoney(delta, app.baseCurrency)} ggü. ${periodLabel(prev.period)}',
                    style: TextStyle(
                      color: delta >= 0 ? kPrimary : kDanger,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }),
            const SizedBox(height: 8),
            AppLineChart(points: points, color: colorFromHex(acc.color), height: 70),
          ],
        ),
      ),
    );
  }
}

/// Small, low-emphasis label for the account's Kontotyp — the bank (shown
/// as the card subtitle) is the primary identity now, since the type mostly
/// only matters once, at account creation.
class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(tagColorHex(tag));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
      child: Text(
        tag,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _AssetsSection extends StatelessWidget {
  const _AssetsSection({required this.app, required this.onNavigate});

  final AppState app;
  final ValueChanged<AppView> onNavigate;

  @override
  Widget build(BuildContext context) {
    final total = app.assets.fold<double>(0, (sum, a) => sum + a.value);
    final overdue = app.assets.isNotEmpty && app.assets.any(app.isAssetOverdue);
    return SectionCard(
      title: 'Vermögenswerte',
      expandChild: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (app.assets.isEmpty)
            const EmptyHint('Noch keine Vermögenswerte erfasst.')
          else ...[
            Text(fmtMoney(total, app.baseCurrency), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text('${app.assets.length} Gegenstände erfasst', style: const TextStyle(color: kMuted, fontSize: 13)),
            const SizedBox(height: 4),
            const Text(
              'Standardmäßig nicht im Gesamtvermögen — oben zuschaltbar.',
              style: TextStyle(color: kMuted, fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
          const Spacer(),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: () => onNavigate(AppView.assets),
              child: noSelect(Text(overdue ? 'Vermögenswerte re-evaluieren' : 'Vermögenswerte verwalten')),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionsSection extends StatelessWidget {
  const _SubscriptionsSection({required this.totals, required this.app, required this.onNavigate});

  final SubscriptionTotals totals;
  final AppState app;
  final ValueChanged<AppView> onNavigate;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Fixposten',
      expandChild: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (app.subscriptions.isEmpty)
            const EmptyHint('Noch keine wiederkehrenden Ein-/Ausgaben erfasst.')
          else
            Wrap(
              spacing: 32,
              runSpacing: 12,
              children: [
                _SummaryItem(
                  label: 'Einnahmen/Monat',
                  value: fmtMoney(totals.totalIncome, app.baseCurrency),
                  subValue: '${fmtMoney(totals.totalIncome * 12, app.baseCurrency)}/Jahr',
                  color: kPrimary,
                ),
                _SummaryItem(
                  label: 'Ausgaben/Monat',
                  value: fmtMoney(totals.totalExpense, app.baseCurrency),
                  subValue: '${fmtMoney(totals.totalExpense * 12, app.baseCurrency)}/Jahr',
                  color: kDanger,
                ),
                _SummaryItem(
                  label: 'Differenz',
                  value: '${totals.net >= 0 ? '+' : ''}${fmtMoney(totals.net, app.baseCurrency)}',
                  subValue: '${totals.net >= 0 ? '+' : ''}${fmtMoney(totals.net * 12, app.baseCurrency)}/Jahr',
                  color: totals.net >= 0 ? kPrimary : kDanger,
                ),
              ],
            ),
          const Spacer(),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: () => onNavigate(AppView.subscriptions),
              child: noSelect(const Text('Fixposten aktualisieren')),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value, this.subValue, required this.color});

  final String label;
  final String value;
  final String? subValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: kMuted, fontSize: 13)),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        if (subValue != null) Text(subValue!, style: const TextStyle(color: kMuted, fontSize: 12)),
      ],
    );
  }
}
