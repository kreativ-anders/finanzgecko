import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/account.dart';
import '../../models/balance.dart';
import '../../state/app_state.dart';
import '../../utils/formatting.dart';
import '../app_view.dart';
import '../theme.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/manual_rate_dialog.dart';
import '../widgets/month_picker_field.dart';
import '../widgets/section_card.dart';

/// Single screen for both capturing new balances and correcting/deleting
/// existing ones — scoped to one month/year at a time (default: current
/// month) so the list stays manageable as entries pile up over time.
class EntriesView extends StatefulWidget {
  const EntriesView({super.key, required this.onNavigate});

  final ValueChanged<AppView> onNavigate;

  @override
  State<EntriesView> createState() => _EntriesViewState();
}

class _EntriesViewState extends State<EntriesView> {
  String _period = currentPeriod();
  bool _onlyMissing = false;
  String _notice = '';
  final Map<int, TextEditingController> _controllers = {};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(int accountId, Balance? balance) {
    final existing = _controllers[accountId];
    if (existing != null) return existing;
    final ctrl = TextEditingController(text: balance == null ? '' : fmtInputNumber(balance.amountOriginal));
    _controllers[accountId] = ctrl;
    return ctrl;
  }

  void _syncControllers(AppState app) {
    for (final accountId in _controllers.keys) {
      final matches = app.balances.where((b) => b.accountId == accountId && b.period == _period);
      _controllers[accountId]!.text = matches.isEmpty ? '' : fmtInputNumber(matches.first.amountOriginal);
    }
  }

  void _changePeriod(String period, AppState app) {
    setState(() {
      _period = period;
      _notice = '';
      _syncControllers(app);
    });
  }

  Future<void> _submit(AppState app) async {
    // The current month isn't over yet, so its last day is a future date
    // with no published rate (Frankfurter 404s). Use today instead — the
    // API itself falls back to the latest published business day. Closed
    // months keep their own last-day rate for historical accuracy.
    final dateISO = _period == currentPeriod() ? todayISO() : lastDayOfMonthISO(_period);
    final rateCache = <String, double?>{};
    var saved = 0;
    var failed = 0;
    var invalid = 0;

    setState(() => _notice = 'Wird gespeichert …');

    for (final acc in app.accounts) {
      final ctrl = _controllers[acc.id];
      final raw = ctrl?.text.trim() ?? '';
      if (raw.isEmpty) continue;
      final amount = parseInputNumber(raw);
      if (amount == null) {
        invalid++;
        continue;
      }

      if (!rateCache.containsKey(acc.currency)) {
        var rate = (await app.currencyService.getExchangeRate(acc.currency, app.baseCurrency, dateISO))?.rate;
        if (rate == null) {
          if (!mounted) return;
          rate = await promptManualRate(context, from: acc.currency, to: app.baseCurrency);
        }
        rateCache[acc.currency] = rate;
      }

      final rate = rateCache[acc.currency];
      if (rate == null) {
        failed++;
        continue;
      }

      await app.upsertBalance(
        accountId: acc.id,
        period: _period,
        amountOriginal: amount,
        currencyOriginal: acc.currency,
        rate: rate,
        amountBase: amount * rate,
      );
      saved++;
    }

    if (!mounted) return;
    _syncControllers(app);
    final parts = ['$saved ${saved == 1 ? 'Konto' : 'Konten'} gespeichert.'];
    if (failed > 0) parts.add('$failed ohne Kurs übersprungen.');
    if (invalid > 0) parts.add('$invalid mit ungültigem Betrag übersprungen.');
    setState(() => _notice = parts.join(' '));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    if (app.accounts.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            children: [
              Text('Erst ein Konto anlegen', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text(
                'Bevor du einen Kontostand erfassen kannst, brauchst du mindestens ein Konto.',
                style: TextStyle(color: kMuted),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => widget.onNavigate(AppView.accounts),
                child: noSelect(const Text('Konto anlegen')),
              ),
            ],
          ),
        ),
      );
    }

    final periodBalances = app.balances.where((b) => b.period == _period).toList();
    final activeIds = app.accounts.map((a) => a.id).toSet();
    final balanceByAccount = {for (final b in periodBalances) b.accountId: b};
    final orphanBalances = periodBalances.where((b) => !activeIds.contains(b.accountId)).toList();
    final visibleAccounts = app.accounts
        .where((acc) => !(_onlyMissing && balanceByAccount.containsKey(acc.id)))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 24,
            runSpacing: 12,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Zeitraum:', style: TextStyle(color: kMuted)),
                  const SizedBox(width: 12),
                  MonthPickerField(value: _period, onChanged: (p) => _changePeriod(p, app)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(value: _onlyMissing, onChanged: (v) => setState(() => _onlyMissing = v)),
                  const Text('Nur fehlende anzeigen', style: TextStyle(color: kMuted)),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionCard(
                  title: 'Kontostände',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Auch rückwirkend möglich — einfach den passenden Monat wählen. Ein bestehender Eintrag für Konto + '
                        'Monat wird überschrieben. Leere Felder werden übersprungen.',
                        style: TextStyle(color: kMuted),
                      ),
                      const SizedBox(height: 16),
                      if (visibleAccounts.isEmpty)
                        Text(
                          'Für ${periodLabel(_period)} sind bereits alle Konten erfasst.',
                          style: const TextStyle(color: kMuted),
                        )
                      else
                        for (final acc in visibleAccounts)
                          _EntryRow(
                            account: acc,
                            controller: _controllerFor(acc.id, balanceByAccount[acc.id]),
                            app: app,
                            period: _period,
                            existing: balanceByAccount[acc.id],
                            onNavigate: widget.onNavigate,
                          ),
                      const SizedBox(height: 8),
                      if (_notice.isNotEmpty) Text(_notice, style: const TextStyle(color: kMuted)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: () => _submit(app), child: noSelect(const Text('Alle speichern'))),
                    ],
                  ),
                ),
                if (orphanBalances.isNotEmpty) ...[
                  cardGap,
                  _OrphanEntriesSection(balances: orphanBalances, app: app, onNavigate: widget.onNavigate),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.account,
    required this.controller,
    required this.app,
    required this.period,
    required this.existing,
    required this.onNavigate,
  });

  final Account account;
  final TextEditingController controller;
  final AppState app;
  final String period;
  final Balance? existing;
  final ValueChanged<AppView> onNavigate;

  Future<void> _delete(BuildContext context) async {
    final bal = existing;
    if (bal == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eintrag löschen'),
        content: Text('Eintrag für ${account.name} · ${periodLabel(bal.period)} wirklich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: noSelect(const Text('Abbrechen'))),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: noSelect(const Text('Löschen'))),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    await context.read<AppState>().deleteBalance(bal.id);
    controller.clear();
    if (!context.mounted) return;
    showSavedSnackBar(context, onNavigate, message: 'Gelöscht.');
  }

  @override
  Widget build(BuildContext context) {
    final prev = app.previousBalance(account.id, period);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: account.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    children: [
                      TextSpan(
                        text: '  (${account.currency})',
                        style: const TextStyle(color: kMuted, fontWeight: FontWeight.normal),
                      ),
                    ],
                  ),
                ),
                Text(
                  prev != null
                      ? 'zuletzt ${fmtMoney(prev.amountOriginal, prev.currencyOriginal)} (${periodLabel(prev.period)})'
                      : '',
                  style: const TextStyle(color: kMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 160,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(labelText: 'Betrag', hintText: '0,00'),
            ),
          ),
          SizedBox(
            width: 40,
            child: existing == null
                ? null
                : IconButton(
                    tooltip: 'Eintrag löschen',
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => _delete(context),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Balances left behind by accounts that have since been archived — kept
/// visible here (with a way back to the account) since they no longer
/// surface anywhere else in the app.
class _OrphanEntriesSection extends StatelessWidget {
  const _OrphanEntriesSection({required this.balances, required this.app, required this.onNavigate});

  final List<Balance> balances;
  final AppState app;
  final ValueChanged<AppView> onNavigate;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Archivierte Konten',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Einträge von Konten, die inzwischen archiviert wurden.', style: TextStyle(color: kMuted)),
          ),
          for (final bal in balances)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _OrphanRow(balance: bal, account: app.findAccount(bal.accountId), onNavigate: onNavigate),
            ),
        ],
      ),
    );
  }
}

