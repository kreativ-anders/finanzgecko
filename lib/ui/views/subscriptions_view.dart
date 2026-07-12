import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants.dart';
import '../../models/subscription.dart';
import '../../state/app_state.dart';
import '../../utils/formatting.dart';
import '../app_view.dart';
import '../theme.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/manual_rate_dialog.dart';
import '../widgets/section_card.dart';
import '../widgets/sign_toggle.dart';

class SubscriptionsView extends StatefulWidget {
  const SubscriptionsView({super.key, required this.onNavigate});

  final ValueChanged<AppView> onNavigate;

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
    _interval = 'monthly';
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
    final magnitude = parseInputNumber(_magnitudeCtrl.text);
    if (name.isEmpty || magnitude == null || magnitude <= 0) {
      showErrorSnackBar(context, 'Bitte Name und einen gültigen Betrag eingeben.');
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
      showErrorSnackBar(context, 'Kein Wechselkurs verfügbar — Fixposten wurde nicht gespeichert.');
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
        _interval = 'monthly';
      });
      if (!mounted) return;
      showSavedSnackBar(context, widget.onNavigate, message: 'Angelegt.');
    } catch (err) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Fehler beim Anlegen: $err');
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final income = app.subscriptions.where((s) => s.amountOriginal > 0).toList()..sort((a, b) => a.name.compareTo(b.name));
    final expense = app.subscriptions.where((s) => s.amountOriginal < 0).toList()..sort((a, b) => a.name.compareTo(b.name));
    final entries = [...income, ...expense];

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
                if (entries.isEmpty)
                  const EmptyHint('Noch keine Fixposten erfasst.')
                else
                  for (final s in entries) _SubscriptionRow(sub: s, app: app, onNavigate: widget.onNavigate),
              ],
            ),
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
                  ElevatedButton(onPressed: () => _submit(app), child: noSelect(const Text('Anlegen'))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionRow extends StatefulWidget {
  const _SubscriptionRow({required this.sub, required this.app, required this.onNavigate});

  final Subscription sub;
  final AppState app;
  final ValueChanged<AppView> onNavigate;

  @override
  State<_SubscriptionRow> createState() => _SubscriptionRowState();
}

class _SubscriptionRowState extends State<_SubscriptionRow> {
  late final TextEditingController _nameCtrl = TextEditingController(text: widget.sub.name);
  late final TextEditingController _currencyCtrl = TextEditingController(text: widget.sub.currencyOriginal);
  late final TextEditingController _magnitudeCtrl = TextEditingController(text: fmtInputNumber(widget.sub.amountOriginal.abs()));
  late String _interval = widget.sub.interval;
  late bool _isExpense = widget.sub.amountOriginal < 0;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _nameCtrl.dispose();
    _currencyCtrl.dispose();
    _magnitudeCtrl.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    setState(() {}); // recompute the monthly preview immediately, save follows after debounce
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _save);
  }

  double get _previewMonthly {
    final magnitude = parseInputNumber(_magnitudeCtrl.text) ?? widget.sub.amountOriginal.abs();
    return (magnitude * widget.sub.rate * intervalMonthFactor(_interval)).abs();
  }

  Future<void> _save() async {
    _debounce?.cancel();
    final app = widget.app;
    final name = _nameCtrl.text.trim();
    final currency = _currencyCtrl.text.trim().toUpperCase();
    final magnitude = parseInputNumber(_magnitudeCtrl.text);

    if (name.isEmpty || magnitude == null || magnitude < 0) {
      showErrorSnackBar(context, 'Bitte einen gültigen Namen und Betrag eingeben.');
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
      showErrorSnackBar(context, 'Kein Wechselkurs verfügbar — Änderung wurde nicht gespeichert.');
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
      if (!mounted) return;
      showSavedSnackBar(context, widget.onNavigate);
    } catch (err) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Fehler beim Speichern: $err');
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fixposten löschen'),
        content: Text('"${widget.sub.name}" wirklich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: noSelect(const Text('Abbrechen'))),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: noSelect(const Text('Löschen'))),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.app.deleteSubscription(widget.sub.id);
      if (!mounted) return;
      showSavedSnackBar(context, widget.onNavigate, message: 'Gelöscht.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthly = _previewMonthly;
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
                onChanged: (_) => _scheduleSave(),
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
                onChanged: (_) => _scheduleSave(),
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
                onChanged: (_) => _scheduleSave(),
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
            Center(child: OutlinedButton(onPressed: _delete, child: noSelect(const Text('Löschen')))),
          ],
        ),
      ),
    );
  }
}
