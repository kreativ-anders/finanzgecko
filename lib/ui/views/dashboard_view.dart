import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants.dart';
import '../../models/account.dart';
import '../../state/app_state.dart';
import '../../utils/formatting.dart';
import '../app_view.dart';
import '../theme.dart';
import '../widgets/banners.dart';
import '../widgets/donut_chart.dart';
import '../widgets/line_chart.dart';
import '../widgets/section_card.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key, required this.onNavigate});

  final ValueChanged<AppView> onNavigate;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final periods = app.allPeriodsSorted();
    final backupReminder = app.getBackupReminder();
    final assetReminder = app.getAssetReminder();
    final totals = app.computeSubscriptionTotals();

    final banners = <Widget>[
      if (app.subscriptions.isNotEmpty && totals.net < 0)
        OverspendBanner(
          expenseText: fmtMoney(totals.totalExpense, app.baseCurrency),
          incomeText: fmtMoney(totals.totalIncome, app.baseCurrency),
          onCheck: () => onNavigate(AppView.subscriptions),
        ),
      if (backupReminder.overdue)
        InfoBanner(message: backupReminder.message, actionLabel: 'Jetzt exportieren', onAction: () => onNavigate(AppView.settings)),
      if (assetReminder != null)
        InfoBanner(message: assetReminder, actionLabel: 'Jetzt prüfen', onAction: () => onNavigate(AppView.assets)),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...banners,
          if (periods.isEmpty) ...[
            _EmptyDashboard(onNavigate: onNavigate),
            cardGap,
            _SummaryRow(
              children: [
                _SubscriptionsSection(totals: totals, app: app, onNavigate: onNavigate),
                _AssetsSection(app: app, onNavigate: onNavigate),
              ],
            ),
          ] else ...[
            _TotalsOverview(periods: periods, app: app),
            cardGap,
            _SummaryRow(
              children: [
                _DistributionSection(app: app, latestPeriod: periods.last, onNavigate: onNavigate),
                _SubscriptionsSection(totals: totals, app: app, onNavigate: onNavigate),
                _AssetsSection(app: app, onNavigate: onNavigate),
              ],
            ),
            cardGap,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Konten', style: Theme.of(context).textTheme.titleLarge),
                OutlinedButton(onPressed: () => onNavigate(AppView.entries), child: noSelect(const Text('Einträge verwalten'))),
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

class _TotalsOverview extends StatelessWidget {
  const _TotalsOverview({required this.periods, required this.app});

  final List<String> periods;
  final AppState app;

  double _totalForPeriod(String period) =>
      app.balancesInPeriod(period).fold<double>(0, (sum, b) => sum + b.amountBase);

  @override
  Widget build(BuildContext context) {
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

    final totalChartData = [for (final p in periods) ChartPoint(periodLabel(p), _totalForPeriod(p))];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GESAMTVERMÖGEN · STAND ${periodLabel(latestPeriod).toUpperCase()}',
                style: const TextStyle(color: kMuted, fontSize: 12, letterSpacing: 1),
              ),
              const SizedBox(height: 4),
              Text(
                fmtMoney(currentTotal, app.baseCurrency),
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
              const SizedBox(height: 4),
              Text(
                'Basiert auf $entriesInLatest von ${app.accounts.length} aktiven Konten mit Eintrag für diesen Monat.',
                style: const TextStyle(color: kMuted, fontSize: 13),
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
        cardGap,
        SectionCard(title: 'Verlauf', child: AppLineChart(points: totalChartData, color: kPrimary, filled: true)),
      ],
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
      for (final entry in byTag.entries) DonutSegment(label: entry.key, value: entry.value, color: colorFromHex(tagColorHex(entry.key))),
    ];

    final positiveTags = byTag.entries.where((e) => e.value > 0).toList();
    final tagTotal = positiveTags.fold<double>(0, (sum, e) => sum + e.value);
    final topEntry = positiveTags.isEmpty ? null : positiveTags.reduce((a, b) => a.value > b.value ? a : b);
    final topShare = (topEntry != null && tagTotal > 0) ? topEntry.value / tagTotal : null;
    final showConcentrationNote = positiveTags.length >= 2 && topShare != null && topShare >= kConcentrationRiskThreshold;

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
            child: OutlinedButton(onPressed: () => onNavigate(AppView.accounts), child: noSelect(const Text('Konten verwalten'))),
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
            children: [for (final child in children) ...[child, cardGap]]..removeLast(),
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
            for (final acc in app.accounts) SizedBox(width: cardWidth, child: _AccountCard(acc: acc, app: app)),
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
                Container(width: 10, height: 10, decoration: BoxDecoration(color: colorFromHex(acc.color), shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Text(acc.name, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                _TagChip(tag: acc.tag),
              ],
            ),
            const SizedBox(height: 4),
            Text(acc.bank, style: const TextStyle(color: kMuted, fontSize: 12), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Text(
              latest != null ? fmtMoney(latest.amountBase, app.baseCurrency) : '—',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
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
      child: Text(tag, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
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
              'Nicht im Gesamtvermögen oben enthalten.',
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
            child: OutlinedButton(onPressed: () => onNavigate(AppView.subscriptions), child: noSelect(const Text('Fixposten aktualisieren'))),
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
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        if (subValue != null) Text(subValue!, style: const TextStyle(color: kMuted, fontSize: 12)),
      ],
    );
  }
}
