class Balance {
  final int id;
  final int accountId;
  final String period; // "YYYY-MM"
  final double amountOriginal;
  final String currencyOriginal;
  final double rate;
  final double amountBase;
  final String note;
  final DateTime enteredAt;

  const Balance({
    required this.id,
    required this.accountId,
    required this.period,
    required this.amountOriginal,
    required this.currencyOriginal,
    required this.rate,
    required this.amountBase,
    required this.note,
    required this.enteredAt,
  });

  Balance copyWith({double? amountOriginal, double? amountBase}) {
    return Balance(
      id: id,
      accountId: accountId,
      period: period,
      amountOriginal: amountOriginal ?? this.amountOriginal,
      currencyOriginal: currencyOriginal,
      rate: rate,
      amountBase: amountBase ?? this.amountBase,
      note: note,
      enteredAt: enteredAt,
    );
  }

  factory Balance.fromJson(Map<String, dynamic> json) => Balance(
    id: json['id'] as int,
    accountId: json['accountId'] as int,
    period: json['period'] as String,
    amountOriginal: (json['amountOriginal'] as num).toDouble(),
    currencyOriginal: json['currencyOriginal'] as String? ?? 'EUR',
    rate: (json['rate'] as num).toDouble(),
    amountBase: (json['amountBase'] as num).toDouble(),
    note: json['note'] as String? ?? '',
    enteredAt: DateTime.tryParse(json['enteredAt'] as String? ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'accountId': accountId,
    'period': period,
    'amountOriginal': amountOriginal,
    'currencyOriginal': currencyOriginal,
    'rate': rate,
    'amountBase': amountBase,
    'note': note,
    'enteredAt': enteredAt.toIso8601String(),
  };
}
