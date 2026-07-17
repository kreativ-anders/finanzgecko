import 'package:flutter/material.dart';

import '../theme.dart';

/// Distinguishes a routine nudge from a genuinely overdue/urgent state — both
/// render as the same neutral [InfoBanner] shell, but sharing one warning
/// icon for both made a "you haven't entered this month yet" nudge look as
/// urgent as "backup 45 days overdue". Only [urgent] gets the warning glyph.
enum BannerUrgency { nudge, urgent }

class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.message, this.actionLabel, this.onAction, this.urgency = BannerUrgency.urgent});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final BannerUrgency urgency;

  @override
  Widget build(BuildContext context) {
    final icon = urgency == BannerUrgency.urgent ? '⚠️' : 'ℹ️';
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
          Expanded(child: Text('$icon $message')),
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
