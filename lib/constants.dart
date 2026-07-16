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
class Bank {
  final String name;
  final String colorHex;

  const Bank(this.name, this.colorHex);
}

const List<Bank> kBanks = [
  Bank('Sparkasse', '#ff0000'),
  Bank('Volksbank Raiffeisenbank', '#0069b4'),
  Bank('Deutsche Bank', '#0018a8'),
  Bank('Commerzbank', '#ffcc00'),
  Bank('ING', '#ff6200'),
  Bank('DKB', '#003d7d'),
  Bank('N26', '#48ac98'),
  Bank('comdirect', '#ffe600'),
  Bank('Consorsbank', '#004a94'),
  Bank('Postbank', '#ffdd00'),
  Bank('HypoVereinsbank', '#e2001a'),
  Bank('Targobank', '#e2001a'),
  Bank('Santander', '#ec0000'),
  Bank('C24 Bank', '#000000'),
  Bank('PayPal', '#003087'),
  Bank('Wise', '#9fe870'),
  Bank('Trade Republic', '#000000'),
  Bank('Revolut', '#0075eb'),
  Bank('Scalable Capital', '#00d3a5'),
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

const int kBackupReminderDays = 30;
const int kAssetReevaluationDays = 182; // ~6 Monate

/// Share (of positive Kontotyp totals) above which the dashboard flags a
/// concentration risk in "Verteilung nach Kontotyp".
const double kConcentrationRiskThreshold = 0.65;

const String kDangerHex = '#ff6b6b';
const String kPrimaryHex = '#00c878';
