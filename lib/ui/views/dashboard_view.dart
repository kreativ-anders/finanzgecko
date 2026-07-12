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
          if (periods.isEmpty)
            _EmptyDashboard(onNavigate: onNavigate)
          else
            _PopulatedDashboard(periods: periods, app: app),
          cardGap,
          _AssetsSection(app: app, onNavigate: onNavigate),
          cardGap,
          _SubscriptionsSection(totals: totals, app: app, onNavigate: onNavigate),
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
          ElevatedButton(onPressed: () => onNavigate(AppView.accounts), child: const Text('Konto anlegen')),
        ],
      ),
    );
  }
}

class _PopulatedDashboard extends StatelessWidget {
  const _PopulatedDashboard({required this.periods, required this.app});

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
    final entriesInLatest = app.balancesInPeriod(latestPeriod).length;

    final totalChartData = [for (final p in periods) ChartPoint(periodLabel(p), _totalForPeriod(p))];

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
                  '${delta >= 0 ? '+' : ''}${fmtMoney(delta, app.baseCurrency)} ggü. ${periodLabel(prevPeriod!)}',
                  style: TextStyle(color: delta >= 0 ? kPrimary : kDanger, fontWeight: FontWeight.w600),
                )
              else
                const Text('Noch kein Vergleichsmonat', style: TextStyle(color: kMuted)),
              const SizedBox(height: 4),
              Text(
                'Basiert auf $entriesInLatest von ${app.accounts.length} aktiven Konten mit Eintrag für diesen Monat.',
                style: const TextStyle(color: kMuted, fontSize: 13),
              ),
            ],
          ),
        ),
        cardGap,
        SectionCard(title: 'Verlauf', child: AppLineChart(points: totalChartData, color: kPrimary)),
        cardGap,
        SectionCard(title: 'Verteilung nach Kontotyp', child: AppDonutChart(segments: donutSegments)),
        cardGap,
        Text('Konten', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _AccountCards(app: app),
      ],
    );
  }
}

class _AccountCards extends StatelessWidget {
  const _AccountCards({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        for (final acc in app.accounts) _AccountCard(acc: acc, app: app),
      ],
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

    return SizedBox(
      width: 240,
      child: Card(
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
                ],
              ),
              const SizedBox(height: 4),
              Text(acc.tag, style: const TextStyle(color: kMuted, fontSize: 12)),
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
    return SectionCard(
      title: 'Vermögenswerte',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (app.assets.isEmpty)
            const EmptyHint('Noch keine Vermögenswerte erfasst.')
          else ...[
            Text(fmtMoney(total, app.baseCurrency), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text('${app.assets.length} Gegenstände erfasst', style: const TextStyle(color: kMuted, fontSize: 13)),
          ],
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () => onNavigate(AppView.assets), child: const Text('Vermögenswerte verwalten')),
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
                _SummaryItem(label: 'Einnahmen/Monat', value: fmtMoney(totals.totalIncome, app.baseCurrency), color: kPrimary),
                _SummaryItem(label: 'Ausgaben/Monat', value: fmtMoney(totals.totalExpense, app.baseCurrency), color: kDanger),
                _SummaryItem(
                  label: 'Differenz',
                  value: '${totals.net >= 0 ? '+' : ''}${fmtMoney(totals.net, app.baseCurrency)}',
                  color: totals.net >= 0 ? kPrimary : kDanger,
                ),
              ],
            ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () => onNavigate(AppView.subscriptions), child: const Text('Fixposten verwalten')),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: kMuted, fontSize: 13)),
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
