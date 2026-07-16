class Account {
  final int id;
  final String name;
  final String bank;
  final String tag;
  final String currency;
  final String color;
  final bool archived;
  final DateTime createdAt;

  const Account({
    required this.id,
    required this.name,
    required this.bank,
    required this.tag,
    required this.currency,
    required this.color,
    required this.archived,
    required this.createdAt,
  });

  Account copyWith({String? name, String? bank, String? tag, String? currency, String? color, bool? archived}) {
    return Account(
      id: id,
      name: name ?? this.name,
      bank: bank ?? this.bank,
      tag: tag ?? this.tag,
      currency: currency ?? this.currency,
      color: color ?? this.color,
      archived: archived ?? this.archived,
      createdAt: createdAt,
    );
  }

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    bank: json['bank'] as String? ?? '',
    tag: json['tag'] as String? ?? '',
    currency: json['currency'] as String? ?? 'EUR',
    color: json['color'] as String? ?? '#00c878',
    archived: json['archived'] as bool? ?? false,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );

  /// Full serialization for the encrypted on-disk store (keeps [color] so the
  /// UI has the resolved accent without recomputing on every load).
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'bank': bank,
    'tag': tag,
    'currency': currency,
    'color': color,
    'archived': archived,
    'createdAt': createdAt.toIso8601String(),
  };

  /// Serialization for "Backup exportieren": deliberately **omits [color]**.
  /// The color is a derived value (from the bank, see `resolveAccountColor`)
  /// and is recomputed on import — leaving it out keeps backups smaller and
  /// prevents a stale/arbitrary color from riding along into an import.
  Map<String, dynamic> toExportJson() => {
    'id': id,
    'name': name,
    'bank': bank,
    'tag': tag,
    'currency': currency,
    'archived': archived,
    'createdAt': createdAt.toIso8601String(),
  };
}
