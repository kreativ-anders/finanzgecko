import 'package:flutter/material.dart';

import '../theme.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, this.trailing, required this.child, this.expandChild = false});

  final String? title;
  final Widget child;

/// Shown at the end of the title row — ignored unless [title] is set.
  final Widget? trailing;

/// When true, lets [child] fill the card's remaining height so equal-height cards can pin content.
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
// Expanded so the trailing widget is pinned right and a wide filter row wraps instead of overflowing.
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
      style: TextStyle(color: kMuted, fontStyle: FontStyle.italic),
    );
  }
}
