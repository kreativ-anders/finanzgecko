import 'package:flutter/material.dart';

import '../constants.dart';

// ---------- Dark palette (the app's original, default look) ----------
const Color _kBackgroundDark = Color(0xFF0A0F0C);
const Color _kSurfaceDark = Color(0xFF101713);
const Color _kBorderDark = Color(0xFF1C2721);
const Color _kMutedDark = Color(0xFF7C8A83);
const Color _kTextPrimaryDark = Colors.white;

// ---------- Light palette ----------
// Same structure as the dark palette — only these four tokens differ, nothing
// here changes layout — with a faint green undertone echoing kPrimary rather
// than a clinical pure white.
const Color _kBackgroundLight = Color(0xFFF4F7F5);
const Color _kSurfaceLight = Color(0xFFFFFFFF);
const Color _kBorderLight = Color(0xFFDCE3DE);
const Color _kMutedLight = Color(0xFF5B6B62);
const Color _kTextPrimaryLight = Color(0xFF10160F);

/// Currently active brightness, kept in sync by [ThemeScope] on every build
/// and read synchronously by the token getters below — this is what lets
/// `kMuted`/`kSurface`/etc. work as bare identifiers from any build method,
/// without threading BuildContext through every call site.
Brightness _activeBrightness = Brightness.dark;

/// Background/surface/border/text switch with the active theme; brand colors
/// deliberately stay identical in both — see dev/ai/design-tokens.md.
Color get kBackground => _activeBrightness == Brightness.dark ? _kBackgroundDark : _kBackgroundLight;
Color get kSurface => _activeBrightness == Brightness.dark ? _kSurfaceDark : _kSurfaceLight;
Color get kBorder => _activeBrightness == Brightness.dark ? _kBorderDark : _kBorderLight;
Color get kMuted => _activeBrightness == Brightness.dark ? _kMutedDark : _kMutedLight;

/// Full-emphasis readable text on [kBackground]/[kSurface] — for the spots
/// (splash screen, chart tooltips, month picker) that used to hardcode
/// `Colors.white` because the app was always dark.
Color get kTextPrimary => _activeBrightness == Brightness.dark ? _kTextPrimaryDark : _kTextPrimaryLight;

/// [kSurface] as a hex string, for the Flutter-free helpers in
/// `constants.dart`. Must match `_kSurfaceDark`/`_kSurfaceLight` above.
String get kSurfaceHex => _activeBrightness == Brightness.dark ? kSurfaceDarkHex : kSurfaceLightHex;

/// The active brightness itself — for the rare case where a whole *asset*
/// switches (the splash logo). Prefer the token getters where a color is
/// enough.
bool get kIsDarkTheme => _activeBrightness == Brightness.dark;

// Keep in sync with kPrimaryHex/kDangerHex in constants.dart — those are the
// string form stored on disk, these the const Color form widget themes need.
const Color kPrimary = Color(0xFF00C878);
const Color kDanger = Color(0xFFFF6B6B);
// Amber, for non-critical warnings (e.g. an incomplete month in the dashboard
// header) — distinct from kDanger, which signals an actual error/loss.
const Color kWarning = Color(0xFFE0A030);

// ---------- WCAG-AA-safe text/icon variants of the brand colors ----------
// kPrimary/kDanger/kWarning stay pixel-identical between themes (see
// dev/ai/design-tokens.md) and are correct as fills. Used directly *as* text/icon
// color on the light theme's near-white background, all three fall short of
// WCAG 2.1 AA's 4.5:1 (kPrimary ~2.0:1, kDanger ~2.6:1, kWarning ~2.1:1),
// verified against kBackground and kSurface. These getters are darkened,
// same-hue variants for glyphs; identical to the constants in dark mode
// (already ≥6.9:1), diverging only in light mode.
Color get kPrimaryText => _activeBrightness == Brightness.dark ? kPrimary : const Color(0xFF00814D);
Color get kDangerText => _activeBrightness == Brightness.dark ? kDanger : const Color(0xFFBA4E4E);
Color get kWarningText => _activeBrightness == Brightness.dark ? kWarning : const Color(0xFF936920);

// Trend-line direction colors (see AppLineChart) — deliberately lighter/more
// muted than kPrimary/kDanger so the dashed projection stays visually
// secondary to the actual data line.
const Color kTrendUp = Color(0xFF8FE3B3);
const Color kTrendDown = Color(0xFFFFC98A);
const Color kTrendNeutral = Color(0xFFA6B0A9);

/// Excludes [child] from the app-wide [SelectionArea] (see main.dart) —
/// for button labels and nav chrome, which aren't meant to be copyable.
Widget noSelect(Widget child) => SelectionContainer.disabled(child: child);

/// Resolves [AppThemeMode] against the OS setting and stashes the result in
/// [_activeBrightness] before building [child], so every token getter above
/// reads the correct value for the rest of this build pass (a parent always
/// builds before its children). Depends on [MediaQuery]'s platform
/// brightness, so it rebuilds on its own when the OS switches light/dark
/// while `themeMode` is "system".
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

/// Resolves [mode] against the OS setting **before** the first widget build,
/// for `main()`: the native window is created and shown before `runApp`, so
/// its `backgroundColor` is picked while [_activeBrightness] still holds its
/// dark default. Without this, a user on the light theme saw a dark window
/// flash before the splash faded in.
void primeThemeBrightness(AppThemeMode mode) {
  _activeBrightness = switch (mode) {
    // Via the binding instance rather than PlatformDispatcher.instance so no
    // extra dart:ui import is needed here; main() has already initialised the
    // binding by this point.
    AppThemeMode.system => WidgetsBinding.instance.platformDispatcher.platformBrightness,
    AppThemeMode.light => Brightness.light,
    AppThemeMode.dark => Brightness.dark,
  };
}

/// Builds [ThemeData] for whichever brightness [ThemeScope] most recently
/// resolved. Callers rendering before any [ThemeScope] exists (the
/// startup-error screen) get the dark default.
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
