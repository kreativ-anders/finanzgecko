import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/account.dart';
import '../../state/app_state.dart';
import '../../utils/formatting.dart';
import '../app_view.dart';
import '../theme.dart';
import '../widgets/manual_rate_dialog.dart';
import '../widgets/month_picker_field.dart';
import '../widgets/section_card.dart';

class EntryView extends StatefulWidget {
  const EntryView({super.key, required this.onNavigate});

  final ValueChanged<AppView> onNavigate;

  @override
  State<EntryView> createState() => _EntryViewState();
}

class _EntryViewState extends State<EntryView> {
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

  TextEditingController _controllerFor(Account acc, AppState app) {
    final existing = _controllers[acc.id];
    if (existing != null) return existing;
    final bal = app.balancesInPeriod(_period).where((b) => b.accountId == acc.id);
    final ctrl = TextEditingController(text: bal.isEmpty ? '' : _trimZeros(bal.first.amountOriginal));
    _controllers[acc.id] = ctrl;
    return ctrl;
  }

  String _trimZeros(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toString();
  }

  void _refreshForPeriod(AppState app) {
    for (final acc in app.accounts) {
      final ctrl = _controllers[acc.id];
      if (ctrl == null) continue;
      final bal = app.balancesInPeriod(_period).where((b) => b.accountId == acc.id);
      ctrl.text = bal.isEmpty ? '' : _trimZeros(bal.first.amountOriginal);
    }
  }

  Future<void> _submit(AppState app) async {
    final dateISO = lastDayOfMonthISO(_period);
    final rateCache = <String, double?>{};
    var saved = 0;
    var failed = 0;

    setState(() => _notice = 'Wird gespeichert …');

    for (final acc in app.accounts) {
      final ctrl = _controllers[acc.id];
      final raw = ctrl?.text.trim() ?? '';
      if (raw.isEmpty) continue;
      final amount = double.tryParse(raw.replaceAll(',', '.'));
      if (amount == null) continue;

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
    _refreshForPeriod(app);
    final parts = ['$saved ${saved == 1 ? 'Konto' : 'Konten'} gespeichert.'];
    if (failed > 0) parts.add('$failed ohne Kurs übersprungen.');
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
              ElevatedButton(onPressed: () => widget.onNavigate(AppView.accounts), child: const Text('Konto anlegen')),
            ],
          ),
        ),
      );
    }

    final inPeriod = app.balancesInPeriod(_period);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: SectionCard(
        title: 'Kontostände erfassen',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Auch rückwirkend möglich — einfach den passenden Monat wählen. Ein bestehender Eintrag für Konto + '
              'Monat wird überschrieben. Leere Felder werden übersprungen.',
              style: TextStyle(color: kMuted),
            ),
            const SizedBox(height: 16),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 24,
              runSpacing: 12,
              children: [
                MonthPickerField(
                  value: _period,
                  onChanged: (p) => setState(() {
                    _period = p;
                    _refreshForPeriod(app);
                  }),
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
            const SizedBox(height: 16),
            for (final acc in app.accounts)
              if (!(_onlyMissing && inPeriod.any((b) => b.accountId == acc.id)))
                _EntryRow(account: acc, controller: _controllerFor(acc, app), app: app, period: _period),
            const SizedBox(height: 8),
            if (_notice.isNotEmpty) Text(_notice, style: const TextStyle(color: kMuted)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => _submit(app), child: const Text('Alle speichern')),
          ],
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.account, required this.controller, required this.app, required this.period});

  final Account account;
  final TextEditingController controller;
  final AppState app;
  final String period;

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
              decoration: const InputDecoration(hintText: 'Betrag'),
            ),
          ),
        ],
      ),
    );
  }
}
