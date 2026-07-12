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
    final ctrl = TextEditingController(text: balance == null ? '' : _trimZeros(balance.amountOriginal));
    _controllers[accountId] = ctrl;
    return ctrl;
  }

  String _trimZeros(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toString();
  }

  void _syncControllers(AppState app) {
    for (final accountId in _controllers.keys) {
      final matches = app.balances.where((b) => b.accountId == accountId && b.period == _period);
      _controllers[accountId]!.text = matches.isEmpty ? '' : _trimZeros(matches.first.amountOriginal);
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
      final amount = double.tryParse(raw.replaceAll(',', '.'));
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
              ElevatedButton(onPressed: () => widget.onNavigate(AppView.accounts), child: noSelect(const Text('Konto anlegen'))),
            ],
          ),
        ),
      );
    }

    final periodBalances = app.balances.where((b) => b.period == _period).toList();
    final activeIds = app.accounts.map((a) => a.id).toSet();
    final balanceByAccount = {for (final b in periodBalances) b.accountId: b};
    final orphanBalances = periodBalances.where((b) => !activeIds.contains(b.accountId)).toList();
    final visibleAccounts = app.accounts.where((acc) => !(_onlyMissing && balanceByAccount.containsKey(acc.id))).toList();

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
                        Text('Für ${periodLabel(_period)} sind bereits alle Konten erfasst.', style: const TextStyle(color: kMuted))
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
                  _OrphanEntriesSection(balances: orphanBalances, onNavigate: widget.onNavigate),
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
                      TextSpan(text: '  (${account.currency})', style: const TextStyle(color: kMuted, fontWeight: FontWeight.normal)),
                    ],
                  ),
                ),
                Text(
                  prev != null ? 'zuletzt ${fmtMoney(prev.amountOriginal, prev.currencyOriginal)} (${periodLabel(prev.period)})' : '',
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

/// Balances left behind by accounts that have since been archived or
/// deleted — kept correctable here since they no longer surface anywhere
/// else in the app.
class _OrphanEntriesSection extends StatefulWidget {
  const _OrphanEntriesSection({required this.balances, required this.onNavigate});

  final List<Balance> balances;
  final ValueChanged<AppView> onNavigate;

  @override
  State<_OrphanEntriesSection> createState() => _OrphanEntriesSectionState();
}

class _OrphanEntriesSectionState extends State<_OrphanEntriesSection> {
  int? _editingId;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Archivierte/gelöschte Konten',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Einträge von Konten, die inzwischen archiviert oder gelöscht wurden.', style: TextStyle(color: kMuted)),
          ),
          for (final bal in widget.balances)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: bal.id == _editingId
                  ? _EditRow(balance: bal, onDone: () => setState(() => _editingId = null), onNavigate: widget.onNavigate)
                  : _DisplayRow(balance: bal, onEdit: () => setState(() => _editingId = bal.id), onNavigate: widget.onNavigate),
            ),
        ],
      ),
    );
  }
}

class _DisplayRow extends StatelessWidget {
  const _DisplayRow({required this.balance, required this.onEdit, required this.onNavigate});

  final Balance balance;
  final VoidCallback onEdit;
  final ValueChanged<AppView> onNavigate;

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eintrag löschen'),
        content: Text('Eintrag für ${periodLabel(balance.period)} wirklich löschen?'),
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
    return Row(
      children: [
        SizedBox(width: 110, child: Text(periodLabel(balance.period))),
        Expanded(child: Text(fmtMoney(balance.amountOriginal, balance.currencyOriginal))),
        OutlinedButton(onPressed: onEdit, child: noSelect(const Text('Bearbeiten'))),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: () => _delete(context), child: noSelect(const Text('Löschen'))),
      ],
    );
  }
}

class _EditRow extends StatefulWidget {
  const _EditRow({required this.balance, required this.onDone, required this.onNavigate});

  final Balance balance;
  final VoidCallback onDone;
  final ValueChanged<AppView> onNavigate;

  @override
  State<_EditRow> createState() => _EditRowState();
}

class _EditRowState extends State<_EditRow> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.balance.amountOriginal.toString());

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_ctrl.text.replaceAll(',', '.'));
    if (amount == null) {
      showErrorSnackBar(context, 'Bitte einen gültigen Betrag eingeben.');
      return;
    }
    try {
      final amountBase = amount * widget.balance.rate;
      await context.read<AppState>().updateBalance(widget.balance.id, amountOriginal: amount, amountBase: amountBase);
      if (!mounted) return;
      showSavedSnackBar(context, widget.onNavigate);
      widget.onDone();
    } catch (err) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Fehler beim Speichern: $err');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 110, child: Text(periodLabel(widget.balance.period))),
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                ),
              ),
              const SizedBox(width: 8),
              Text(widget.balance.currencyOriginal, style: const TextStyle(color: kMuted)),
            ],
          ),
        ),
        ElevatedButton(onPressed: _save, child: noSelect(const Text('Speichern'))),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: widget.onDone, child: noSelect(const Text('Abbrechen'))),
      ],
    );
  }
}
