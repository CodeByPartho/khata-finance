/// A single income or expense entry in the ledger.
class Txn {
  final String id;
  final double amount;
  final bool isIncome;
  final String category;
  final DateTime date;
  final String note;

  const Txn({
    required this.id,
    required this.amount,
    required this.isIncome,
    required this.category,
    required this.date,
    required this.note,
  });

  Txn copyWith({
    String? id,
    double? amount,
    bool? isIncome,
    String? category,
    DateTime? date,
    String? note,
  }) {
    return Txn(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      isIncome: isIncome ?? this.isIncome,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'amount': amount,
      'isIncome': isIncome,
      'category': category,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory Txn.fromJson(Map<String, dynamic> json) {
    return Txn(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      isIncome: json['isIncome'] as bool,
      category: json['category'] as String,
      date: DateTime.parse(json['date'] as String),
      note: (json['note'] as String?) ?? '',
    );
  }
}
