import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../utils/formatting.dart';
import '../theme.dart';

/// Custom month/year picker — WebKitGTK ships no picker UI for the native month input.
class MonthPickerField extends StatelessWidget {
  const MonthPickerField({super.key, required this.value, required this.onChanged});

  final String value; // "YYYY-MM"
  final ValueChanged<String> onChanged;

  Future<void> _open(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _MonthPickerDialog(initialValue: value),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () => _open(context),
      style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, minimumSize: const Size(180, 48)),
      child: noSelect(Text(periodLabel(value))),
    );
  }
}

class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int selectedYear;
  late int selectedMonth;
  late int viewYear;

  @override
  void initState() {
    super.initState();
    final parsed = _parsePeriod(widget.initialValue);
    final now = DateTime.now();
    selectedYear = parsed?.$1 ?? now.year;
    selectedMonth = parsed?.$2 ?? now.month;
    viewYear = selectedYear;
  }

  /// Tolerant "YYYY-MM" parse; malformed input falls back to the current month instead of throwing.
  static (int, int)? _parsePeriod(String value) {
    final parts = value.split('-');
    if (parts.length != 2) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) return null;
    return (year, month);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'Vorheriges Jahr',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => viewYear -= 1),
          ),
          Text('$viewYear', style: const TextStyle(fontWeight: FontWeight.w600)),
          IconButton(
            tooltip: 'Nächstes Jahr',
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() => viewYear += 1),
          ),
        ],
      ),
      content: SizedBox(
        width: 260,
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.7,
          children: List.generate(12, (i) {
            final month = i + 1;
            final active = viewYear == selectedYear && month == selectedMonth;
            return Semantics(
              selected: active,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: active ? kPrimary : null,
                  foregroundColor: active ? const Color(0xFF04140D) : kTextPrimary,
                  side: BorderSide(color: active ? kPrimary : kBorder),
                  padding: EdgeInsets.zero,
                ),
                onPressed: () {
                  final period = '$viewYear-${month.toString().padLeft(2, '0')}';
                  Navigator.of(context).pop(period);
                },
                child: noSelect(Text(kMonthLabels[i])),
              ),
            );
          }),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: noSelect(const Text('Abbrechen')))],
    );
  }
}
