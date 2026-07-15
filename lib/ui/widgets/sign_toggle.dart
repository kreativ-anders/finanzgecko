import 'package:flutter/material.dart';

import '../theme.dart';

/// Toggles a Fixposten between income (+) and expense (−).
///
/// Wrapped in an [InputDecorator] using the app's shared input decoration
/// theme, so it renders with the exact same border, fill and floating
/// "Typ" label as the neighboring [TextFormField]s in the row — matching
/// their height and baseline instead of a fixed-size circle guessed to fit.
class SignToggle extends StatelessWidget {
  const SignToggle({super.key, required this.isExpense, required this.onChanged});

  final bool isExpense;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = isExpense ? kDanger : kPrimary;
    // Reuses the theme's default input text style (the same one TextField
    // applies to its editable text) so this decorator's content line box —
    // and therefore its overall height — matches the neighboring text
    // fields exactly, instead of drifting out of sync with a custom style.
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
