const List<String> kTags = ['Girokonto', 'Tagesgeld', 'Festgeld', 'Depot', 'Kredit', 'Bargeld', 'Krypto'];

/// Hex strings (not Color) — these are stored verbatim in account.color, so
/// keeping them as strings avoids a lossy round-trip through Color objects.
const Map<String, String> kTagColors = {
  'Girokonto': '#00c878',
  'Tagesgeld': '#2fd0a0',
  'Festgeld': '#1fa370',
  'Depot': '#7ee6c0',
  'Kredit': '#ff6b6b',
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

const int kBackupReminderDays = 30;
const int kAssetReevaluationDays = 182; // ~6 Monate

const String kDangerHex = '#ff6b6b';
const String kPrimaryHex = '#00c878';
