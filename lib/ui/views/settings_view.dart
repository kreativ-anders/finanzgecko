import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/section_card.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key, required this.onExport, required this.onImport});

  final Future<void> Function() onExport;
  final Future<void> Function() onImport;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lastExport = app.store.lastExportAt;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionCard(
            title: 'Basiswährung',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Alle Beträge werden für Dashboard-Ansichten in diese Währung umgerechnet.', style: TextStyle(color: kMuted)),
                const SizedBox(height: 12),
                DropdownButton<String>(
                  value: app.baseCurrency,
                  items: [for (final c in kCurrencies) DropdownMenuItem(value: c, child: Text(c))],
                  onChanged: (v) {
                    if (v != null) context.read<AppState>().setBaseCurrency(v);
                  },
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
                DropdownButton<String>(
                  value: app.defaultSubscriptionInterval,
                  items: [for (final i in kSubscriptionIntervals) DropdownMenuItem(value: i.value, child: Text(i.label))],
                  onChanged: (v) {
                    if (v != null) context.read<AppState>().setDefaultSubscriptionInterval(v);
                  },
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
                ElevatedButton(onPressed: onExport, child: const Text('Backup exportieren…')),
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
                OutlinedButton(onPressed: onImport, child: const Text('Backup importieren…')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime date) {
  final d = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  final t = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  return '$d, $t';
}
