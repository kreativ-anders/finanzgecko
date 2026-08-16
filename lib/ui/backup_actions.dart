import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/backup_crypto.dart';
import '../state/app_state.dart';
import '../utils/csv_export.dart';
import '../utils/formatting.dart';
import 'app_view.dart';
import 'theme.dart';
import 'widgets/app_snackbar.dart';
import 'widgets/backup_passphrase_dialog.dart';

/// Export/import flow for backups. Pure UI orchestration — persistence, schema
/// checking, bank→colour derivation and encryption live in [AppState]/AppStore
/// (see `# Quelle:` in gherkin/backup_restore.feature).
///
/// Free functions rather than methods in `navigation_shell.dart`, so the
/// navigation shell and the backup flow each have their own primary file.

const _backupTypeGroups = [
  XTypeGroup(label: 'JSON-Backup', extensions: ['json']),
];

Future<void> exportBackup(BuildContext context, ValueChanged<AppView> onNavigate) async {
  final appState = context.read<AppState>();
  final exportData = appState.exportAllData();
  final suggestedName = 'finanzgecko-backup-${todayISO()}.json';

  // Password prompt before the file dialog: it concerns the content, not the
  // location. Empty string = deliberately no password, null = cancelled — the
  // two must not be confused, or a cancellation would turn into an unprotected
  // export.
  final passphrase = await promptNewBackupPassphrase(context);
  if (passphrase == null) return;

  final location = await getSaveLocation(suggestedName: suggestedName, acceptedTypeGroups: _backupTypeGroups);
  if (location == null) return; // dialog cancelled

  try {
    // Without a password, exactly the previous plaintext JSON — existing flows
    // and older app versions keep reading it unchanged.
    final jsonStr = passphrase.isEmpty
        ? const JsonEncoder.withIndent('  ').convert(exportData)
        : await encryptBackup(exportData, passphrase);
    await File(location.path).writeAsString(jsonStr);
    await appState.markExported();
    if (!context.mounted) return;
    showSavedSnackBar(
      context,
      onNavigate,
      message: passphrase.isEmpty ? 'Backup exportiert.' : 'Backup exportiert und mit Passwort geschützt.',
    );
  } catch (err) {
    if (!context.mounted) return;
    showErrorSnackBar(context, 'Export fehlgeschlagen: $err');
  }
}

/// Exports the data as CSV tables — one file per domain (Konten, Kontostände,
/// Fixposten, Vermögenswerte), all written into one folder the user picks.
/// Unlike the JSON backup this is lossy and read-only, so it deliberately does
/// NOT count as a backup (no `markExported`, does not reset the backup
/// reminder).
Future<void> exportCsvTables(BuildContext context, ValueChanged<AppView> onNavigate) async {
  final appState = context.read<AppState>();
  final files = buildCsvExports(
    accounts: appState.allAccountsIncludingArchived(),
    balances: appState.balances,
    subscriptions: appState.subscriptions,
    assets: appState.assets,
    baseCurrency: appState.baseCurrency,
    dateStamp: todayISO(),
  );

  // A folder, not four save dialogs: the tables only make sense together (the
  // Konto-ID column joins Konten and Kontostände), and fixed file names keep a
  // re-export recognizable next to the previous one.
  final directoryPath = await getDirectoryPath(confirmButtonText: 'Exportieren');
  if (directoryPath == null) return; // dialog cancelled

  final targets = [for (final f in files) File('$directoryPath${Platform.pathSeparator}${f.fileName}')];

  // The folder picker — unlike the save dialog — never asks about overwriting,
  // so ask once here for the whole set instead of silently replacing an
  // earlier export.
  final existing = targets.where((f) => f.existsSync()).length;
  if (existing > 0) {
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dateien überschreiben?'),
        content: Text(
          existing == 1
              ? 'In diesem Ordner existiert bereits eine CSV-Datei von heute. Sie wird überschrieben.'
              : 'In diesem Ordner existieren bereits $existing CSV-Dateien von heute. Sie werden überschrieben.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: noSelect(const Text('Abbrechen'))),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: noSelect(const Text('Überschreiben'))),
        ],
      ),
    );
    if (confirmed != true) return;
  }

  try {
    for (var i = 0; i < files.length; i++) {
      // Leading BOM so Excel opens the UTF-8 file with correct umlauts.
      await targets[i].writeAsString('\u{FEFF}${files[i].content}');
    }
    if (!context.mounted) return;
    showSavedSnackBar(context, onNavigate, message: '${files.length} CSV-Tabellen exportiert.');
  } catch (err) {
    if (!context.mounted) return;
    showErrorSnackBar(context, 'CSV-Export fehlgeschlagen: $err');
  }
}

Future<void> importBackup(BuildContext context, ValueChanged<AppView> onNavigate) async {
  final appState = context.read<AppState>();
  final file = await openFile(acceptedTypeGroups: _backupTypeGroups);
  if (file == null) return; // dialog cancelled

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
    final decoded = jsonDecode(raw);

    // The import recognises encrypted backups by their structure, not by file
    // extension or name — a plaintext backup takes the previous path unchanged
    // and asks for nothing.
    Map<String, dynamic>? payload;
    if (isEncryptedBackup(decoded)) {
      var wasWrong = false;
      while (payload == null) {
        if (!context.mounted) return;
        final passphrase = await promptExistingBackupPassphrase(context, wasWrong: wasWrong);
        if (passphrase == null) return; // cancelled: nothing was changed
        try {
          payload = await decryptBackup(decoded as Map, passphrase);
        } on WrongBackupPassphraseException {
          // Ask again instead of aborting — a typo should not cost the whole
          // flow.
          wasWrong = true;
        }
      }
    } else if (decoded is Map<String, dynamic>) {
      payload = decoded;
    } else {
      throw const FormatException('Backup-JSON ist kein Objekt');
    }

    await appState.importAllData(payload);
    if (!context.mounted) return;
    onNavigate(AppView.dashboard);
    showSavedSnackBar(context, onNavigate, message: 'Import abgeschlossen.');
  } catch (err) {
    if (!context.mounted) return;
    showErrorSnackBar(context, 'Import fehlgeschlagen: ${describeError(err)}');
  }
}
