import 'package:flutter/material.dart';

import '../theme.dart';

/// Toggles a Fixposten between income (+) and expense (−).
class SignToggle extends StatelessWidget {
  const SignToggle({super.key, required this.isExpense, required this.onChanged});

  final bool isExpense;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = isExpense ? kDanger : kPrimary;
    return Tooltip(
      message: isExpense ? 'Ausgabe' : 'Einnahme',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => onChanged(!isExpense),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.15),
            border: Border.all(color: color, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            isExpense ? '−' : '+',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
      ),
    );
  }
}
