class Asset {
  final int id;
  final String name;
  final double value;
  final DateTime createdAt;
  final DateTime? lastEvaluatedAt;

  const Asset({
    required this.id,
    required this.name,
    required this.value,
    required this.createdAt,
    required this.lastEvaluatedAt,
  });

  Asset copyWith({String? name, double? value, DateTime? lastEvaluatedAt}) {
    return Asset(
      id: id,
      name: name ?? this.name,
      value: value ?? this.value,
      createdAt: createdAt,
      lastEvaluatedAt: lastEvaluatedAt ?? this.lastEvaluatedAt,
    );
  }

  factory Asset.fromJson(Map<String, dynamic> json) => Asset(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    value: (json['value'] as num).toDouble(),
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    lastEvaluatedAt: json['lastEvaluatedAt'] != null
        ? DateTime.tryParse(json['lastEvaluatedAt'] as String)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'value': value,
    'createdAt': createdAt.toIso8601String(),
    'lastEvaluatedAt': lastEvaluatedAt?.toIso8601String(),
  };
}