class _OrphanRow extends StatelessWidget {
  const _OrphanRow({required this.balance, required this.account, required this.onNavigate});

  final Balance balance;
  // Null in the rare case the account record itself is gone entirely (e.g. a
  // hand-edited import) rather than merely archived — then only Löschen applies.
  final Account? account;
  final ValueChanged<AppView> onNavigate;

  Future<void> _restore(BuildContext context) async {
    final acc = account;
    if (acc == null) return;
    await context.read<AppState>().restoreAccount(acc.id);
    if (!context.mounted) return;
    showSavedSnackBar(context, onNavigate, message: 'Wiederhergestellt.');
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eintrag löschen'),
        content: Text(
          'Eintrag für ${account?.name ?? 'unbekanntes Konto'} · ${periodLabel(balance.period)} wirklich löschen?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: noSelect(const Text('Abbrechen'))),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: noSelect(const Text('Löschen'))),
        ],
      ),
    );
    if (confirmed == true) {
      if (!context.mounted) return;
      await context.read<AppState>().deleteBalance(balance.id);
      if (!context.mounted) return;
      showSavedSnackBar(context, onNavigate, message: 'Gelöscht.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final acc = account;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 110, child: Text(periodLabel(balance.period))),
        Expanded(
          child: Text(
            acc?.name ?? 'Konto gelöscht',
            style: acc == null ? const TextStyle(color: kMuted) : const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        SizedBox(
          width: 120,
          child: Text(fmtMoney(balance.amountOriginal, balance.currencyOriginal), textAlign: TextAlign.right),
        ),
        const SizedBox(width: 12),
        if (acc != null) ...[
          OutlinedButton(onPressed: () => _restore(context), child: noSelect(const Text('Wiederherstellen'))),
          const SizedBox(width: 8),
        ],
        OutlinedButton(onPressed: () => _delete(context), child: noSelect(const Text('Löschen'))),
      ],
    );
  }
}
