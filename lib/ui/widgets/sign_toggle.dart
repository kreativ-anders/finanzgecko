import 'package:flutter/material.dart';

import '../theme.dart';

/// Toggles a Fixposten between income (+) and expense (−), in an [InputDecorator] to match field height.
class SignToggle extends StatelessWidget {
  const SignToggle({super.key, required this.isExpense, required this.onChanged});

  final bool isExpense;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = isExpense ? kDangerText : kPrimaryText;
    // Reuses the theme's input text style so this decorator's height matches the neighboring text fields.
    final textStyle = (Theme.of(context).textTheme.bodyLarge ?? const TextStyle()).copyWith(
      color: color,
      fontWeight: FontWeight.bold,
    );
    return SizedBox(
      width: 64,
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Typ'),
        child: Tooltip(
          message: isExpense ? 'Ausgabe' : 'Einnahme',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: InkWell(
              onTap: () => onChanged(!isExpense),
              child: Center(child: noSelect(Text(isExpense ? '−' : '+', style: textStyle))),
            ),
          ),
        ),
      ),
    );
  }
}
