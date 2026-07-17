import 'package:flutter/material.dart';

import '../../utils/formatting.dart';
import '../theme.dart';

/// Asks the user for a manual "1 [from] = ? [to]" rate when neither the live
/// API nor the local cache has one (e.g. offline on first use of a currency
/// pair). Returns null if cancelled or the input isn't a valid positive number.
Future<double?> promptManualRate(BuildContext context, {required String from, required String to}) async {
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
            Text('Kein Wechselkurs $from → $to verfügbar (offline?). Bitte Kurs manuell eingeben:'),
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
