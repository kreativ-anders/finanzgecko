import 'package:flutter/material.dart';

import '../theme.dart';

/// Result of [promptNewBackupPassphrase]: empty string = deliberately no
/// password, null = dialog cancelled. Keeping these distinct matters —
/// "cancelled" must never trigger an unprotected export.
typedef BackupPassphraseChoice = String?;

/// Asks on export whether the backup should be password-protected.
///
/// Both paths are their own button instead of "leave the field empty":
/// encryption should be a decision made on purpose, not skipped by accident.
Future<BackupPassphraseChoice> promptNewBackupPassphrase(BuildContext context) async {
  final pwCtrl = TextEditingController();
  final repeatCtrl = TextEditingController();
  try {
    return await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final pw = pwCtrl.text;
          final repeat = repeatCtrl.text;
          final mismatch = repeat.isNotEmpty && pw != repeat;
          final canProtect = pw.isNotEmpty && pw == repeat;
          return AlertDialog(
            title: const Text('Backup exportieren'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Du kannst das Backup mit einem Passwort schützen. Dann kann nur jemand, der das Passwort '
                    'kennt, die Datei lesen — sinnvoll, wenn du sie in eine Cloud oder auf einen USB-Stick legst.',
                    style: TextStyle(color: kMuted, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: pwCtrl,
                    autofocus: true,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Passwort'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: repeatCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Passwort wiederholen',
                      errorText: mismatch ? 'Die beiden Eingaben stimmen nicht überein.' : null,
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {
                      if (canProtect) Navigator.of(ctx).pop(pwCtrl.text);
                    },
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Merk dir das Passwort gut: ohne es lässt sich dieses Backup nicht mehr öffnen. Deine Daten '
                    'in der App bleiben davon unberührt.',
                    style: TextStyle(color: kMuted, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: noSelect(const Text('Abbrechen'))),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(''),
                child: noSelect(const Text('Ohne Passwort')),
              ),
              ElevatedButton(
                onPressed: canProtect ? () => Navigator.of(ctx).pop(pwCtrl.text) : null,
                child: noSelect(const Text('Mit Passwort schützen')),
              ),
            ],
          );
        },
      ),
    );
  } finally {
    pwCtrl.dispose();
    repeatCtrl.dispose();
  }
}

/// Asks on import for the password of a protected backup file.
/// Null = cancelled. [wasWrong] shows the hint after a failed attempt,
/// instead of just re-showing the dialog without comment.
Future<String?> promptExistingBackupPassphrase(BuildContext context, {bool wasWrong = false}) async {
  final ctrl = TextEditingController();
  try {
    return await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backup ist mit einem Passwort geschützt'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Diese Datei lässt sich nur mit dem Passwort öffnen, das beim Export vergeben wurde.',
                style: TextStyle(color: kMuted, height: 1.4),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                autofocus: true,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Passwort',
                  errorText: wasWrong ? 'Das Passwort stimmt nicht.' : null,
                ),
                onSubmitted: (v) => Navigator.of(ctx).pop(v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: noSelect(const Text('Abbrechen'))),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: noSelect(const Text('Entsperren')),
          ),
        ],
      ),
    );
  } finally {
    ctrl.dispose();
  }
}
