import 'package:flutter/material.dart';

import '../../utils/formatting.dart';
import '../theme.dart';

/// Asks for a manual "1 [from] = ? [to]" rate; [reason] names the real cause instead of guessing "(offline?)".
Future<double?> promptManualRate(
  BuildContext context, {
  required String from,
  required String to,
  String? reason,
}) async {
  final ctrl = TextEditingController();
  try {
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kein Wechselkurs verfügbar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reason ?? 'Für $from → $to liegt kein Wechselkurs vor.'),
            const SizedBox(height: 8),
            Text('Bitte Kurs manuell eingeben:', style: TextStyle(color: kMuted)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: '1 $from = ? $to'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: noSelect(const Text('Abbrechen'))),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(parseInputNumber(ctrl.text)),
            child: noSelect(const Text('Übernehmen')),
          ),
        ],
      ),
    );
    return (result != null && result > 0) ? result : null;
  } finally {
    ctrl.dispose();
  }
}
