import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/asset.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/banners.dart';
import '../widgets/section_card.dart';

class AssetsView extends StatefulWidget {
  const AssetsView({super.key});

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
    final value = double.tryParse(_valueCtrl.text.replaceAll(',', '.'));
    if (value == null) return;
    try {
      await app.addAsset(name: _nameCtrl.text.trim(), value: value);
      _nameCtrl.clear();
      _valueCtrl.clear();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler beim Anlegen: $err')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final reminder = app.getAssetReminder();
    final assets = [...app.assets]..sort((a, b) => a.name.compareTo(b.name));

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
                const Text(
                  'Anschaffungen wie Elektronik, Möbel oder Fahrzeuge mit ihrem aktuellen Wert. Werte direkt in der '
                  'Liste bearbeiten — beim Ändern gilt der Eintrag als heute neu bewertet.',
                  style: TextStyle(color: kMuted),
                ),
                const SizedBox(height: 14),
                if (assets.isEmpty)
                  const EmptyHint('Noch keine Vermögenswerte angelegt.')
                else
                  for (final asset in assets) _AssetRow(asset: asset, app: app),
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
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _valueCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: 'Wert (${app.baseCurrency})', hintText: '0,00'),
                    validator: (v) => (double.tryParse((v ?? '').replaceAll(',', '.')) == null) ? 'Ungültiger Wert' : null,
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
  const _AssetRow({required this.asset, required this.app});

  final Asset asset;
  final AppState app;

  @override
  State<_AssetRow> createState() => _AssetRowState();
}

class _AssetRowState extends State<_AssetRow> {
  late final TextEditingController _valueCtrl = TextEditingController(text: _fmt(widget.asset.value));

  String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void didUpdateWidget(covariant _AssetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.value != widget.asset.value) {
      _valueCtrl.text = _fmt(widget.asset.value);
    }
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveValue() async {
    final newValue = double.tryParse(_valueCtrl.text.replaceAll(',', '.'));
    if (newValue == null) {
      _valueCtrl.text = _fmt(widget.asset.value);
      return;
    }
    try {
      await widget.app.updateAsset(widget.asset.id, value: newValue);
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler beim Speichern: $err')));
      _valueCtrl.text = _fmt(widget.asset.value);
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
                      ? 'zuletzt bewertet ${_formatDate(asset.lastEvaluatedAt!)}'
                      : 'noch nie bewertet',
                  style: const TextStyle(color: kMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (_overdue)
            Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(border: Border.all(color: kDanger), borderRadius: BorderRadius.circular(999)),
              child: const Text('Neu bewerten', style: TextStyle(color: kDanger, fontSize: 11)),
            ),
          SizedBox(
            width: 130,
            child: TextField(
              controller: _valueCtrl,
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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

String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
