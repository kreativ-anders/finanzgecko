import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants.dart';
import '../../models/subscription.dart';
import '../../state/app_state.dart';
import '../../utils/formatting.dart';
import '../theme.dart';
import '../widgets/manual_rate_dialog.dart';
import '../widgets/section_card.dart';
import '../widgets/sign_toggle.dart';

class SubscriptionsView extends StatefulWidget {
  const SubscriptionsView({super.key});

  @override
  State<SubscriptionsView> createState() => _SubscriptionsViewState();
}

class _SubscriptionsViewState extends State<SubscriptionsView> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _magnitudeCtrl = TextEditingController();
  late final TextEditingController _currencyCtrl;
  late String _interval;
  bool _isExpense = true;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _interval = app.defaultSubscriptionInterval;
    _currencyCtrl = TextEditingController(text: app.baseCurrency);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _magnitudeCtrl.dispose();
    _currencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AppState app) async {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameCtrl.text.trim();
    final currency = _currencyCtrl.text.trim().toUpperCase();
    final magnitude = double.tryParse(_magnitudeCtrl.text.replaceAll(',', '.'));
    if (name.isEmpty || magnitude == null || magnitude <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bitte Name und einen gültigen Betrag eingeben.')));
      return;
    }

    final rateResult = await app.currencyService.getExchangeRate(currency, app.baseCurrency, todayISO());
    var rate = rateResult?.rate;
    if (rate == null) {
      if (!mounted) return;
      rate = await promptManualRate(context, from: currency, to: app.baseCurrency);
    }
    if (rate == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kein Wechselkurs verfügbar — Fixposten wurde nicht gespeichert.')));
      return;
    }

    final sign = _isExpense ? -1 : 1;
    try {
      await app.addSubscription(
        name: name,
        interval: _interval,
        amountOriginal: sign * magnitude,
        currencyOriginal: currency,
        rate: rate,
        amountBase: sign * magnitude * rate,
      );
      _nameCtrl.clear();
      _magnitudeCtrl.clear();
      setState(() {
        _isExpense = true;
        _currencyCtrl.text = app.baseCurrency;
        _interval = app.defaultSubscriptionInterval;
      });
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler beim Anlegen: $err')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final totals = app.computeSubscriptionTotals();
    final income = app.subscriptions.where((s) => s.amountOriginal > 0).toList()..sort((a, b) => a.name.compareTo(b.name));
    final expense = app.subscriptions.where((s) => s.amountOriginal < 0).toList()..sort((a, b) => a.name.compareTo(b.name));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionCard(
            title: 'Fixposten',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Wiederkehrende Ein- und Ausgaben wie Gehalt, Dividenden oder Abos. Über das Vorzeichen-Symbol '
                  'zwischen Einnahme (+) und Ausgabe (−) umschalten. Alle Felder sind direkt bearbeitbar.',
                  style: TextStyle(color: kMuted),
                ),
                const SizedBox(height: 14),
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
              ],
            ),
          ),
          cardGap,
          SectionCard(
            title: 'Einnahmen',
            child: income.isEmpty
                ? const EmptyHint('Noch keine Einnahmen erfasst.')
                : Column(children: [for (final s in income) _SubscriptionRow(sub: s, app: app)]),
          ),
          cardGap,
          SectionCard(
            title: 'Ausgaben',
            child: expense.isEmpty
                ? const EmptyHint('Noch keine Ausgaben erfasst.')
                : Column(children: [for (final s in expense) _SubscriptionRow(sub: s, app: app)]),
          ),
          cardGap,
          SectionCard(
            title: 'Neuer Fixposten',
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name', hintText: 'z.B. Netflix, Gehalt, Dividenden'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Pflichtfeld' : null,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _interval,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Intervall'),
                          items: [for (final i in kSubscriptionIntervals) DropdownMenuItem(value: i.value, child: Text(i.label))],
                          onChanged: (v) => setState(() => _interval = v ?? _interval),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextFormField(controller: _currencyCtrl, decoration: const InputDecoration(labelText: 'Währung')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SignToggle(isExpense: _isExpense, onChanged: (v) => setState(() => _isExpense = v)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _magnitudeCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Betrag', hintText: '0,00'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('Standard ist Ausgabe (−). Für eine Einnahme wie Gehalt auf + umschalten.', style: TextStyle(color: kMuted, fontSize: 12)),
                  const SizedBox(height: 18),
                  ElevatedButton(onPressed: () => _submit(app), child: const Text('Anlegen')),
                ],
              ),
            ),
          ),
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

