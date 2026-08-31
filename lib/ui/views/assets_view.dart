import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants.dart';
import '../../models/asset.dart';
import '../../state/app_state.dart';
import '../../utils/formatting.dart';
import '../app_view.dart';
import '../theme.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/banners.dart';
import '../widgets/section_card.dart';

class AssetsView extends StatefulWidget {
  const AssetsView({super.key, required this.onNavigate});

  final ValueChanged<AppView> onNavigate;

  @override
  State<AssetsView> createState() => _AssetsViewState();
}

class _AssetsViewState extends State<AssetsView> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AppState app) async {
    if (!_formKey.currentState!.validate()) return;
    final value = parseInputNumber(_valueCtrl.text);
    if (value == null) return;
    try {
      await app.addAsset(name: _nameCtrl.text.trim(), value: value);
      _nameCtrl.clear();
      _valueCtrl.clear();
      if (!mounted) return;
      showSavedSnackBar(context, widget.onNavigate, message: 'Angelegt.');
    } catch (err) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Fehler beim Anlegen: ${describeError(err)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final reminder = app.getAssetReminder();
    // Descending by value, so the biggest Vermögenswert leads; name breaks ties.
    final assets = [...app.assets]
      ..sort((a, b) {
        final cmp = b.value.compareTo(a.value);
        return cmp != 0 ? cmp : a.name.compareTo(b.name);
      });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reminder != null) InfoBanner(message: reminder),
          SectionCard(
            title: 'Vermögenswerte',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Anschaffungen wie Elektronik, Möbel oder Fahrzeuge mit ihrem aktuellen Wert. Werte direkt in der '
                  'Liste bearbeiten — jede Bearbeitung gilt als heute neu bewertet.',
                  style: TextStyle(color: kMuted),
                ),
                const SizedBox(height: 14),
                if (assets.isEmpty)
                  const EmptyHint('Noch keine Vermögenswerte angelegt.')
                else
                  for (final asset in assets)
                    _AssetRow(key: ValueKey(asset.id), asset: asset, app: app, onNavigate: widget.onNavigate),
              ],
            ),
          ),
          cardGap,
          SectionCard(
            title: 'Neuer Vermögenswert',
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Bezeichnung', hintText: 'z.B. MacBook Pro'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Pflichtfeld' : null,
                    onFieldSubmitted: (_) => _submit(app),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _valueCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: 'Wert (${app.baseCurrency})', hintText: '0,00'),
                    validator: (v) => (parseInputNumber(v ?? '') == null) ? 'Ungültiger Wert' : null,
                    onFieldSubmitted: (_) => _submit(app),
                  ),
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

class _AssetRow extends StatefulWidget {
  const _AssetRow({super.key, required this.asset, required this.app, required this.onNavigate});

  final Asset asset;
  final AppState app;
  final ValueChanged<AppView> onNavigate;

  @override
  State<_AssetRow> createState() => _AssetRowState();
}

class _AssetRowState extends State<_AssetRow> {
  late final TextEditingController _valueCtrl = TextEditingController(text: fmtInputNumber(widget.asset.value));
  Timer? _debounce;

  @override
  void didUpdateWidget(covariant _AssetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.value != widget.asset.value) {
      _valueCtrl.text = fmtInputNumber(widget.asset.value);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _valueCtrl.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(kInlineEditDebounce, _saveValue);
  }

  Future<void> _saveValue() async {
    _debounce?.cancel();
    final newValue = parseInputNumber(_valueCtrl.text);
    if (newValue == null) {
      _valueCtrl.text = fmtInputNumber(widget.asset.value);
      return;
    }
    try {
      await widget.app.updateAsset(widget.asset.id, value: newValue);
      if (!mounted) return;
      showSavedSnackBar(context, widget.onNavigate);
    } catch (err) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Fehler beim Speichern: ${describeError(err)}');
      _valueCtrl.text = fmtInputNumber(widget.asset.value);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vermögenswert löschen'),
        content: Text('"${widget.asset.name}" wirklich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: noSelect(const Text('Abbrechen'))),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: noSelect(const Text('Löschen'))),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.app.deleteAsset(widget.asset.id);
      if (!mounted) return;
      showSavedSnackBar(context, widget.onNavigate, message: 'Gelöscht.');
    }
  }

  bool get _overdue => widget.app.isAssetOverdue(widget.asset);

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(asset.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  asset.lastEvaluatedAt != null
                      ? 'zuletzt bewertet ${fmtDate(asset.lastEvaluatedAt!)}'
                      : 'noch nie bewertet',
                  style: TextStyle(color: kMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (_overdue)
            Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: kDangerText),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('Neu bewerten', style: TextStyle(color: kDangerText, fontSize: 11)),
            ),
          SizedBox(
            width: 130,
            child: TextField(
              controller: _valueCtrl,
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _scheduleSave(),
              onSubmitted: (_) => _saveValue(),
              onTapOutside: (_) => _saveValue(),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: _delete, child: noSelect(const Text('Löschen'))),
        ],
      ),
    );
  }
}
