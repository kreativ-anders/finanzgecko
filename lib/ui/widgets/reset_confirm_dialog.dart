import 'package:flutter/material.dart';

import '../theme.dart';

const String _confirmPhrase = 'ZURÜCKSETZEN';

/// Requires typing [_confirmPhrase] before the irreversible reset — see dev/ai/ui-conventions.md.
Future<bool> confirmReset(BuildContext context) async {
  final ctrl = TextEditingController();
  try {
    return await _showConfirmResetDialog(context, ctrl) == true;
  } finally {
    ctrl.dispose();
  }
}

Future<bool?> _showConfirmResetDialog(BuildContext context, TextEditingController ctrl) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final matches = ctrl.text.trim() == _confirmPhrase;
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: kDangerText),
              const SizedBox(width: 10),
              const Text('App wirklich zurücksetzen?'),
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
                      style: TextStyle(fontWeight: FontWeight.bold, color: kDangerText),
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
// INFO: near-black on kDanger — white text there measures ~2.8:1, short of WCAG AA.
              style: ElevatedButton.styleFrom(backgroundColor: kDanger, foregroundColor: const Color(0xFF2B0000)),
              child: noSelect(const Text('Endgültig zurücksetzen')),
            ),
          ],
        );
      },
    ),
  );
}
