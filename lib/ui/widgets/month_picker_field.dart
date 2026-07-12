import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../utils/formatting.dart';
import '../theme.dart';

/// Custom month/year picker, replacing the native <input type="month">
/// equivalent — WebKitGTK didn't implement a picker UI for it, and the same
/// custom widget now works identically across every desktop platform.
class MonthPickerField extends StatelessWidget {
  const MonthPickerField({super.key, required this.value, required this.onChanged});

  final String value; // "YYYY-MM"
  final ValueChanged<String> onChanged;

  Future<void> _open(BuildContext context) async {
    final result = await showDialog<String>(context: context, builder: (ctx) => _MonthPickerDialog(initialValue: value));
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () => _open(context),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        minimumSize: const Size(180, 48),
      ),
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
    final parts = widget.initialValue.split('-');
    selectedYear = int.parse(parts[0]);
    selectedMonth = int.parse(parts[1]);
    viewYear = selectedYear;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => viewYear -= 1)),
          Text('$viewYear', style: const TextStyle(fontWeight: FontWeight.w600)),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => viewYear += 1)),
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
            return OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: active ? kPrimary : null,
                foregroundColor: active ? const Color(0xFF04140D) : Colors.white,
                side: BorderSide(color: active ? kPrimary : kBorder),
                padding: EdgeInsets.zero,
              ),
              onPressed: () {
                final period = '$viewYear-${month.toString().padLeft(2, '0')}';
                Navigator.of(context).pop(period);
              },
              child: noSelect(Text(kMonthLabels[i])),
            );
          }),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: noSelect(const Text('Abbrechen')))],
    );
  }
}
