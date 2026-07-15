import 'package:flutter/material.dart';

import '../theme.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, this.trailing, required this.child, this.expandChild = false});

  final String? title;
  final Widget child;

  /// Shown at the end of the title row (e.g. a filter control) — ignored
  /// unless [title] is also set.
  final Widget? trailing;

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
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(title!, style: Theme.of(context).textTheme.titleLarge),
                  // Expanded (not just trailing inline) so it's pinned to the
                  // card's top-right; bounding its width also lets a wide
                  // filter row wrap onto a second line instead of overflowing.
                  if (trailing != null)
                    Expanded(
                      child: Align(alignment: Alignment.centerRight, child: trailing!),
                    ),
                ],
              ),
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
    return Text(
      text,
      style: const TextStyle(color: kMuted, fontStyle: FontStyle.italic),
    );
  }
}
