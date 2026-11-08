/// A savings goal, for example a new phone or an emergency fund.
class Goal {
  final String id;
  final String name;
  final double target;
  final double saved;

  const Goal({
    required this.id,
    required this.name,
    required this.target,
    this.saved = 0,
  });

  /// Share of the target already saved, between 0 and 1.
  double get progress {
    if (target <= 0) {
      return 0;
    }
    final double value = saved / target;
    if (value < 0) {
      return 0;
    }
    if (value > 1) {
      return 1;
    }
    return value;
  }

  Goal copyWith({double? saved}) {
    return Goal(
      id: id,
      name: name,
      target: target,
      saved: saved ?? this.saved,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'target': target,
      'saved': saved,
    };
  }

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Goal',
      target: (json['target'] as num?)?.toDouble() ?? 0,
      saved: (json['saved'] as num?)?.toDouble() ?? 0,
    );
  }
}
