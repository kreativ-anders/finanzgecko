import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants.dart';
import '../../models/account.dart';
import '../../state/app_state.dart';
import '../../utils/formatting.dart';
import '../app_view.dart';
import '../theme.dart';
import '../widgets/app_snackbar.dart';
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
                        leading: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(color: colorFromHex(hex), shape: BoxShape.circle),
                        ),
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
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: resolvedColor, shape: BoxShape.circle),
                  ),
                ),
              ),
              validator: (v) => isKnownBank(v) ? null : 'Bitte eine Bank aus der Liste auswählen',
            );
          },
        ),
        _BankSuggestionHint(typedBank: () => widget.controller.text),
      ],
    );
  }
}

/// Transparency note: shown whenever the currency differs from the base
/// currency, since exchange rates then come from a third-party API, not offline data.
class _CurrencyHint extends StatelessWidget {
  const _CurrencyHint({required this.currency, required this.baseCurrency});

  final String currency;
  final String baseCurrency;

  @override
  Widget build(BuildContext context) {
    if (currency == baseCurrency) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        'Wechselkurse werden automatisch über die frankfurter.dev API (EZB-Referenzkurse) abgerufen und für den Offline-Betrieb zwischengespeichert.',
        style: TextStyle(color: kMuted, fontSize: 12),
      ),
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
          Text('Bank fehlt? ', style: TextStyle(color: kMuted, fontSize: 12)),
          InkWell(
            onTap: () => _openBankSuggestion(typedBank()),
            child: noSelect(Text('Auf GitHub vorschlagen', style: TextStyle(color: kPrimaryText, fontSize: 12))),
          ),
          Text(' oder ', style: TextStyle(color: kMuted, fontSize: 12)),
          InkWell(
            onTap: _openSuggestionMail,
            child: noSelect(Text('E-Mail schreiben', style: TextStyle(color: kPrimaryText, fontSize: 12))),
          ),
        ],
      ),
    );
  }
}

/// The Bank/Name/Typ/Währung field group shared by the "Neues Konto" form and
/// the inline edit form — both wrap this in their own [Form] (with their own
/// submit button and validation trigger), so only the field layout itself is
/// shared here.
class _AccountFormFields extends StatelessWidget {
  const _AccountFormFields({
    required this.nameCtrl,
    required this.bankCtrl,
    required this.tag,
    required this.currency,
    required this.baseCurrency,
    required this.fallbackColorHex,
    required this.tagOptions,
    required this.currencyOptions,
    required this.onTagChanged,
    required this.onCurrencyChanged,
  });

  final TextEditingController nameCtrl;
  final TextEditingController bankCtrl;
  final String tag;
  final String currency;
  final String baseCurrency;
  final String fallbackColorHex;
  final Iterable<String> tagOptions;
  final Iterable<String> currencyOptions;
  final ValueChanged<String?> onTagChanged;
  final ValueChanged<String?> onCurrencyChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BankField(controller: bankCtrl, fallbackColorHex: fallbackColorHex),
        const SizedBox(height: 14),
        TextFormField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Name', hintText: 'z.B. Gehaltskonto, Trading'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Pflichtfeld' : null,
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: tag,
                decoration: const InputDecoration(labelText: 'Typ'),
                items: [for (final t in tagOptions) DropdownMenuItem(value: t, child: Text(t))],
                onChanged: onTagChanged,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: currency,
                decoration: const InputDecoration(labelText: 'Währung'),
                items: [for (final c in currencyOptions) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: onCurrencyChanged,
              ),
            ),
          ],
        ),
        _CurrencyHint(currency: currency, baseCurrency: baseCurrency),
      ],
    );
  }
}

class AccountsView extends StatefulWidget {
  const AccountsView({super.key, required this.onNavigate});

  final ValueChanged<AppView> onNavigate;

  @override
  State<AccountsView> createState() => _AccountsViewState();
}

