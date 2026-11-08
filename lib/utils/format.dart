import 'package:intl/intl.dart';

final NumberFormat _moneyFormat = NumberFormat('#,##0', 'en_US');
final DateFormat _dateFormat = DateFormat('d MMM yyyy');
final DateFormat _dateShortFormat = DateFormat('d MMM');
final DateFormat _monthYearFormat = DateFormat('MMMM yyyy');
final DateFormat _monthShortFormat = DateFormat('MMM');

/// Formats an amount in taka, for example: ৳ 12,500
/// Negative values are shown as -৳ 1,200.
String fmtMoney(double value) {
  final String digits = _moneyFormat.format(value.abs().round());
  if (value < 0) {
    return '-৳ $digits';
  }
  return '৳ $digits';
}

/// Signed money for transaction rows, for example: + ৳ 5,000 or - ৳ 850.
String fmtMoneySigned(double value, {required bool isIncome}) {
  final String sign = isIncome ? '+' : '-';
  return '$sign ${fmtMoney(value.abs())}';
}

/// Full date, for example: 5 Nov 2026.
String fmtDate(DateTime date) {
  return _dateFormat.format(date);
}

/// Short date, for example: 5 Nov.
String fmtDateShort(DateTime date) {
  return _dateShortFormat.format(date);
}

/// Month and year, for example: November 2026.
String fmtMonthYear(DateTime date) {
  return _monthYearFormat.format(date);
}

/// Short month name, for example: Nov.
String fmtMonthShort(DateTime date) {
  return _monthShortFormat.format(date);
}

/// Header label for a day group: Today, Yesterday, or the full date.
String fmtDayHeader(DateTime date) {
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime day = DateTime(date.year, date.month, date.day);
  if (day == today) {
    return 'Today';
  }
  if (day == today.subtract(const Duration(days: 1))) {
    return 'Yesterday';
  }
  return fmtDate(date);
}
