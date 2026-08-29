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

class DashboardView extends StatelessWidget {
  const DashboardView({super.key, required this.onNavigate, required this.onOpenAccountEntry});

  final ValueChanged<AppView> onNavigate;

  /// Opens "Einträge" positioned on one account — separate from [onNavigate],
  /// which carries no payload.
  final ValueChanged<int> onOpenAccountEntry;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final allPeriods = app.allPeriodsSorted();
    final backupReminder = app.getBackupReminder();
    final assetReminder = app.getAssetReminder();
    final totals = app.computeSubscriptionTotals();
    final updateReminder = app.getUpdateReminder();

    final banners = <Widget>[
      if (updateReminder != null)
        InfoBanner(
          message: updateReminder,
          actionLabel: 'Jetzt erfassen',
          onAction: () => onNavigate(AppView.entries),
          urgency: BannerUrgency.nudge,
        ),
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

    // Resolved once and threaded through every time-based card below, so the
    // filter drives the whole dashboard.
    final available = availableRanges(allPeriods);
    final storedPreset = app.dashboardRangePreset;
    final preset = (storedPreset != null && available.contains(storedPreset)) ? storedPreset : defaultRange(available);
    final filtered = allPeriods.isEmpty ? <String>[] : periodsForRange(allPeriods, preset);
    final includesLatest = filtered.isNotEmpty && filtered.last == allPeriods.last;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...banners,
          if (allPeriods.isEmpty) ...[
            _EmptyDashboard(onNavigate: onNavigate, hasAccounts: app.accounts.isNotEmpty),
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
              onRangeChanged: app.setDashboardRangePreset,
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
            Row(
              children: [
                Expanded(child: Text('Konten', style: Theme.of(context).textTheme.titleLarge)),
                _AccountSortSelector(selected: app.accountSortOrder, onChanged: app.setAccountSortOrder),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => onNavigate(AppView.entries),
                  child: noSelect(const Text('Einträge verwalten')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _AccountCards(app: app, sortOrder: app.accountSortOrder, onOpenAccountEntry: onOpenAccountEntry),
          ],
        ],
      ),
    );
  }
}

/// Onboarding hero shown in place of the charts until there's at least one
/// balance entry — staged in two steps so the call to action matches what's
/// actually missing (an account first, then a first Kontostand). `Center` is
/// required because this sits inside a Column with crossAxisAlignment.start;
/// without it the block would shrink-wrap and "center" relative to itself,
/// i.e. look left-aligned.
class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard({required this.onNavigate, required this.hasAccounts});

  final ValueChanged<AppView> onNavigate;
  final bool hasAccounts;

  @override
  Widget build(BuildContext context) {
    final headline = hasAccounts ? 'Fast geschafft!' : 'Willkommen bei FinanzGecko! 👋';
    final body = hasAccounts
        ? 'Dein erstes Konto steht schon — trag jetzt deinen ersten Kontostand ein, dann füllt sich dein '
              'Dashboard mit Verlauf, Verteilung und Kennzahlen.'
        : 'Noch keine Daten vorhanden. Leg jetzt dein erstes Konto an, um dein Vermögen zu erfassen.';
    final buttonLabel = hasAccounts ? 'Einträge erfassen' : 'Konto anlegen';
    final target = hasAccounts ? AppView.entries : AppView.accounts;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(headline, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                body,
                style: TextStyle(color: kMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () => onNavigate(target), child: noSelect(Text(buttonLabel))),
            ],
          ),
        ),
      ),
    );
  }
}

