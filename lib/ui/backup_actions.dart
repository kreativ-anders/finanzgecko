import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../utils/csv_export.dart';
import '../utils/formatting.dart';
import 'app_view.dart';
import 'theme.dart';
import 'widgets/app_snackbar.dart';

/// Export-/Import-Fluss für Backups (native Datei-Dialoge, Sicherheitsabfrage,
/// Bestätigungs-/Fehler-Snackbars). Reine UI-Orchestrierung — die eigentliche
/// Persistenz, Schemaprüfung, Bank→Farbe-Ableitung und Verschlüsselung liegen
/// in [AppState]/AppStore (siehe `# Quelle:` in gherkin/backup_restore.feature).
///
/// Bewusst als freie Funktionen (statt Methoden in `navigation_shell.dart`), damit die
/// Navigations-Shell (Feature `navigation`) und der Backup-Fluss (Feature
/// `backup_restore`) je eine eigene Primär-Datei haben. `onNavigate` dient den
/// Snackbar-Aktionen und dem Sprung aufs Dashboard nach erfolgreichem Import.

const _backupTypeGroups = [
  XTypeGroup(label: 'JSON-Backup', extensions: ['json']),
];

const _csvTypeGroups = [
  XTypeGroup(label: 'CSV', extensions: ['csv']),
];

Future<void> exportBackup(BuildContext context, ValueChanged<AppView> onNavigate) async {
  final appState = context.read<AppState>();
  final exportData = appState.exportAllData();
  final suggestedName = 'finanzgecko-backup-${todayISO()}.json';

  final location = await getSaveLocation(suggestedName: suggestedName, acceptedTypeGroups: _backupTypeGroups);
  if (location == null) return; // Dialog abgebrochen

  try {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(exportData);
    await File(location.path).writeAsString(jsonStr);
    await appState.markExported();
    if (!context.mounted) return;
    showSavedSnackBar(context, onNavigate, message: 'Backup exportiert.');
  } catch (err) {
    if (!context.mounted) return;
    showErrorSnackBar(context, 'Export fehlgeschlagen: $err');
  }
}

/// Exportiert die Kontostände als CSV-Tabelle (für Tabellenkalkulationen).
/// Anders als das JSON-Backup ist das verlustbehaftet und nur lesend, zählt
/// daher bewusst NICHT als Backup (kein `markExported`, setzt den
/// Backup-Reminder nicht zurück).
Future<void> exportBalancesCsv(BuildContext context, ValueChanged<AppView> onNavigate) async {
  final appState = context.read<AppState>();
  final csv = buildBalancesCsv(
    appState.allAccountsIncludingArchived(),
    appState.balances,
    baseCurrency: appState.baseCurrency,
  );
  final suggestedName = 'finanzgecko-kontostaende-${todayISO()}.csv';

  final location = await getSaveLocation(suggestedName: suggestedName, acceptedTypeGroups: _csvTypeGroups);
  if (location == null) return; // Dialog abgebrochen

  try {
    // Leading BOM so Excel opens the UTF-8 file with correct umlauts.
    await File(location.path).writeAsString('\u{FEFF}$csv');
    if (!context.mounted) return;
    showSavedSnackBar(context, onNavigate, message: 'CSV exportiert.');
  } catch (err) {
    if (!context.mounted) return;
    showErrorSnackBar(context, 'CSV-Export fehlgeschlagen: $err');
  }
}

Future<void> importBackup(BuildContext context, ValueChanged<AppView> onNavigate) async {
  final appState = context.read<AppState>();
  final file = await openFile(acceptedTypeGroups: _backupTypeGroups);
  if (file == null) return; // Dialog abgebrochen

  if (!context.mounted) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Backup importieren'),
      content: const Text('Import ersetzt ALLE aktuellen Daten. Fortfahren?'),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: noSelect(const Text('Abbrechen'))),
        ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: noSelect(const Text('Importieren'))),
      ],
    ),
  );
  if (confirmed != true) return;

  try {
    final raw = await file.readAsString();
    final imported = jsonDecode(raw) as Map<String, dynamic>;
    await appState.importAllData(imported);
    if (!context.mounted) return;
    onNavigate(AppView.dashboard);
    showSavedSnackBar(context, onNavigate, message: 'Import abgeschlossen.');
  } catch (err) {
    if (!context.mounted) return;
    showErrorSnackBar(context, 'Import fehlgeschlagen: ${describeError(err)}');
  }
}
