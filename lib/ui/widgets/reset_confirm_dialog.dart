import 'package:flutter/material.dart';

import '../theme.dart';

const String _confirmPhrase = 'ZURÜCKSETZEN';

/// Asks the user to type [_confirmPhrase] before allowing the irreversible
/// "reset app + delete all data" action — a typed confirmation, rather than
/// a plain Ja/Nein dialog, guards against an accidental click on something
/// this destructive.
Future<bool> confirmReset(BuildContext context) async {
  final ctrl = TextEditingController();
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final matches = ctrl.text.trim() == _confirmPhrase;
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: kDanger),
              SizedBox(width: 10),
              Text('App wirklich zurücksetzen?'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Alle Konten, Kontostände, Vermögenswerte und Fixposten werden unwiderruflich gelöscht. '
                'Die Basiswährung wird auf ihren Standardwert zurückgesetzt.',
              ),
              const SizedBox(height: 14),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Gib zum Bestätigen '),
                    TextSpan(
                      text: _confirmPhrase,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: kDanger),
                    ),
                    const TextSpan(text: ' ein:'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: _confirmPhrase),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: noSelect(const Text('Abbrechen'))),
            ElevatedButton(
              onPressed: matches ? () => Navigator.of(ctx).pop(true) : null,
              style: ElevatedButton.styleFrom(backgroundColor: kDanger, foregroundColor: Colors.white),
              child: noSelect(const Text('Endgültig zurücksetzen')),
            ),
          ],
        );
      },
    ),
  );
  return result == true;
}