class _AccountsViewState extends State<AccountsView> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  String _tag = kTags.first;
  String _currency = 'EUR';
  int? _editingId;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bankCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitNew() async {
    if (!_formKey.currentState!.validate()) return;
    final app = context.read<AppState>();
    final bank = _bankCtrl.text.trim();
    try {
      await app.addAccount(
        name: _nameCtrl.text.trim(),
        bank: bank,
        tag: _tag,
        currency: _currency,
        color: bankColorHex(bank) ?? tagColorHex(_tag),
      );
      _nameCtrl.clear();
      _bankCtrl.clear();
      setState(() {
        _tag = kTags.first;
        _currency = 'EUR';
      });
      if (!mounted) return;
      showSavedSnackBar(context, widget.onNavigate, message: 'Angelegt.');
    } catch (err) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Fehler beim Anlegen des Kontos: ${describeError(err)}');
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
                                  onNavigate: widget.onNavigate,
                                )
                              : _AccountRow(
                                  account: acc,
                                  onEdit: () => setState(() => _editingId = acc.id),
                                  onNavigate: widget.onNavigate,
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
                  _AccountFormFields(
                    nameCtrl: _nameCtrl,
                    bankCtrl: _bankCtrl,
                    tag: _tag,
                    currency: _currency,
                    baseCurrency: app.baseCurrency,
                    fallbackColorHex: tagColorHex(_tag),
                    tagOptions: kTags,
                    currencyOptions: kCurrencies,
                    onTagChanged: (v) => setState(() => _tag = v ?? _tag),
                    onCurrencyChanged: (v) => setState(() => _currency = v ?? _currency),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(onPressed: _submitNew, child: noSelect(const Text('Konto anlegen'))),
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
  const _AccountRow({required this.account, required this.onEdit, required this.onNavigate});

  final Account account;
  final VoidCallback onEdit;
  final ValueChanged<AppView> onNavigate;

  Future<void> _archive(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konto archivieren'),
        content: Text('"${account.name}" wirklich archivieren? Es verschwindet danach komplett aus allen Charts.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: noSelect(const Text('Abbrechen'))),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: noSelect(const Text('Archivieren'))),
        ],
      ),
    );
    if (confirmed == true) {
      if (!context.mounted) return;
      await context.read<AppState>().archiveAccount(account.id);
      if (!context.mounted) return;
      showSavedSnackBar(context, onNavigate, message: 'Archiviert.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: colorFromHex(account.color), shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    '${account.bank.isNotEmpty ? '${account.bank} · ' : ''}${account.tag} · ${account.currency}',
                    style: TextStyle(color: kMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            OutlinedButton(onPressed: onEdit, child: noSelect(const Text('Bearbeiten'))),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: () => _archive(context), child: noSelect(const Text('Archivieren'))),
          ],
        ),
      ),
    );
  }
}

class _AccountEditForm extends StatefulWidget {
  const _AccountEditForm({required this.account, required this.onDone, required this.onNavigate});

  final Account account;
  final VoidCallback onDone;
  final ValueChanged<AppView> onNavigate;

  @override
  State<_AccountEditForm> createState() => _AccountEditFormState();
}

class _AccountEditFormState extends State<_AccountEditForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl = TextEditingController(text: widget.account.name);
  late final TextEditingController _bankCtrl = TextEditingController(text: widget.account.bank);
  late String _tag = widget.account.tag;
  late String _currency = widget.account.currency;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bankCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Same Form + validators as the "Neues Konto" creation flow (Pflichtfeld
    // name, known-bank check inside _BankField) — editing used to bypass
    // them with separate manual checks, so a validator tightened on
    // creation silently didn't apply here.
    if (!_formKey.currentState!.validate()) return;
    final bank = _bankCtrl.text.trim();
    try {
      await context.read<AppState>().updateAccount(
        widget.account.id,
        name: _nameCtrl.text.trim(),
        bank: bank,
        tag: _tag,
        currency: _currency,
        color: bankColorHex(bank) ?? widget.account.color,
      );
      if (!mounted) return;
      showSavedSnackBar(context, widget.onNavigate);
      widget.onDone();
    } catch (err) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Fehler beim Speichern: ${describeError(err)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AccountFormFields(
                nameCtrl: _nameCtrl,
                bankCtrl: _bankCtrl,
                tag: _tag,
                currency: _currency,
                baseCurrency: context.read<AppState>().baseCurrency,
                fallbackColorHex: widget.account.color,
                tagOptions: {...kTags, _tag},
                currencyOptions: {...kCurrencies, _currency},
                onTagChanged: (v) => setState(() => _tag = v ?? _tag),
                onCurrencyChanged: (v) => setState(() => _currency = v ?? _currency),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton(onPressed: _save, child: noSelect(const Text('Speichern'))),
                  const SizedBox(width: 10),
                  OutlinedButton(onPressed: widget.onDone, child: noSelect(const Text('Abbrechen'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
