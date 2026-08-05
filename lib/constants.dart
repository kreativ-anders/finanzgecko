import 'dart:math' as math;

import 'package:flutter/services.dart' show LogicalKeyboardKey;

const List<String> kTags = ['Girokonto', 'Tagesgeld', 'Depot', 'Bargeld', 'Krypto'];

/// Hex strings (not Color) — these are stored verbatim in account.color, so
/// keeping them as strings avoids a lossy round-trip through Color objects.
const Map<String, String> kTagColors = {
  'Girokonto': '#00c878',
  'Tagesgeld': '#2fd0a0',
  'Depot': '#7ee6c0',
  'Bargeld': '#c9d6cf',
  'Krypto': '#f5a623',
};

String tagColorHex(String tag) => kTagColors[tag] ?? '#888888';

const List<String> kCurrencies = ['EUR', 'USD', 'CHF', 'GBP', 'JPY', 'SEK', 'NOK', 'DKK'];

const List<String> kMonthLabels = ['Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];

/// A global keyboard shortcut: the [key] it's bound to in
/// `ui/navigation_shell.dart` (combined there with Strg/⌘) and the single
/// letter shown as a hint next to the corresponding button in
/// `ui/views/settings_view.dart` — paired here so a rebind can't silently
/// desync the displayed hint.
class AppShortcut {
  const AppShortcut(this.key, this.letter);

  final LogicalKeyboardKey key;
  final String letter;
}

class AppShortcuts {
  const AppShortcuts._();

  static const export = AppShortcut(LogicalKeyboardKey.keyE, 'E');
  static const import_ = AppShortcut(LogicalKeyboardKey.keyI, 'I');
  static const quit = AppShortcut(LogicalKeyboardKey.keyQ, 'Q');
}

/// Fixposten: wiederkehrende Ein-/Ausgaben. monthFactor rechnet den jeweiligen
/// Turnus auf ein Monatsäquivalent um, damit z.B. ein jährlicher und ein
/// monatlicher Betrag vergleichbar sind.
class SubscriptionInterval {
  final String value;
  final String label;
  final double monthFactor;

  const SubscriptionInterval({required this.value, required this.label, required this.monthFactor});
}

const List<SubscriptionInterval> kSubscriptionIntervals = [
  SubscriptionInterval(value: 'daily', label: 'Täglich', monthFactor: 30.4368),
  SubscriptionInterval(value: 'weekly', label: 'Wöchentlich', monthFactor: 4.34524),
  SubscriptionInterval(value: 'monthly', label: 'Monatlich', monthFactor: 1),
  SubscriptionInterval(value: 'quarterly', label: 'Vierteljährlich', monthFactor: 1 / 3),
  SubscriptionInterval(value: 'yearly', label: 'Jährlich', monthFactor: 1 / 12),
];

String intervalLabel(String value) {
  for (final i in kSubscriptionIntervals) {
    if (i.value == value) return i.label;
  }
  return value;
}

double intervalMonthFactor(String value) {
  for (final i in kSubscriptionIntervals) {
    if (i.value == value) return i.monthFactor;
  }
  return 1;
}

/// Bekannte Banken & Markenfarben, für Autovervollständigung + Konto-Akzentfarbe.
///
/// Von Hand gepflegte, bewusst unvollständige Liste — deutsche Filial-, Genossenschafts- und Autobanken, gängige
/// Direktbanken/Neobanken und Broker, plus PayPal/Wise/Revolut als gebräuchliche internationale Zahlungsdienste.
/// `colorHex` ist jeweils die offizielle Markenfarbe der Bank, von Hand recherchiert (nicht algorithmisch
/// abgeleitet). Neue Einträge kommen über die im Konto-Formular verlinkten Kanäle (GitHub-Issue/E-Mail) — siehe
/// AI_MASTER.md §4.1 und `gherkin/accounts.feature`.
class Bank {
  final String name;
  final String colorHex;

  const Bank(this.name, this.colorHex);
}

const List<Bank> kBanks = [
  // Filialbanken (Großbanken, Sparkassen/Genossenschaftsbanken)
  Bank('Sparkasse', '#ff0000'),
  Bank('Volksbank Raiffeisenbank', '#0069b4'),
  Bank('Deutsche Bank', '#0018a8'),
  Bank('Commerzbank', '#ffcc00'),
  Bank('HypoVereinsbank', '#e2001a'),
  Bank('Targobank', '#e2001a'),
  Bank('Santander', '#ec0000'),
  Bank('Postbank', '#ffdd00'),
  Bank('Sparda-Bank', '#0066b4'),
  Bank('Apobank', '#17427f'),
  Bank('BBBank', '#005ca9'),
  Bank('norisbank', '#f08701'),
  Bank('OLB', '#007858'),

  // Direktbanken & Neobanken
  Bank('ING', '#ff6200'),
  Bank('DKB', '#003d7d'),
  Bank('N26', '#48ac98'),
  Bank('comdirect', '#ffe600'),
  Bank('Consorsbank', '#004a94'),
  Bank('C24 Bank', '#000000'),
  Bank('bunq', '#ff7819'),
  Bank('Vivid Money', '#7d33f6'),
  Bank('Openbank', '#e9004c'),
  Bank('Solarisbank', '#ff633c'),
  Bank('Klarna', '#ffa8cd'),
  Bank('OSKAR', '#29b68c'),
  Bank('Qonto', '#6b5aed'),

  // Autobanken
  Bank('Volkswagen Bank', '#007392'),
  Bank('Mercedes-Benz Bank', '#000000'),
  Bank('BMW Bank', '#0066b1'),
  Bank('Audi Bank', '#f50537'),
  Bank('Ford Bank', '#003478'),
  Bank('Renault Bank', '#efdf00'),

  // Broker & Krypto
  Bank('Trade Republic', '#000000'),
  Bank('Scalable Capital', '#00d3a5'),
  Bank('Smartbroker', '#80ff04'),
  Bank('eToro', '#13c636'),
  Bank('Bitpanda', '#103e36'),

  // Kreditkarten-/Nischenbanken
  Bank('Advanzia Bank (Gebührenfrei)', '#00174a'),
  Bank('Hanseatic Bank', '#e6323c'),
  Bank('Barclays', '#00aeef'),

  // Internationale Zahlungsdienste
  Bank('PayPal', '#003087'),
  Bank('Wise', '#9fe870'),
  Bank('Revolut', '#0075eb'),
];

String? bankColorHex(String? bankName) {
  final needle = (bankName ?? '').trim().toLowerCase();
  if (needle.isEmpty) return null;
  for (final b in kBanks) {
    if (b.name.toLowerCase() == needle) return b.colorHex;
  }
  return null;
}

/// True if [bankName] matches an entry in [kBanks] (case-insensitive).
/// Accounts must reference a known bank so the dashboard can rely on a
/// resolved brand color/name instead of arbitrary free text.
bool isKnownBank(String? bankName) => bankColorHex(bankName) != null;

/// Surfaces a brand color is rendered against — the card background per theme
/// (`_kSurfaceDark`/`_kSurfaceLight` in `ui/theme.dart`, mirrored here so this
/// file stays free of Flutter imports and unit-testable on its own).
const String kSurfaceDarkHex = '#101713';
const String kSurfaceLightHex = '#ffffff';

/// WCAG AA for normal-size text. The Kontotyp chip renders at 11px bold, so
/// the 3:1 large-text exception does not apply.
const double _kMinTextContrast = 4.5;

/// Relative luminance per WCAG 2.1, from a `#rrggbb` string.
double relativeLuminance(String hex) {
  final rgb = _rgb(hex);
  double channel(int v) {
    final c = v / 255;
    return c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(rgb[0]) + 0.7152 * channel(rgb[1]) + 0.0722 * channel(rgb[2]);
}

/// WCAG contrast ratio between two `#rrggbb` colors — 1.0 (identical) to 21.0
/// (black on white).
double contrastRatio(String aHex, String bHex) {
  final la = relativeLuminance(aHex);
  final lb = relativeLuminance(bHex);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// A brand color made legible as *text* on [backgroundHex].
///
/// Bank brand colors in [kBanks] are picked for logos, not for type on our
/// surfaces: `#000000` (Trade Republic, C24, Mercedes-Benz Bank) disappears on
/// the dark card, `#ffe600` (comdirect) on the light one. This mixes the color
/// toward white or black — whichever direction the background allows — in 2%
/// steps until it clears [_kMinTextContrast], and returns it unchanged when it
/// already does. Mixing (rather than an HSL lightness bump) keeps the result
/// predictable for the achromatic extremes, at the cost of some saturation.
///
/// Pure and hex-in/hex-out on purpose, so it is unit-testable without a Flutter
/// binding — see `gherkin/executable/account_color.feature`.
String readableOn(String colorHex, String backgroundHex) {
  if (contrastRatio(colorHex, backgroundHex) >= _kMinTextContrast) return _normalizeHex(colorHex);

  // Lighten on dark backgrounds, darken on light ones. Picking the direction
  // from the background (not from the color) avoids pushing a mid-grey the
  // wrong way, where it would never reach the target.
  final towardWhite = relativeLuminance(backgroundHex) < 0.5;
  final target = towardWhite ? [255, 255, 255] : [0, 0, 0];
  final rgb = _rgb(colorHex);

  for (var step = 1; step <= 50; step++) {
    final t = step * 0.02;
    final mixed = _hex([
      (rgb[0] + (target[0] - rgb[0]) * t).round(),
      (rgb[1] + (target[1] - rgb[1]) * t).round(),
      (rgb[2] + (target[2] - rgb[2]) * t).round(),
    ]);
    if (contrastRatio(mixed, backgroundHex) >= _kMinTextContrast) return mixed;
  }
  // Unreachable for our surfaces (pure white/black always clears 4.5:1 against
  // both), but returning the extreme beats returning something illegible.
  return _hex(target);
}

List<int> _rgb(String hex) {
  final h = hex.replaceFirst('#', '');
  final v = int.parse(h.length == 3 ? h.split('').map((c) => '$c$c').join() : h, radix: 16);
  return [(v >> 16) & 0xff, (v >> 8) & 0xff, v & 0xff];
}

String _hex(List<int> rgb) =>
    '#${rgb.map((c) => c.clamp(0, 255).toRadixString(16).padLeft(2, '0')).join()}';

String _normalizeHex(String hex) => _hex(_rgb(hex));

/// The stored accent color for an account, derived from its [bank]:
/// - a **known** bank → that bank's brand color (single source of truth),
/// - an **empty** bank (e.g. Bargeld/Krypto without an institution) → the
///   Kontotyp color as a fallback,
/// - an **unknown, non-empty** bank → throws [FormatException].
///
/// This is the invariant the account form already enforces
/// (`bankColorHex(bank) ?? tagColorHex(tag)` + known-bank validator); it lives
/// here as a pure function so import/backup can enforce the same rule instead
/// of trusting an arbitrary `color` from the file.
String resolveAccountColor({required String bank, required String tag}) {
  final trimmed = bank.trim();
  if (trimmed.isEmpty) return tagColorHex(tag);
  final color = bankColorHex(trimmed);
  if (color == null) {
    throw FormatException('Unbekannte Bank "$trimmed" — bitte eine Bank aus der Liste verwenden.');
  }
  return color;
}

/// Erster Backup-Hinweis, gemessen ab der frühesten erfassten Aktivität
/// (nicht ab App-Installation) — solange die App leer ist (keine Konten,
/// Kontostände, Vermögenswerte, Fixposten), gibt es schlicht nichts zu
/// sichern, siehe [AppState.getBackupReminder].
const int kBackupReminderFirstDays = 182; // ~6 Monate
/// Wiederholter Backup-Hinweis nach dem ersten Export, gemessen ab dem
/// letzten Export.
const int kBackupReminderRepeatDays = 90; // ~3 Monate
const int kAssetReevaluationDays = 182; // ~6 Monate

/// Debounce before an inline-edited field (Vermögenswerte, Fixposten) is
/// auto-saved — see AI_MASTER.md §5 "Inline-Edit mit Debounce".
const Duration kInlineEditDebounce = Duration(milliseconds: 600);

/// Share (of positive Kontotyp totals) above which the dashboard flags a
/// concentration risk in "Verteilung nach Kontotyp".
const double kConcentrationRiskThreshold = 0.65;

const String kDangerHex = '#ff6b6b';
const String kPrimaryHex = '#00c878';

/// Erscheinungsbild-Einstellung (Einstellungen → Erscheinungsbild). `system`
/// folgt der Betriebssystem-Einstellung und ist der Standard. Die eigentliche
/// Farbauflösung (welche Palette für welchen Modus) lebt in `ui/theme.dart`;
/// hier nur die Domänen-Repräsentation, damit `AppSchema`/`AppStore` sie ohne
/// eine Abhängigkeit auf die UI-Schicht persistieren können.
enum AppThemeMode { system, light, dark }

String appThemeModeToJson(AppThemeMode mode) => mode.name;

AppThemeMode appThemeModeFromJson(String? value) =>
    AppThemeMode.values.firstWhere((m) => m.name == value, orElse: () => AppThemeMode.system);