class _TotalsOverview extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final latestPeriod = periods.last;
    final prevPeriod = periods.length > 1 ? periods[periods.length - 2] : null;

    final currentTotal = app.totalForPeriod(latestPeriod);
    final prevTotal = prevPeriod != null ? app.totalForPeriod(prevPeriod) : null;
    final delta = prevTotal != null ? currentTotal - prevTotal : null;
    final pct = (delta != null && prevTotal != null && prevTotal != 0) ? (delta / prevTotal) * 100 : null;
    final entriesInLatest = app.balancesInPeriod(latestPeriod).length;
    final hasForeignCurrencyInTotal = app.balancesInPeriod(latestPeriod).any((b) {
      final acc = app.findAccount(b.accountId);
      return acc != null && acc.currency != app.baseCurrency;
    });

    // Vermögenswerte (Sachwerte) have no monthly history, so including them
    // only adds a constant to the headline — the delta and the
    // contribution/market split are account-based and unaffected.
    final assetsTotal = app.assets.fold<double>(0, (sum, a) => sum + a.value);
    final hasAssets = app.assets.isNotEmpty;
    final withAssets = app.includeAssetsInTotal && hasAssets;
    final displayTotal = currentTotal + (withAssets ? assetsTotal : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // Bottom deliberately smaller than top: this block has no
          // SectionCard border of its own, and the next section already adds
          // cardGap (20) plus its own 20px top padding — a symmetric 16 here
          // made the gap to "Verlauf" nearly 5x the intra-block line gap.
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          // The range filter is a global control, so it sits top-right,
          // anchored to the top of the block, instead of sharing a baseline
          // with a caption line.
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overline stands alone — the "inkl. Sachwerte" switch
                    // sits under the number it controls instead of competing
                    // with this line at nearly the same weight.
                    Text(
                      withAssets
                          ? 'GESAMTVERMÖGEN INKL. SACHWERTE · STAND ${periodLabel(latestPeriod).toUpperCase()}'
                          : 'GESAMTVERMÖGEN · STAND ${periodLabel(latestPeriod).toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: kMuted, fontSize: 12, letterSpacing: 1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fmtMoney(displayTotal, app.baseCurrency),
                      maxLines: 1,
                      style: TextStyle(color: kPrimaryText, fontSize: 44, fontWeight: FontWeight.bold),
                    ),
                    if (hasAssets) ...[
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.scale(
                            scale: 0.8,
                            child: Switch(value: app.includeAssetsInTotal, onChanged: app.setIncludeAssetsInTotal),
                          ),
                          const SizedBox(width: 4),
                          Text('inkl. Sachwerte', style: TextStyle(color: kMuted, fontSize: 12)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    if (delta != null)
                      Text(
                        '${fmtSignedMoney(delta, app.baseCurrency)}'
                        '${pct != null ? ' (${delta >= 0 ? '+' : ''}${fmtPercent(pct)})' : ''}'
                        ' ggü. ${periodLabel(prevPeriod!)}',
                        style: TextStyle(color: delta >= 0 ? kPrimaryText : kDangerText, fontWeight: FontWeight.w600),
                      )
                    else
                      Text('Noch kein Vergleichsmonat', style: TextStyle(color: kMuted)),
                    // Contributions are estimated from the Fixposten net
                    // (scaled by the month gap), the rest is market/other
                    // movement. Rounded to whole units — the split is an
                    // estimate, so cents would be false precision.
                    if (delta != null && prevPeriod != null && app.subscriptions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final split = contributionMarketSplit(
                            delta: delta,
                            monthlyNet: app.computeSubscriptionTotals().net,
                            monthGap: monthsBetweenPeriods(prevPeriod, latestPeriod),
                          );
                          final cur = app.baseCurrency;
                          return Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _SplitChip(
                                icon: Icons.savings_outlined,
                                label: '${fmtSignedMoneyRounded(split.contributions, cur)} eingezahlt',
                                tint: kPrimaryText,
                              ),
                              _SplitChip(
                                icon: Icons.show_chart,
                                label: '${fmtSignedMoneyRounded(split.market, cur)} Markt',
                                tint: kMuted,
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                    // Shown ONLY when the latest month is missing accounts.
                    // At full coverage the line is noise; when incomplete it
                    // is a real "your total is understated" flag.
                    if (entriesInLatest < app.accounts.length) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 14, color: kWarningText),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Nur $entriesInLatest von ${app.accounts.length} Konten für diesen Monat erfasst — Summe evtl. unvollständig.',
                              style: TextStyle(color: kWarningText, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (hasForeignCurrencyInTotal) ...[
                      const SizedBox(height: 12),
                      // Capped to a readable width — at the dashboard's full
                      // ~1100px content width this line would stretch well
                      // past a comfortable measure.
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, size: 13, color: kMuted),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Fremdwährungskonten: Rundungsdifferenzen von wenigen Cent möglich.',
                                style: TextStyle(color: kMuted, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Global range filter, pinned top-right above the Verlauf card.
              if (options.length > 1) ...[
                const SizedBox(width: 16),
                _PresetSelector(options: options, selected: selected, onChanged: onRangeChanged),
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

/// The "Verlauf" card: total net worth over the active window, with a forward
/// projection. [includesLatest] says whether the window reaches the most
/// recent entry — only then is a projection drawn.
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.periods, required this.app, required this.includesLatest});

  final List<String> periods;
  final AppState app;
  final bool includesLatest;

  @override
  Widget build(BuildContext context) {
    final filtered = periods;
    final chartData = [for (final p in filtered) ChartPoint(periodLabel(p), app.totalForPeriod(p))];
    final values = [for (final p in filtered) app.totalForPeriod(p)];

    // Projection: least-squares trend of the actual history, stabilized by
    // the Fixposten net as a decaying prior (see utils/analysis.dart). Only
    // drawn when the window reaches the latest entry — never from a stale
    // anchor, so it disappears on "Letztes Jahr".
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
            endLabel: periodLabel(addMonthsToPeriod(filtered.last, months)),
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
            Builder(
              builder: (context) {
                final rate = forecast.monthlyDelta;
                final delta = rate * forecast.months;
                final total = app.totalForPeriod(filtered.last) + delta;
                final cur = app.baseCurrency;
                final String basis;
                if (trendRate != null && planRate != null) {
                  basis = 'Prognose aus $trendPoints Monaten Verlauf, mit Fixposten geglättet';
                } else if (trendRate != null) {
                  basis = 'Prognose aus $trendPoints Monaten Verlauf';
                } else {
                  basis = 'Prognose aus den Fixposten (noch wenig Verlauf)';
                }
                // The rate is the one number worth reading at a glance;
                // basis and endpoint are detail, demoted to a second line.
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prognose: ${fmtSignedMoney(rate, cur)}/Monat',
                      style: TextStyle(color: kMuted, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '$basis → ${fmtMoney(total, cur)} bis ${forecast.endLabel} (${fmtSignedMoney(delta, cur)})',
                      style: TextStyle(color: kMuted, fontSize: 12),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Net worth split by Kontotyp across every recorded month — a stacked area so
/// allocation drift (e.g. a growing Depot share) becomes visible over time,
/// which the single-month donut can't show.
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
        showHover: true,
        currency: app.baseCurrency,
      ),
    );
  }
}

/// Compact stats over the full net-worth history. Hidden below two months.
class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.app, required this.periods});

  final AppState app;

  /// All periods with data, sorted ascending.
  final List<String> periods;

  @override
  Widget build(BuildContext context) {
    final series = [for (final p in periods) (period: p, total: app.totalForPeriod(p))];
    final stats = computeNetWorthStats(series);
    if (stats == null) return const SizedBox.shrink();
    final cur = app.baseCurrency;
    final tiles = [
      (
        label: 'Gesamtveränderung',
        value: fmtSignedMoney(stats.totalGrowth, cur),
        subValue: 'seit ${periodLabel(stats.startPeriod)}',
        color: stats.totalGrowth >= 0 ? kPrimaryText : kDangerText,
      ),
      (
        label: 'Bester Monat',
        value: fmtSignedMoney(stats.best.delta, cur),
        subValue: periodLabel(stats.best.period),
        color: stats.best.delta >= 0 ? kPrimaryText : kDangerText,
      ),
      (
        label: 'Schwächster Monat',
        value: fmtSignedMoney(stats.worst.delta, cur),
        subValue: periodLabel(stats.worst.period),
        color: stats.worst.delta >= 0 ? kPrimaryText : kDangerText,
      ),
      (
        label: 'Ø Veränderung/Monat',
        value: fmtSignedMoney(stats.averageChange, cur),
        subValue: '${stats.changeCount} Monate',
        color: stats.averageChange >= 0 ? kPrimaryText : kDangerText,
      ),
      (
        label: 'Monate im Plus',
        value: '${stats.monthsUp}/${stats.changeCount}',
        subValue: fmtPercent(stats.upShare * 100),
        color: kPrimaryText,
      ),
      (
        label: 'Höchststand',
        value: fmtMoney(stats.peak, cur),
        subValue: periodLabel(stats.peakPeriod),
        color: kPrimaryText,
      ),
    ];
    return SectionCard(
      title: 'Kennzahlen',
      child: _BalancedMetricsGrid(
        itemWidths: [
          for (final t in tiles) _metricTileWidth(context, label: t.label, value: t.value, subValue: t.subValue),
        ],
        spacing: 32,
        runSpacing: 12,
        children: [
          for (final t in tiles) _SummaryItem(label: t.label, value: t.value, subValue: t.subValue, color: t.color),
        ],
      ),
    );
  }
}

/// Like [Wrap], but avoids a trailing row of exactly one tile by pulling the
/// previous row's last tile forward into it — so a resize never strands a
/// single tile by itself.
class _BalancedMetricsGrid extends StatelessWidget {
  const _BalancedMetricsGrid({
    required this.itemWidths,
    required this.spacing,
    required this.runSpacing,
    required this.children,
  });

  /// Natural (unpadded) width of each entry in [children], same order.
  final List<double> itemWidths;
  final double spacing;
  final double runSpacing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rows = _packRows(itemWidths, constraints.maxWidth, spacing);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var r = 0; r < rows.length; r++) ...[
              if (r > 0) SizedBox(height: runSpacing),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var c = 0; c < rows[r].length; c++) ...[
                    if (c > 0) SizedBox(width: spacing),
                    children[rows[r][c]],
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Greedily packs item indices into rows fitting [maxWidth], then borrows the
/// previous row's last item if exactly one would be left alone at the end.
List<List<int>> _packRows(List<double> widths, double maxWidth, double spacing) {
  final rows = <List<int>>[];
  var current = <int>[];
  var currentWidth = 0.0;
  for (var i = 0; i < widths.length; i++) {
    final withThis = current.isEmpty ? widths[i] : currentWidth + spacing + widths[i];
    if (current.isNotEmpty && withThis > maxWidth) {
      rows.add(current);
      current = [i];
      currentWidth = widths[i];
    } else {
      current.add(i);
      currentWidth = withThis;
    }
  }
  if (current.isNotEmpty) rows.add(current);

  if (rows.length > 1 && rows.last.length == 1) {
    rows.last.insert(0, rows[rows.length - 2].removeLast());
  }
  return rows;
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
    return Semantics(
      selected: selected,
      child: InkWell(
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
      ),
    );
  }
}

/// Sort control for the Konto-Karten grid. A compact popup rather than a
/// [_PresetChip] row like the range filter, since six options would crowd the
/// header; each entry pairs its label with a directional icon.
class _AccountSortSelector extends StatelessWidget {
  const _AccountSortSelector({required this.selected, required this.onChanged});

  final AccountSortOrder selected;
  final ValueChanged<AccountSortOrder> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AccountSortOrder>(
      tooltip: 'Sortierung ändern',
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final order in AccountSortOrder.values)
          PopupMenuItem(
            value: order,
            child: Row(
              children: [
                Icon(order.icon, size: 18, color: order == selected ? kPrimaryText : kMuted),
                const SizedBox(width: 10),
                Text(
                  order.label,
                  style: TextStyle(
                    color: order == selected ? kPrimaryText : null,
                    fontWeight: order == selected ? FontWeight.w600 : null,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorder),
        ),
        child: noSelect(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected.icon, size: 16, color: kMuted),
              const SizedBox(width: 6),
              Text(
                selected.label,
                style: TextStyle(fontSize: 12, color: kMuted, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 2),
              Icon(Icons.expand_more, size: 16, color: kMuted),
            ],
          ),
        ),
      ),
    );
  }
}

