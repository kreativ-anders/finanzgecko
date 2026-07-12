import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/reset_confirm_dialog.dart';
import '../widgets/section_card.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key, required this.onExport, required this.onImport});

  final Future<void> Function() onExport;
  final Future<void> Function() onImport;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lastExport = app.store.lastExportAt;
    final modKeyLabel = Platform.isMacOS ? '⌘' : 'Strg';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: 'Basiswährung',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Alle Beträge werden für Dashboard-Ansichten in diese Währung umgerechnet.', style: TextStyle(color: kMuted)),
                const SizedBox(height: 12),
                SizedBox(
                  width: 280,
                  child: DropdownButtonFormField<String>(
                    initialValue: app.baseCurrency,
                    isExpanded: true,
                    items: [for (final c in kCurrencies) DropdownMenuItem(value: c, child: Text(c))],
                    onChanged: (v) {
                      if (v != null) context.read<AppState>().setBaseCurrency(v);
                    },
                  ),
                ),
              ],
            ),
          ),
          cardGap,
          SectionCard(
            title: 'Standardintervall für Fixposten',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Wird beim Anlegen eines neuen Fixpostens vorausgewählt. Monatlich passt für die meisten, da '
                  'Gehalt in der Regel monatlich eingeht.',
                  style: TextStyle(color: kMuted),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 280,
                  child: DropdownButtonFormField<String>(
                    initialValue: app.defaultSubscriptionInterval,
                    isExpanded: true,
                    items: [for (final i in kSubscriptionIntervals) DropdownMenuItem(value: i.value, child: Text(i.label))],
                    onChanged: (v) {
                      if (v != null) context.read<AppState>().setDefaultSubscriptionInterval(v);
                    },
                  ),
                ),
              ],
            ),
          ),
          cardGap,
          SectionCard(
            title: 'Export',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Schreibt eine unverschlüsselte JSON-Datei mit allen Konten und Kontoständen an einen Ort deiner Wahl.', style: TextStyle(color: kMuted)),
                const SizedBox(height: 6),
                Text(
                  lastExport != null ? 'Letzter Export: ${_formatDateTime(lastExport)}' : 'Noch nie exportiert.',
                  style: const TextStyle(color: kMuted, fontSize: 13),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(onPressed: onExport, child: noSelect(const Text('Backup exportieren…'))),
                    const SizedBox(width: 10),
                    Text('$modKeyLabel+E', style: const TextStyle(color: kMuted, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          cardGap,
          SectionCard(
            title: 'Import',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: 'Achtung: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: 'Der Import ersetzt alle aktuell gespeicherten Daten vollständig.'),
                    ],
                  ),
                  style: TextStyle(color: kMuted),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(onPressed: onImport, child: noSelect(const Text('Backup importieren…'))),
                    const SizedBox(width: 10),
                    Text('$modKeyLabel+I', style: const TextStyle(color: kMuted, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          cardGap,
          Container(
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kDanger.withValues(alpha: 0.4)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: kDanger, size: 20),
                    const SizedBox(width: 8),
                    Text('Zurücksetzen', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: kDanger)),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Setzt Basiswährung und Standardintervall auf ihre Standardwerte zurück und löscht ALLE Konten, '
                  'Kontostände, Vermögenswerte und Fixposten unwiderruflich.',
                  style: TextStyle(color: kMuted),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Erstelle vorher ggf. ein Backup über den Export oben — diese Aktion kann nicht rückgängig gemacht werden.',
                  style: TextStyle(color: kMuted),
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: () => _handleReset(context),
                  style: OutlinedButton.styleFrom(foregroundColor: kDanger, side: const BorderSide(color: kDanger)),
                  child: noSelect(const Text('App zurücksetzen…')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleReset(BuildContext context) async {
    final confirmed = await confirmReset(context);
    if (!confirmed) return;
    if (!context.mounted) return;
    await context.read<AppState>().resetAllData();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('App wurde auf Standardwerte zurückgesetzt.')));
  }
}

String _formatDateTime(DateTime date) {
  final d = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  final t = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  return '$d, $t';
}
