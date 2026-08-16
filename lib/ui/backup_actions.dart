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

const _csvTypeGroups = [
  XTypeGroup(label: 'CSV', extensions: ['csv']),
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

/// Exports the Kontostände as a CSV table (for spreadsheets). Unlike the JSON
/// backup this is lossy and read-only, so it deliberately does NOT count as a
/// backup (no `markExported`, does not reset the backup reminder).
Future<void> exportBalancesCsv(BuildContext context, ValueChanged<AppView> onNavigate) async {
  final appState = context.read<AppState>();
  final csv = buildBalancesCsv(
    appState.allAccountsIncludingArchived(),
    appState.balances,
    baseCurrency: appState.baseCurrency,
  );
  final suggestedName = 'finanzgecko-kontostaende-${todayISO()}.csv';

  final location = await getSaveLocation(suggestedName: suggestedName, acceptedTypeGroups: _csvTypeGroups);
  if (location == null) return; // dialog cancelled

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