class _SubscriptionRow extends StatefulWidget {
  const _SubscriptionRow({required this.sub, required this.app});

  final Subscription sub;
  final AppState app;

  @override
  State<_SubscriptionRow> createState() => _SubscriptionRowState();
}

class _SubscriptionRowState extends State<_SubscriptionRow> {
  late final TextEditingController _nameCtrl = TextEditingController(text: widget.sub.name);
  late final TextEditingController _currencyCtrl = TextEditingController(text: widget.sub.currencyOriginal);
  late final TextEditingController _magnitudeCtrl = TextEditingController(text: _fmt(widget.sub.amountOriginal.abs()));
  late String _interval = widget.sub.interval;
  late bool _isExpense = widget.sub.amountOriginal < 0;

  String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _currencyCtrl.dispose();
    _magnitudeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final app = widget.app;
    final name = _nameCtrl.text.trim();
    final currency = _currencyCtrl.text.trim().toUpperCase();
    final magnitude = double.tryParse(_magnitudeCtrl.text.replaceAll(',', '.'));

    if (name.isEmpty || magnitude == null || magnitude < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bitte einen gültigen Namen und Betrag eingeben.')));
      setState(() {}); // revert visible fields to widget.sub values on next build
      return;
    }

    final rateResult = await app.currencyService.getExchangeRate(currency, app.baseCurrency, todayISO());
    var rate = rateResult?.rate;
    if (rate == null) {
      if (!mounted) return;
      rate = await promptManualRate(context, from: currency, to: app.baseCurrency);
    }
    if (rate == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kein Wechselkurs verfügbar — Änderung wurde nicht gespeichert.')));
      return;
    }

    final sign = _isExpense ? -1 : 1;
    try {
      await app.updateSubscription(
        widget.sub.id,
        name: name,
        interval: _interval,
        currencyOriginal: currency,
        amountOriginal: sign * magnitude,
        rate: rate,
        amountBase: sign * magnitude * rate,
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler beim Speichern: $err')));
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fixposten löschen'),
        content: Text('"${widget.sub.name}" wirklich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.app.deleteSubscription(widget.sub.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthly = widget.app.monthlyEquivalent(widget.sub).abs();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
                onTapOutside: (_) => _save(),
                onSubmitted: (_) => _save(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: _interval,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Intervall'),
                items: [for (final i in kSubscriptionIntervals) DropdownMenuItem(value: i.value, child: Text(i.label))],
                onChanged: (v) {
                  setState(() => _interval = v ?? _interval);
                  _save();
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _currencyCtrl,
                decoration: const InputDecoration(labelText: 'Währung'),
                onTapOutside: (_) => _save(),
                onSubmitted: (_) => _save(),
              ),
            ),
            const SizedBox(width: 10),
            SignToggle(
              isExpense: _isExpense,
              onChanged: (v) {
                setState(() => _isExpense = v);
                _save();
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _magnitudeCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Betrag'),
                onTapOutside: (_) => _save(),
                onSubmitted: (_) => _save(),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 110,
              child: Center(
                child: Text(
                  '≈ ${fmtMoney(monthly, widget.app.baseCurrency)}/Monat',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kMuted, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Center(child: OutlinedButton(onPressed: _delete, child: const Text('Löschen'))),
          ],
        ),
      ),
    );
  }
}
