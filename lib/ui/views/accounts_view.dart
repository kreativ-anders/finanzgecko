import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants.dart';
import '../../models/account.dart';
import '../../state/app_state.dart';
import '../../utils/formatting.dart';
import '../theme.dart';
import '../widgets/section_card.dart';

Future<void> _openBankSuggestion(String typed) async {
  final title = Uri.encodeComponent('Bank vorschlagen: $typed');
  final uri = Uri.parse('https://github.com/kreativanders/finanzgecko/issues/new?title=$title');
  await launchUrl(uri);
}

Future<void> _openSuggestionMail() async {
  final uri = Uri.parse('mailto:finanzgecko@kreativ-anders.de?subject=Bank%20vorschlagen');
  await launchUrl(uri);
}

/// Bank text field with a color preview (matching the account's future
/// accent color) and a colored swatch per suggestion in the dropdown —
/// reusing the same [kBanks] brand colors the account list already shows.
class _BankField extends StatefulWidget {
  const _BankField({required this.controller, required this.fallbackColorHex});

  final TextEditingController controller;
  final String fallbackColorHex;

  @override
  State<_BankField> createState() => _BankFieldState();
}

class _BankFieldState extends State<_BankField> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _focusNode.dispose();
    super.dispose();
  }

  // Repaints the color swatch and "Bank fehlt?" hint as the user types —
  // needed because we hand our controller straight to Autocomplete below
  // instead of shadowing it with a second, manually-synced one.
  void _handleControllerChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final resolvedColor = colorFromHex(bankColorHex(widget.controller.text) ?? widget.fallbackColorHex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Autocomplete<String>(
          textEditingController: widget.controller,
          focusNode: _focusNode,
          optionsBuilder: (v) {
            if (v.text.isEmpty) return const Iterable<String>.empty();
            return kBanks.map((b) => b.name).where((n) => n.toLowerCase().contains(v.text.toLowerCase()));
          },
          optionsViewBuilder: (context, onSelected, options) {
            final matches = options.toList();
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240, maxWidth: 320),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final name = matches[index];
                      final hex = bankColorHex(name) ?? widget.fallbackColorHex;
                      return ListTile(
                        dense: true,
                        leading: Container(width: 12, height: 12, decoration: BoxDecoration(color: colorFromHex(hex), shape: BoxShape.circle)),
                        title: Text(name),
                        onTap: () => onSelected(name),
                      );
                    },
                  ),
                ),
              ),
            );
          },
          fieldViewBuilder: (context, controller, focusNode, onSubmit) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: 'Bank',
                hintText: 'z.B. DKB',
                suffixIcon: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Container(width: 12, height: 12, decoration: BoxDecoration(color: resolvedColor, shape: BoxShape.circle)),
                ),
              ),
            );
          },
        ),
        _BankSuggestionHint(typedBank: () => widget.controller.text),
      ],
    );
  }
}

class _BankSuggestionHint extends StatelessWidget {
  const _BankSuggestionHint({required this.typedBank});

  final String Function() typedBank;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        children: [
          const Text('Bank fehlt? ', style: TextStyle(color: kMuted, fontSize: 12)),
          InkWell(
            onTap: () => _openBankSuggestion(typedBank()),
            child: const Text('Auf GitHub vorschlagen', style: TextStyle(color: kPrimary, fontSize: 12)),
          ),
          const Text(' oder ', style: TextStyle(color: kMuted, fontSize: 12)),
          InkWell(onTap: _openSuggestionMail, child: const Text('E-Mail schreiben', style: TextStyle(color: kPrimary, fontSize: 12))),
        ],
      ),
    );
  }
}

class AccountsView extends StatefulWidget {
  const AccountsView({super.key});

  @override
  State<AccountsView> createState() => _AccountsViewState();
}

