class Subscription {
  final int id;
  final String name;
  final String interval;
  final double amountOriginal;
  final String currencyOriginal;
  final double rate;
  final double amountBase;
  final DateTime createdAt;

  const Subscription({
    required this.id,
    required this.name,
    required this.interval,
    required this.amountOriginal,
    required this.currencyOriginal,
    required this.rate,
    required this.amountBase,
    required this.createdAt,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    interval: json['interval'] as String? ?? 'monthly',
    amountOriginal: (json['amountOriginal'] as num).toDouble(),
    currencyOriginal: json['currencyOriginal'] as String? ?? 'EUR',
    rate: (json['rate'] as num).toDouble(),
    amountBase: (json['amountBase'] as num).toDouble(),
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'interval': interval,
    'amountOriginal': amountOriginal,
    'currencyOriginal': currencyOriginal,
    'rate': rate,
    'amountBase': amountBase,
    'createdAt': createdAt.toIso8601String(),
  };

  Subscription copyWith({
    String? name,
    String? interval,
    double? amountOriginal,
    String? currencyOriginal,
    double? rate,
    double? amountBase,
  }) => Subscription(
    id: id,
    name: name ?? this.name,
    interval: interval ?? this.interval,
    amountOriginal: amountOriginal ?? this.amountOriginal,
    currencyOriginal: currencyOriginal ?? this.currencyOriginal,
    rate: rate ?? this.rate,
    amountBase: amountBase ?? this.amountBase,
    createdAt: createdAt,
  );
}
