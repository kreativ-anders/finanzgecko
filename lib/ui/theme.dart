import 'package:flutter/material.dart';

import '../constants.dart';

// ---------- Dark palette (the app's original, default look) ----------
const Color _kBackgroundDark = Color(0xFF0A0F0C);
const Color _kSurfaceDark = Color(0xFF101713);
const Color _kBorderDark = Color(0xFF1C2721);
const Color _kMutedDark = Color(0xFF7C8A83);
const Color _kTextPrimaryDark = Colors.white;

// ---------- Light palette ----------
// Kept close to the dark palette's structure (same border-radius/spacing
// everywhere — nothing here changes layout, only these four tokens), with a
// faint green undertone echoing kPrimary rather than a clinical pure white.
const Color _kBackgroundLight = Color(0xFFF4F7F5);
const Color _kSurfaceLight = Color(0xFFFFFFFF);
const Color _kBorderLight = Color(0xFFDCE3DE);
const Color _kMutedLight = Color(0xFF5B6B62);
const Color _kTextPrimaryLight = Color(0xFF10160F);

/// Currently active brightness, kept in sync by [ThemeScope] on every build
/// (see its class doc) and read synchronously by the token getters below —
/// this is what lets `kMuted`/`kSurface`/etc. keep working as bare
/// identifiers from any build method, without threading BuildContext through
/// every call site across the UI.
Brightness _activeBrightness = Brightness.dark;

/// Background/surface/border/muted-text/primary-text now switch with the
/// active theme; brand colors ([kPrimary]/[kDanger]/[kWarning]/the trend
/// colors) deliberately stay identical in both themes — see AI_MASTER.md §5.
Color get kBackground => _activeBrightness == Brightness.dark ? _kBackgroundDark : _kBackgroundLight;
Color get kSurface => _activeBrightness == Brightness.dark ? _kSurfaceDark : _kSurfaceLight;
Color get kBorder => _activeBrightness == Brightness.dark ? _kBorderDark : _kBorderLight;
Color get kMuted => _activeBrightness == Brightness.dark ? _kMutedDark : _kMutedLight;

/// Full-emphasis readable text on [kBackground]/[kSurface] — for the handful
/// of spots (splash screen, chart tooltips, the month picker) that used to
/// hardcode `Colors.white` because the app was always dark.
Color get kTextPrimary => _activeBrightness == Brightness.dark ? _kTextPrimaryDark : _kTextPrimaryLight;

/// [kSurface] as a hex string, for the pure color helpers in `constants.dart`
/// (`readableOn`) that stay free of Flutter types. Must match
/// `_kSurfaceDark`/`_kSurfaceLight` above.
String get kSurfaceHex => _activeBrightness == Brightness.dark ? kSurfaceDarkHex : kSurfaceLightHex;

// Keep in sync with kPrimaryHex/kDangerHex in constants.dart (those are the
// string form used for on-disk account colors; these are the const Color
// form needed for widget themes/const constructors).
const Color kPrimary = Color(0xFF00C878);
const Color kDanger = Color(0xFFFF6B6B);
// Amber, for non-critical warnings (e.g. an incomplete month in the dashboard
// header) — distinct from kDanger, which signals an actual error/loss.
const Color kWarning = Color(0xFFE0A030);

// ---------- WCAG-AA-safe text/icon variants of the brand colors ----------
// kPrimary/kDanger/kWarning themselves stay pixel-identical between themes
// (see AI_MASTER.md §5) — they're correct as-is for fills (button/chip
// backgrounds, chart lines) where a dark or light glyph sits on top. But used
// directly *as* text/icon color on the light theme's near-white background,
// all three fall short of WCAG 2.1 AA's 4.5:1 minimum (kPrimary ~2.0:1,
// kDanger ~2.6:1, kWarning ~2.1:1) — verified against both kBackground and
// kSurface. These three getters are darkened, same-hue variants used
// wherever the brand color is the color of a glyph rather than a fill; they
// equal the original constant in dark mode (already ≥6.9:1) and only diverge
// in light mode (recomputed against #F4F7F5/#FFFFFF to clear 4.5:1 with
// margin, see the derivation this was checked against).
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
/// [_activeBrightness] before building [child] — every token getter above
/// then reads the correct value for the rest of this build pass (Flutter
/// always builds a parent before its children, so the ordering is safe).
/// Depends on [MediaQuery]'s platform brightness, so it also rebuilds on its
/// own whenever the OS switches light/dark while `themeMode` is "system".
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

/// Builds [ThemeData] for whichever brightness [ThemeScope] most recently
/// resolved. Callers that render before a [ThemeScope] exists yet (the
/// startup-error screen in main.dart) get the dark default, matching the
/// app's original always-dark look.
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
