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

/// Export/import flow for backups; persistence, schema checks and encryption live in [AppState].

const _backupTypeGroups = [
  XTypeGroup(label: 'JSON-Backup', extensions: ['json']),
];

Future<void> exportBackup(BuildContext context, ValueChanged<AppView> onNavigate) async {
  final appState = context.read<AppState>();
  final exportData = appState.exportAllData();
  final suggestedName = 'finanzgecko-backup-${todayISO()}.json';

  // WARNING: empty means deliberately no password, null means cancelled — confusing them exports unprotected.
  final passphrase = await promptNewBackupPassphrase(context);
  if (passphrase == null) return;

  final location = await getSaveLocation(suggestedName: suggestedName, acceptedTypeGroups: _backupTypeGroups);
  if (location == null) return; // dialog cancelled

  try {
    // Without a password, byte-identical plaintext JSON so older app versions keep reading it.
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

/// Exports lossy, read-only CSV tables; deliberately not a backup (no `markExported`, no reminder reset).
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

  // One folder instead of four save dialogs: the tables only make sense together.
  final directoryPath = await getDirectoryPath(confirmButtonText: 'Exportieren');
  if (directoryPath == null) return; // dialog cancelled

  final targets = [for (final f in files) File('$directoryPath${Platform.pathSeparator}${f.fileName}')];

  // The folder picker never asks about overwriting, so ask once here for the whole set.
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

    // Encrypted backups are recognised by their structure, not by file extension or name.
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
          // Ask again instead of aborting — a typo should not cost the whole flow.
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
