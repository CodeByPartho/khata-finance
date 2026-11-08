/// Id of the preset Cash account, used as the default account for
/// transactions that were saved before accounts existed.
const String kDefaultAccountId = 'cash';

/// A single income or expense entry in the ledger.
class Txn {
  final String id;
  final double amount;
  final bool isIncome;
  final String category;
  final DateTime date;
  final String note;

  /// Account or wallet this entry belongs to.
  final String accountId;

  /// Optional free-form tag, for example "recurring" or "family".
  final String tag;

  const Txn({
    required this.id,
    required this.amount,
    required this.isIncome,
    required this.category,
    required this.date,
    required this.note,
    this.accountId = kDefaultAccountId,
    this.tag = '',
  });

  Txn copyWith({
    String? id,
    double? amount,
    bool? isIncome,
    String? category,
    DateTime? date,
    String? note,
    String? accountId,
    String? tag,
  }) {
    return Txn(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      isIncome: isIncome ?? this.isIncome,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
      accountId: accountId ?? this.accountId,
      tag: tag ?? this.tag,
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
      'accountId': accountId,
      'tag': tag,
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
      // Data saved by v1.0 has no account or tag: default safely.
      accountId: (json['accountId'] as String?) ?? kDefaultAccountId,
      tag: (json['tag'] as String?) ?? '',
    );
  }
}
