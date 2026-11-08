/// A movement of money between two of the user's own accounts.
/// A transfer is not income and not expense: it never changes the
/// monthly income or expense totals or any budget. An optional fee
/// (for example an MFS cash out fee) is charged to the source account
/// on top of the moved amount.
class Transfer {
  final String id;
  final String fromAccountId;
  final String toAccountId;
  final double amount;
  final double fee;
  final DateTime date;
  final String note;

  const Transfer({
    required this.id,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amount,
    this.fee = 0,
    required this.date,
    this.note = '',
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'fromAccountId': fromAccountId,
      'toAccountId': toAccountId,
      'amount': amount,
      'fee': fee,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory Transfer.fromJson(Map<String, dynamic> json) {
    return Transfer(
      id: json['id'] as String,
      fromAccountId: json['fromAccountId'] as String,
      toAccountId: json['toAccountId'] as String,
      amount: (json['amount'] as num).toDouble(),
      fee: (json['fee'] as num?)?.toDouble() ?? 0,
      date: DateTime.parse(json['date'] as String),
      note: (json['note'] as String?) ?? '',
    );
  }
}
