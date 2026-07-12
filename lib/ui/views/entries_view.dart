import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/account.dart';
import '../../models/balance.dart';
import '../../state/app_state.dart';
import '../../utils/formatting.dart';
import '../app_view.dart';
import '../theme.dart';
import '../widgets/section_card.dart';

class EntriesView extends StatefulWidget {
  const EntriesView({super.key, required this.onNavigate});

  final ValueChanged<AppView> onNavigate;

  @override
  State<EntriesView> createState() => _EntriesViewState();
}

class _EntriesViewState extends State<EntriesView> {
  int? _editingBalanceId;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    if (app.balances.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            children: [
              Text('Noch keine Einträge', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text('Unter "Erfassen" kannst du deinen ersten Kontostand eintragen.', style: TextStyle(color: kMuted)),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () => widget.onNavigate(AppView.entry), child: const Text('Kontostand erfassen')),
            ],
          ),
        ),
      );
    }

    final groups = <int, List<Balance>>{};
    for (final b in app.balances) {
      groups.putIfAbsent(b.accountId, () => []).add(b);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bestehende Kontostände korrigieren oder löschen.', style: TextStyle(color: kMuted)),
          const SizedBox(height: 16),
          for (final entry in groups.entries) ...[
            _AccountEntriesSection(
              account: app.accounts.where((a) => a.id == entry.key).isEmpty
                  ? null
                  : app.accounts.firstWhere((a) => a.id == entry.key),
              balances: entry.value,
              editingId: _editingBalanceId,
              onEdit: (id) => setState(() => _editingBalanceId = id),
              onDoneEdit: () => setState(() => _editingBalanceId = null),
            ),
            cardGap,
          ],
        ],
      ),
    );
  }
}

class _AccountEntriesSection extends StatelessWidget {
  const _AccountEntriesSection({
    required this.account,
    required this.balances,
    required this.editingId,
    required this.onEdit,
    required this.onDoneEdit,
  });

  final Account? account;
  final List<Balance> balances;
  final int? editingId;
  final ValueChanged<int> onEdit;
  final VoidCallback onDoneEdit;

  @override
  Widget build(BuildContext context) {
    final sorted = [...balances]..sort((a, b) => b.period.compareTo(a.period));

    return SectionCard(
      title: account?.name ?? '(archiviertes/gelöschtes Konto)',
      child: Column(
        children: [
          for (final bal in sorted)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: bal.id == editingId
                  ? _EditRow(balance: bal, onDone: onDoneEdit)
                  : _DisplayRow(balance: bal, accountName: account?.name ?? 'Konto', onEdit: () => onEdit(bal.id)),
            ),
        ],
      ),
    );
  }
}

class _DisplayRow extends StatelessWidget {
  const _DisplayRow({required this.balance, required this.accountName, required this.onEdit});

  final Balance balance;
  final String accountName;
  final VoidCallback onEdit;

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eintrag löschen'),
        content: Text('Eintrag für $accountName · ${periodLabel(balance.period)} wirklich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed == true) {
      if (!context.mounted) return;
      await context.read<AppState>().deleteBalance(balance.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 110, child: Text(periodLabel(balance.period))),
        Expanded(child: Text(fmtMoney(balance.amountOriginal, balance.currencyOriginal))),
        OutlinedButton(onPressed: onEdit, child: const Text('Bearbeiten')),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: () => _delete(context), child: const Text('Löschen')),
      ],
    );
  }
}

class _EditRow extends StatefulWidget {
  const _EditRow({required this.balance, required this.onDone});

  final Balance balance;
  final VoidCallback onDone;

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bitte einen gültigen Betrag eingeben.')));
      return;
    }
    try {
      final amountBase = amount * widget.balance.rate;
      await context.read<AppState>().updateBalance(widget.balance.id, amountOriginal: amount, amountBase: amountBase);
      widget.onDone();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler beim Speichern: $err')));
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
        ElevatedButton(onPressed: _save, child: const Text('Speichern')),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: widget.onDone, child: const Text('Abbrechen')),
      ],
    );
  }
}