extension on AccountSortOrder {
  String get label => switch (this) {
    AccountSortOrder.standard => 'Standard',
    AccountSortOrder.nameAsc => 'Name (A–Z)',
    AccountSortOrder.amountDesc => 'Betrag (hoch → niedrig)',
    AccountSortOrder.amountAsc => 'Betrag (niedrig → hoch)',
    AccountSortOrder.changeDesc => 'Veränderung (größter Zuwachs)',
    AccountSortOrder.changeAsc => 'Veränderung (größter Rückgang)',
  };

  IconData get icon => switch (this) {
    AccountSortOrder.standard => Icons.reorder_rounded,
    AccountSortOrder.nameAsc => Icons.sort_by_alpha_rounded,
    AccountSortOrder.amountDesc => Icons.south_rounded,
    AccountSortOrder.amountAsc => Icons.north_rounded,
    AccountSortOrder.changeDesc => Icons.trending_up_rounded,
    AccountSortOrder.changeAsc => Icons.trending_down_rounded,
  };
}

/// Non-interactive header chip breaking the total change into "eingezahlt"
/// vs. "Markt". [tint] drives both the faint fill and the icon/text color, so
/// it reads as a quiet label rather than a button.
class _SplitChip extends StatelessWidget {
  const _SplitChip({required this.icon, required this.label, required this.tint});