class _AccountsViewState extends State<AccountsView> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController(text: 'EUR');
  String _tag = kTags.first;
  int? _editingId;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bankCtrl.dispose();
    _currencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitNew() async {
    if (!_formKey.currentState!.validate()) return;
    final app = context.read<AppState>();
    final bank = _bankCtrl.text.trim();
    final currency = _currencyCtrl.text.trim().isEmpty ? 'EUR' : _currencyCtrl.text.trim().toUpperCase();
    try {
      await app.addAccount(
        name: _nameCtrl.text.trim(),
        bank: bank,
        tag: _tag,
        currency: currency,
        color: bankColorHex(bank) ?? tagColorHex(_tag),
      );
      _nameCtrl.clear();
      _bankCtrl.clear();
      _currencyCtrl.text = 'EUR';
      setState(() => _tag = kTags.first);
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler beim Anlegen des Kontos: $err')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionCard(
            title: 'Bestehende Konten',
            child: app.accounts.isEmpty
                ? const EmptyHint('Noch keine Konten angelegt.')
                : Column(
                    children: [
                      for (final acc in app.accounts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: acc.id == _editingId
                              ? _AccountEditForm(
                                  account: acc,
                                  onDone: () => setState(() => _editingId = null),
                                )
                              : _AccountRow(
                                  account: acc,
                                  onEdit: () => setState(() => _editingId = acc.id),
                                ),
                        ),
                    ],
                  ),
          ),
          cardGap,
          SectionCard(
            title: 'Neues Konto',
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BankField(controller: _bankCtrl, fallbackColorHex: tagColorHex(_tag)),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name', hintText: 'z.B. Gehaltskonto, Trading'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Pflichtfeld' : null,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _tag,
                          decoration: const InputDecoration(labelText: 'Typ'),
                          items: [for (final t in kTags) DropdownMenuItem(value: t, child: Text(t))],
                          onChanged: (v) => setState(() => _tag = v ?? _tag),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Autocomplete<String>(
                          optionsBuilder: (v) {
                            if (v.text.isEmpty) return kCurrencies;
                            return kCurrencies.where((c) => c.toLowerCase().contains(v.text.toLowerCase()));
                          },
                          onSelected: (v) => _currencyCtrl.text = v,
                          fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                            controller.text = _currencyCtrl.text;
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              onChanged: (v) => _currencyCtrl.text = v,
                              decoration: const InputDecoration(labelText: 'Währung'),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(onPressed: _submitNew, child: const Text('Konto anlegen')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account, required this.onEdit});

  final Account account;
  final VoidCallback onEdit;

  Future<void> _archive(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konto archivieren'),
        content: Text('"${account.name}" wirklich archivieren? Es verschwindet danach komplett aus allen Charts.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Archivieren')),
        ],
      ),
    );
    if (confirmed == true) {
      if (!context.mounted) return;
      await context.read<AppState>().archiveAccount(account.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: colorFromHex(account.color), shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    '${account.bank.isNotEmpty ? '${account.bank} · ' : ''}${account.tag} · ${account.currency}',
                    style: const TextStyle(color: kMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            OutlinedButton(onPressed: onEdit, child: const Text('Bearbeiten')),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: () => _archive(context), child: const Text('Archivieren')),
          ],
        ),
      ),
    );
  }
}

class _AccountEditForm extends StatefulWidget {
  const _AccountEditForm({required this.account, required this.onDone});

  final Account account;
  final VoidCallback onDone;

  @override
  State<_AccountEditForm> createState() => _AccountEditFormState();
}

class _AccountEditFormState extends State<_AccountEditForm> {
  late final TextEditingController _nameCtrl = TextEditingController(text: widget.account.name);
  late final TextEditingController _bankCtrl = TextEditingController(text: widget.account.bank);
  late final TextEditingController _currencyCtrl = TextEditingController(text: widget.account.currency);
  late String _tag = widget.account.tag;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bankCtrl.dispose();
    _currencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bitte einen Namen eingeben.')));
      return;
    }
    final bank = _bankCtrl.text.trim();
    try {
      await context.read<AppState>().updateAccount(
        widget.account.id,
        name: _nameCtrl.text.trim(),
        bank: bank,
        tag: _tag,
        currency: _currencyCtrl.text.trim().isEmpty ? 'EUR' : _currencyCtrl.text.trim().toUpperCase(),
        color: bankColorHex(bank) ?? widget.account.color,
      );
      widget.onDone();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler beim Speichern: $err')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BankField(controller: _bankCtrl, fallbackColorHex: widget.account.color),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name', hintText: 'z.B. Gehaltskonto, Trading'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _tag,
                    decoration: const InputDecoration(labelText: 'Typ'),
                    items: [for (final t in kTags) DropdownMenuItem(value: t, child: Text(t))],
                    onChanged: (v) => setState(() => _tag = v ?? _tag),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(child: TextFormField(controller: _currencyCtrl, decoration: const InputDecoration(labelText: 'Währung'))),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(onPressed: _save, child: const Text('Speichern')),
                const SizedBox(width: 10),
                OutlinedButton(onPressed: widget.onDone, child: const Text('Abbrechen')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
