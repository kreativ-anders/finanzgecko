import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../utils/formatting.dart';
import '../theme.dart';

/// Round color swatch of a Konto or Bank.
class ColorDot extends StatelessWidget {
  const ColorDot({super.key, required this.color, this.size = 12});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// "Bank · Typ · Währung" — the bank is dropped when empty.
String accountDetails(Account account) =>
    [if (account.bank.isNotEmpty) account.bank, account.tag, account.currency].join(' · ');

/// Identity of a Konto as shown in Konten and Einträge: color dot, name, [accountDetails] and an optional [note].
class AccountLabel extends StatelessWidget {
  const AccountLabel({super.key, required this.account, this.note});

  final Account account;

  /// Extra muted line below the details, e.g. the last recorded Kontostand.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(color: kMuted, fontSize: 13);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Centers the dot on the name's first line instead of on the whole block.
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: ColorDot(color: colorFromHex(account.color)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(account.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(accountDetails(account), style: muted),
              if (note != null) Text(note!, style: muted.copyWith(fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}