  final IconData icon;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: tint.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tint),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: tint, fontSize: 13)),
        ],
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
      final acc = app.findAccount(b.accountId);
      if (acc == null) continue;
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
                Icon(Icons.info_outline, size: 14, color: kDangerText),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Hoher Anteil in einer Kategorie: ${topEntry!.key} macht ${fmtPercent(topShare * 100)} deines Vermögens aus.',
                    style: TextStyle(color: kDangerText, fontSize: 12),
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

/// Side-by-side summary cards once there's enough width, stacked otherwise.
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
  const _AccountCards({required this.app, required this.sortOrder, required this.onOpenAccountEntry});

  final AppState app;
  final AccountSortOrder sortOrder;
  final ValueChanged<int> onOpenAccountEntry;

  static const double _spacing = 16;
  static const double _minCardWidth = 220;
  static const int _maxColumns = 4;

  @override
  Widget build(BuildContext context) {
    final accounts = sortAccounts(
      app.accounts,
      sortOrder,
      nameFor: (acc) => acc.name,
      amountFor: (acc) => app.latestBalanceForAccount(acc.id)?.amountBase,
      changeFor: (acc) {
        final latest = app.latestBalanceForAccount(acc.id);
        if (latest == null) return null;
        final prev = app.previousBalance(acc.id, latest.period);
        if (prev == null) return null;
        return latest.amountBase - prev.amountBase;
      },
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = ((constraints.maxWidth + _spacing) / (_minCardWidth + _spacing)).floor().clamp(1, _maxColumns);
        final cardWidth = (constraints.maxWidth - _spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: _spacing,
          runSpacing: _spacing,
          children: [
            for (final acc in accounts)
              SizedBox(
                width: cardWidth,
                child: _AccountCard(acc: acc, app: app, onOpenAccountEntry: onOpenAccountEntry),
              ),
          ],
        );
      },
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.acc, required this.app, required this.onOpenAccountEntry});

  final Account acc;
  final AppState app;
  final ValueChanged<int> onOpenAccountEntry;

  @override
  Widget build(BuildContext context) {
    final accBalances = app.balances.where((b) => b.accountId == acc.id).toList()
      ..sort((a, b) => a.period.compareTo(b.period));
    final points = [for (final b in accBalances) ChartPoint(periodLabel(b.period), b.amountBase)];
    final latest = app.latestBalanceForAccount(acc.id);

    // Whole card is the click target, not just the chart: the 70px chart
    // alone is a small, hard-to-discover hit area. The Card's own radius (12,
    // see theme.dart cardTheme) is repeated on the InkWell so the hover/splash
    // doesn't bleed over the rounded corners.
    //
    // `noSelect` is what makes the hand cursor appear: the app-wide
    // SelectionArea's text cursor sits *deeper* in the tree than the InkWell
    // and would otherwise win. Same rule for any clickable surface with text,
    // see dev/ai/ui-conventions.md.
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onOpenAccountEntry(acc.id),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: Tooltip(
          message: 'Kontostand für "${acc.name}" erfassen',
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: noSelect(
              Column(
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
                      _TagChip(tag: acc.tag, accountColorHex: acc.color),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    acc.bank,
                    style: TextStyle(color: kMuted, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    latest != null ? fmtMoney(latest.amountBase, app.baseCurrency) : '—',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  // Month-over-month change, so each card shows direction at
                  // a glance, not just the current figure.
                  if (latest != null)
                    Builder(
                      builder: (context) {
                        final prev = app.previousBalance(acc.id, latest.period);
                        if (prev == null) return const SizedBox.shrink();
                        final delta = latest.amountBase - prev.amountBase;
                        return Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '${fmtSignedMoney(delta, app.baseCurrency)} ggü. ${periodLabel(prev.period)}',
                            style: TextStyle(
                              color: delta >= 0 ? kPrimaryText : kDangerText,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 8),
                  AppLineChart(points: points, color: colorFromHex(acc.color), height: 70),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Low-emphasis label for the account's Kontotyp — the bank is the card's
/// primary identity now, since the type mostly matters only at creation.
class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag, required this.accountColorHex});

  final String tag;

  /// The account's own accent color rather than the Kontotyp color, so the
  /// chip matches the dot and mini chart on the same card.
  final String accountColorHex;

  @override
  Widget build(BuildContext context) {
    // Bank brand colors are logo colors and fail as 11px bold text on our
    // surfaces (#000000 on the dark card, #ffe600 on the light one), so the
    // *label* uses the contrast-corrected variant. The 15% fill keeps the
    // untouched brand color — as a background it has no contrast requirement
    // and is what makes the chip read as "that bank".
    final fill = colorFromHex(accountColorHex);
    final label = colorFromHex(readableOn(accountColorHex, kSurfaceHex));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: fill.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
      child: Text(
        tag,
        style: TextStyle(color: label, fontSize: 11, fontWeight: FontWeight.w600),
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
            const EmptyHint('Noch keine Vermögenswerte angelegt.')
          else ...[
            Text(fmtMoney(total, app.baseCurrency), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text('${app.assets.length} Vermögenswerte erfasst', style: TextStyle(color: kMuted, fontSize: 13)),
            const SizedBox(height: 4),
            Text(
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
              child: noSelect(Text(overdue ? 'Vermögenswerte neu bewerten' : 'Vermögenswerte verwalten')),
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
            const EmptyHint('Noch keine Fixposten erfasst.')
          else
            Wrap(
              spacing: 32,
              runSpacing: 12,
              children: [
                _SummaryItem(
                  label: 'Einnahmen/Monat',
                  value: fmtMoney(totals.totalIncome, app.baseCurrency),
                  subValue: '${fmtMoney(totals.totalIncome * 12, app.baseCurrency)}/Jahr',
                  color: kPrimaryText,
                ),
                _SummaryItem(
                  label: 'Ausgaben/Monat',
                  value: fmtMoney(totals.totalExpense, app.baseCurrency),
                  subValue: '${fmtMoney(totals.totalExpense * 12, app.baseCurrency)}/Jahr',
                  color: kDangerText,
                ),
                _SummaryItem(
                  label: 'Differenz',
                  value: fmtSignedMoney(totals.net, app.baseCurrency),
                  subValue: '${fmtSignedMoney(totals.net * 12, app.baseCurrency)}/Jahr',
                  color: totals.net >= 0 ? kPrimaryText : kDangerText,
                ),
              ],
            ),
          const Spacer(),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: () => onNavigate(AppView.subscriptions),
              child: noSelect(const Text('Fixposten verwalten')),
            ),
          ),
        ],
      ),
    );
  }
}

// Getters, not `const`/`final` fields: kMuted resolves against the current
// theme, so a cached value would freeze at whatever theme was active on
// first use and never follow a later Hell/Dunkel switch.
TextStyle get _metricLabelStyle => TextStyle(color: kMuted, fontSize: 13);
const _metricValueStyle = TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
TextStyle get _metricSubValueStyle => TextStyle(color: kMuted, fontSize: 12);

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
        Text(label, style: _metricLabelStyle),
        Text(value, style: _metricValueStyle.copyWith(color: color)),
        if (subValue != null) Text(subValue!, style: _metricSubValueStyle),
      ],
    );
  }
}

/// Natural width a single metric tile needs (the widest of its label, value
/// and subValue) — measured from the real text/style rather than guessed, so
/// [_BalancedMetricsGrid] packs rows as tightly as the content allows.
double _metricTileWidth(BuildContext context, {required String label, required String value, String? subValue}) {
  final scaler = MediaQuery.textScalerOf(context);
  double measure(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    return painter.width;
  }

  return [
    measure(label, _metricLabelStyle),
    measure(value, _metricValueStyle),
    if (subValue != null) measure(subValue, _metricSubValueStyle),
  ].reduce((a, b) => a > b ? a : b);
}
