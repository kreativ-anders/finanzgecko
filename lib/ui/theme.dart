import 'package:flutter/material.dart';

const Color kBackground = Color(0xFF0A0F0C);
const Color kSurface = Color(0xFF101713);
const Color kBorder = Color(0xFF1C2721);
const Color kMuted = Color(0xFF7C8A83);
// Keep in sync with kPrimaryHex/kDangerHex in constants.dart (those are the
// string form used for on-disk account colors; these are the const Color
// form needed for widget themes/const constructors).
const Color kPrimary = Color(0xFF00C878);
const Color kDanger = Color(0xFFFF6B6B);

// Trend-line direction colors (see AppLineChart) — deliberately lighter/more
// muted than kPrimary/kDanger so the dashed projection stays visually
// secondary to the actual data line.
const Color kTrendUp = Color(0xFF8FE3B3);
const Color kTrendDown = Color(0xFFFFC98A);
const Color kTrendNeutral = Color(0xFFA6B0A9);

/// Excludes [child] from the app-wide [SelectionArea] (see main.dart) —
/// for button labels and nav chrome, which aren't meant to be copyable.
Widget noSelect(Widget child) => SelectionContainer.disabled(child: child);

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: kPrimary,
    brightness: Brightness.dark,
  ).copyWith(primary: kPrimary, surface: kSurface, error: kDanger);

  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: kBorder),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: kBackground,
    canvasColor: kBackground,
    dividerColor: kBorder,
    cardTheme: const CardThemeData(
      color: kSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: kBorder),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kBackground,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: BorderSide(color: kPrimary, width: 1.5)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimary,
        foregroundColor: const Color(0xFF04140D),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: kBorder),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: kPrimary)),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected) ? const Color(0xFF04140D) : kMuted;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected) ? kPrimary : kSurface;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected) ? Colors.transparent : kBorder;
      }),
    ),
    scrollbarTheme: const ScrollbarThemeData(),
    dialogTheme: const DialogThemeData(backgroundColor: kSurface),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: kSurface,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
  );
}
