/// How often a recurring transaction repeats.
enum RecurringFrequency { weekly, monthly, yearly }

extension RecurringFrequencyInfo on RecurringFrequency {
  String get label {
    switch (this) {
      case RecurringFrequency.weekly:
        return 'Weekly';
      case RecurringFrequency.monthly:
        return 'Monthly';
      case RecurringFrequency.yearly:
        return 'Yearly';
    }
  }

  /// Cost normalized to one month, used for the subscriptions total.
  double get monthlyFactor {
    switch (this) {
      case RecurringFrequency.weekly:
        return 52 / 12;
      case RecurringFrequency.monthly:
        return 1;
      case RecurringFrequency.yearly:
        return 1 / 12;
    }
  }
}

RecurringFrequency frequencyFromName(String? name) {
  for (final RecurringFrequency f in RecurringFrequency.values) {
    if (f.name == name) {
      return f;
    }
  }
  return RecurringFrequency.monthly;
}

/// A rule that posts a transaction automatically on a schedule,
/// for example rent, a salary or a streaming subscription.
class RecurringRule {
  final String id;
  final double amount;
  final bool isIncome;
  final String category;
  final String accountId;
  final String note;
  final RecurringFrequency frequency;
  final DateTime nextDue;
  final bool active;

  const RecurringRule({
    required this.id,
    required this.amount,
    required this.isIncome,
    required this.category,
    required this.accountId,
    this.note = '',
    required this.frequency,
    required this.nextDue,
    this.active = true,
  });

  RecurringRule copyWith({
    DateTime? nextDue,
    bool? active,
  }) {
    return RecurringRule(
      id: id,
      amount: amount,
      isIncome: isIncome,
      category: category,
      accountId: accountId,
      note: note,
      frequency: frequency,
      nextDue: nextDue ?? this.nextDue,
      active: active ?? this.active,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'amount': amount,
      'isIncome': isIncome,
      'category': category,
      'accountId': accountId,
      'note': note,
      'frequency': frequency.name,
      'nextDue': nextDue.toIso8601String(),
      'active': active,
    };
  }

  factory RecurringRule.fromJson(Map<String, dynamic> json) {
    return RecurringRule(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      isIncome: json['isIncome'] as bool,
      category: json['category'] as String,
      accountId: (json['accountId'] as String?) ?? 'cash',
      note: (json['note'] as String?) ?? '',
      frequency: frequencyFromName(json['frequency'] as String?),
      nextDue: DateTime.parse(json['nextDue'] as String),
      active: (json['active'] as bool?) ?? true,
    );
  }
}

/// Advances [date] by one [frequency] step. Monthly and yearly steps
/// clamp the day to the last day of the target month, so a rule due
/// on 31 January is next due on the last day of February.
DateTime advanceDate(DateTime date, RecurringFrequency frequency) {
  final DateTime day = DateTime(date.year, date.month, date.day);
  switch (frequency) {
    case RecurringFrequency.weekly:
      return day.add(const Duration(days: 7));
    case RecurringFrequency.monthly:
      return addMonthsClamped(day, 1);
    case RecurringFrequency.yearly:
      return addMonthsClamped(day, 12);
  }
}

/// Adds [months] calendar months to [date], clamping the day.
DateTime addMonthsClamped(DateTime date, int months) {
  final int total = (date.year * 12 + (date.month - 1)) + months;
  final int year = total ~/ 12;
  final int month = (total % 12) + 1;
  final int lastDay = DateTime(year, month + 1, 0).day;
  final int day = date.day > lastDay ? lastDay : date.day;
  return DateTime(year, month, day);
}
