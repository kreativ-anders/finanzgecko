import 'package:flutter/material.dart';

import '../theme.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, required this.child, this.expandChild = false});

  final String? title;
  final Widget child;

  /// When true, lets [child] grow to fill the card's remaining height —
  /// used so cards of equal height (see [cardGap] usage in `_SummaryRow`)
  /// can pin content like a trailing button to the bottom.
  final bool expandChild;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title!, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
            ],
            expandChild ? Expanded(child: child) : child,
          ],
        ),
      ),
    );
  }
}

/// Vertical gap used consistently between stacked [SectionCard]s.
const Widget cardGap = SizedBox(height: 20);

class EmptyHint extends StatelessWidget {
  const EmptyHint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: kMuted, fontStyle: FontStyle.italic));
  }
}
