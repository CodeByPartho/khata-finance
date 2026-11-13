/// One dena paona (debt) entry: money lent to or borrowed from a
/// person. When [iLent] is true, the person owes the user. When it
/// is false, the user owes the person. [settled] is the part of
/// [amount] that has been paid back so far.
class DebtEntry {
  final String id;
  final String person;
  final double amount;
  final bool iLent;
  final DateTime date;
  final String note;
  final double settled;

  /// Optional annual interest rate in percent for money owed.
  /// 0 means interest free. Used by the debt payoff planner.
  final double annualRatePercent;

  /// Optional minimum monthly payment in taka. 0 means no fixed
  /// minimum; the planner then assumes 5 percent of the balance.
  final double minPayment;

  const DebtEntry({
    required this.id,
    required this.person,
    required this.amount,
    required this.iLent,
    required this.date,
    this.note = '',
    this.settled = 0,
    this.annualRatePercent = 0,
    this.minPayment = 0,
  });

  /// Amount still outstanding on this entry.
  double get remaining {
    final double value = amount - settled;
    return value < 0 ? 0 : value;
  }

  bool get isSettled => remaining <= 0;

  DebtEntry copyWith({
    double? settled,
    double? annualRatePercent,
    double? minPayment,
  }) {
    return DebtEntry(
      id: id,
      person: person,
      amount: amount,
      iLent: iLent,
      date: date,
      note: note,
      settled: settled ?? this.settled,
      annualRatePercent: annualRatePercent ?? this.annualRatePercent,
      minPayment: minPayment ?? this.minPayment,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'person': person,
      'amount': amount,
      'iLent': iLent,
      'date': date.toIso8601String(),
      'note': note,
      'settled': settled,
      'annualRatePercent': annualRatePercent,
      'minPayment': minPayment,
    };
  }

  factory DebtEntry.fromJson(Map<String, dynamic> json) {
    return DebtEntry(
      id: json['id'] as String,
      person: (json['person'] as String?) ?? '',
      amount: (json['amount'] as num).toDouble(),
      iLent: (json['iLent'] as bool?) ?? true,
      date: DateTime.parse(json['date'] as String),
      note: (json['note'] as String?) ?? '',
      settled: (json['settled'] as num?)?.toDouble() ?? 0,
      annualRatePercent:
          (json['annualRatePercent'] as num?)?.toDouble() ?? 0,
      minPayment: (json['minPayment'] as num?)?.toDouble() ?? 0,
    );
  }
}
