/// Card billing cycle math. Pure logic, no Flutter imports.
/// A cycle starts on [billingStartDay] of a month and runs until the
/// day before the next cycle starts. The due date is [dueDay] of the
/// month after the cycle starts.
class CardCycle {
  final int billingStartDay;
  final int dueDay;

  const CardCycle({required this.billingStartDay, required this.dueDay});

  static int _clampDay(int year, int month, int day) {
    final int lastDay = DateTime(year, month + 1, 0).day;
    if (day < 1) {
      return 1;
    }
    if (day > lastDay) {
      return lastDay;
    }
    return day;
  }

  /// Start of the cycle that contains [date].
  DateTime cycleStart(DateTime date) {
    final int startDay = _clampDay(date.year, date.month, billingStartDay);
    if (date.day >= startDay) {
      return DateTime(date.year, date.month, startDay);
    }
    final DateTime prev = DateTime(date.year, date.month - 1, 1);
    return DateTime(
      prev.year,
      prev.month,
      _clampDay(prev.year, prev.month, billingStartDay),
    );
  }

  /// Start of the cycle after the one that contains [date].
  DateTime nextCycleStart(DateTime date) {
    final DateTime start = cycleStart(date);
    final DateTime next = DateTime(start.year, start.month + 1, 1);
    return DateTime(
      next.year,
      next.month,
      _clampDay(next.year, next.month, billingStartDay),
    );
  }

  /// Last day of the cycle that contains [date].
  DateTime cycleEnd(DateTime date) {
    return nextCycleStart(date).subtract(const Duration(days: 1));
  }

  /// Days left in the cycle, counting today. On the last day of the
  /// cycle this is 1.
  int daysLeftInCycle(DateTime date) {
    final DateTime end = cycleEnd(date);
    final DateTime today = DateTime(date.year, date.month, date.day);
    return end.difference(today).inDays + 1;
  }

  /// Due date for the cycle that contains [date]: [dueDay] of the
  /// month after the cycle starts, clamped to that month.
  DateTime dueDate(DateTime date) {
    final DateTime start = cycleStart(date);
    final DateTime dueMonth = DateTime(start.year, start.month + 1, 1);
    return DateTime(
      dueMonth.year,
      dueMonth.month,
      _clampDay(dueMonth.year, dueMonth.month, dueDay),
    );
  }

  /// Days from [date] until the due date. Negative when overdue.
  int daysUntilDue(DateTime date) {
    final DateTime today = DateTime(date.year, date.month, date.day);
    return dueDate(date).difference(today).inDays;
  }
}
