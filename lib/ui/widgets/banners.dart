import 'package:flutter/material.dart';

import '../theme.dart';

class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Expanded(child: Text('⚠️ $message')),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 12),
            OutlinedButton(onPressed: onAction, child: noSelect(Text(actionLabel!))),
          ],
        ],
      ),
    );
  }
}

/// Deliberately louder than [InfoBanner]: expenses exceeding income should
/// jump out immediately.
class OverspendBanner extends StatelessWidget {
  const OverspendBanner({super.key, required this.expenseText, required this.incomeText, required this.onCheck});

  final String expenseText;
  final String incomeText;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(color: kDanger, borderRadius: BorderRadius.circular(12)),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 480,
            child: Text(
              'Deine wiederkehrenden Ausgaben ($expenseText/Monat) übersteigen deine wiederkehrenden Einnahmen ($incomeText/Monat)!',
              style: const TextStyle(color: Color(0xFF2B0000), fontWeight: FontWeight.w700, height: 1.4),
            ),
          ),
          ElevatedButton(
            onPressed: onCheck,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2B0000),
              foregroundColor: const Color(0xFFFFE6E6),
            ),
            child: noSelect(const Text('Fixposten prüfen')),
          ),
        ],
      ),
    );
  }
}
