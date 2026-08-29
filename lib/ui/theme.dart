import 'package:flutter/material.dart';

import '../constants.dart';

const Color _kBackgroundDark = Color(0xFF0A0F0C);
const Color _kSurfaceDark = Color(0xFF101713);
const Color _kBorderDark = Color(0xFF1C2721);
const Color _kMutedDark = Color(0xFF7C8A83);
const Color _kTextPrimaryDark = Colors.white;

const Color _kBackgroundLight = Color(0xFFF4F7F5);
const Color _kSurfaceLight = Color(0xFFFFFFFF);
const Color _kBorderLight = Color(0xFFDCE3DE);
const Color _kMutedLight = Color(0xFF5B6B62);
const Color _kTextPrimaryLight = Color(0xFF10160F);

// Read synchronously by the token getters below, so they work without a BuildContext.
Brightness _activeBrightness = Brightness.dark;

/// Theme-dependent tokens; brand colors stay identical in both themes — see dev/ai/design-tokens.md.
Color get kBackground => _activeBrightness == Brightness.dark ? _kBackgroundDark : _kBackgroundLight;
Color get kSurface => _activeBrightness == Brightness.dark ? _kSurfaceDark : _kSurfaceLight;
Color get kBorder => _activeBrightness == Brightness.dark ? _kBorderDark : _kBorderLight;
Color get kMuted => _activeBrightness == Brightness.dark ? _kMutedDark : _kMutedLight;

/// Full-emphasis readable text on [kBackground]/[kSurface].
Color get kTextPrimary => _activeBrightness == Brightness.dark ? _kTextPrimaryDark : _kTextPrimaryLight;

/// [kSurface] as a hex string for `constants.dart`; must match `_kSurfaceDark`/`_kSurfaceLight`.
String get kSurfaceHex => _activeBrightness == Brightness.dark ? kSurfaceDarkHex : kSurfaceLightHex;

/// The active brightness itself, for the rare case where a whole asset switches (the splash logo).
bool get kIsDarkTheme => _activeBrightness == Brightness.dark;

// WARNING: keep in sync with kPrimaryHex/kDangerHex in constants.dart, the string form stored on disk.
const Color kPrimary = Color(0xFF00C878);
const Color kDanger = Color(0xFFFF6B6B);
// Amber for non-critical warnings, distinct from kDanger which signals an actual error.
const Color kWarning = Color(0xFFE0A030);

// INFO: on light, the brand colors fail WCAG AA as text (kPrimary ~2.0:1, kDanger ~2.6:1, kWarning ~2.1:1).
Color get kPrimaryText => _activeBrightness == Brightness.dark ? kPrimary : const Color(0xFF00814D);
Color get kDangerText => _activeBrightness == Brightness.dark ? kDanger : const Color(0xFFBA4E4E);
Color get kWarningText => _activeBrightness == Brightness.dark ? kWarning : const Color(0xFF936920);

// Deliberately lighter than kPrimary/kDanger so the dashed projection stays visually secondary.
const Color kTrendUp = Color(0xFF8FE3B3);
const Color kTrendDown = Color(0xFFFFC98A);
const Color kTrendNeutral = Color(0xFFA6B0A9);

/// Excludes [child] from the app-wide [SelectionArea] — see dev/ai/ui-conventions.md.
Widget noSelect(Widget child) => SelectionContainer.disabled(child: child);

/// Stashes the brightness resolved from [mode] before building [child], so the token getters see it.
class ThemeScope extends StatelessWidget {
  const ThemeScope({super.key, required this.mode, required this.child});

  final AppThemeMode mode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final systemBrightness = MediaQuery.platformBrightnessOf(context);
    _activeBrightness = switch (mode) {
      AppThemeMode.system => systemBrightness,
      AppThemeMode.light => Brightness.light,
      AppThemeMode.dark => Brightness.dark,
    };
    return child;
  }
}

/// Resolves [mode] before the first build; without it a light-theme user saw a dark window flash.
void primeThemeBrightness(AppThemeMode mode) {
  _activeBrightness = switch (mode) {
    // Via the binding instance so no extra dart:ui import is needed here.
    AppThemeMode.system => WidgetsBinding.instance.platformDispatcher.platformBrightness,
    AppThemeMode.light => Brightness.light,
    AppThemeMode.dark => Brightness.dark,
  };
}

/// Builds [ThemeData] for the brightness [ThemeScope] resolved last; dark default before any scope.
ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: kPrimary,
    brightness: _activeBrightness,
  ).copyWith(primary: kPrimary, surface: kSurface, error: kDanger);

  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: kBorder),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: _activeBrightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: kBackground,
    canvasColor: kBackground,
    dividerColor: kBorder,
    cardTheme: CardThemeData(
      color: kSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
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
      focusedBorder: border.copyWith(borderSide: BorderSide(color: kPrimaryText, width: 1.5)),
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
        foregroundColor: kTextPrimary,
        side: BorderSide(color: kBorder),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: kPrimaryText)),
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
    dialogTheme: DialogThemeData(backgroundColor: kSurface),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: kSurface,
      contentTextStyle: TextStyle(color: kTextPrimary),
    ),
  );
}
