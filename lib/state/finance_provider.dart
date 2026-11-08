import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/transaction.dart';

/// App state for Khata: transactions and monthly budgets, persisted
/// locally as JSON in shared_preferences.
class FinanceProvider extends ChangeNotifier {
  static const String _txnsKey = 'khata_txns_v1';
  static const String _budgetsKey = 'khata_budgets_v1';
  static const String _seededKey = 'khata_seeded_v1';

  List<Txn> _txns = <Txn>[];
  Map<String, double> _budgets = <String, double>{};
  bool _loaded = false;

  FinanceProvider() {
    load();
  }

  bool get isLoaded => _loaded;

  /// All transactions, newest first.
  List<Txn> get txns {
    final List<Txn> sorted = List<Txn>.from(_txns);
    sorted.sort((Txn a, Txn b) => b.date.compareTo(a.date));
    return List<Txn>.unmodifiable(sorted);
  }

  Map<String, double> get budgets =>
      Map<String, double>.unmodifiable(_budgets);

  double budgetFor(String category) {
    return _budgets[category] ?? 0;
  }

  /// Loads saved data. On the very first run it seeds demo data once;
  /// the seeded flag keeps the demo data from coming back after the
  /// user clears everything.
  Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool seeded = prefs.getBool(_seededKey) ?? false;

    if (!seeded) {
      _txns = _demoTxns();
      _budgets = _defaultBudgets();
      await _saveTxns(prefs);
      await _saveBudgets(prefs);
      await prefs.setBool(_seededKey, true);
    } else {
      _txns = _readTxns(prefs);
      _budgets = _readBudgets(prefs);
    }
    _loaded = true;
    notifyListeners();
  }

  List<Txn> _readTxns(SharedPreferences prefs) {
    final String? raw = prefs.getString(_txnsKey);
    if (raw == null || raw.isEmpty) {
      return <Txn>[];
    }
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((dynamic e) => Txn.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return <Txn>[];
    }
  }

  Map<String, double> _readBudgets(SharedPreferences prefs) {
    final String? raw = prefs.getString(_budgetsKey);
    if (raw == null || raw.isEmpty) {
      return <String, double>{};
    }
    try {
      final Map<String, dynamic> decoded =
          jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (String key, dynamic value) =>
            MapEntry<String, double>(key, (value as num).toDouble()),
      );
    } catch (_) {
      return <String, double>{};
    }
  }

  Future<void> _saveTxns(SharedPreferences prefs) async {
    final List<Map<String, dynamic>> list =
        _txns.map((Txn t) => t.toJson()).toList();
    await prefs.setString(_txnsKey, jsonEncode(list));
  }

  Future<void> _saveBudgets(SharedPreferences prefs) async {
    await prefs.setString(_budgetsKey, jsonEncode(_budgets));
  }

  Future<void> addTxn(Txn txn) async {
    _txns = <Txn>[..._txns, txn];
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _saveTxns(prefs);
    notifyListeners();
  }

  Future<void> deleteTxn(String id) async {
    _txns = _txns.where((Txn t) => t.id != id).toList();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _saveTxns(prefs);
    notifyListeners();
  }

  Future<void> setBudget(String category, double amount) async {
    _budgets = <String, double>{..._budgets, category: amount};
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _saveBudgets(prefs);
    notifyListeners();
  }

  /// Removes all transactions and budgets and saves the empty state.
  /// The seeded flag stays set, so demo data does not return.
  Future<void> clearAllData() async {
    _txns = <Txn>[];
    _budgets = <String, double>{};
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_txnsKey);
    await prefs.remove(_budgetsKey);
    await prefs.setBool(_seededKey, true);
    notifyListeners();
  }

  /// Restores the demo transactions and default budgets.
  Future<void> resetToDemo() async {
    _txns = _demoTxns();
    _budgets = _defaultBudgets();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _saveTxns(prefs);
    await _saveBudgets(prefs);
    await prefs.setBool(_seededKey, true);
    notifyListeners();
  }

  List<Txn> txnsForMonth(DateTime month) {
    return txns.where((Txn t) {
      return t.date.year == month.year && t.date.month == month.month;
    }).toList();
  }

  double incomeForMonth(DateTime month) {
    return txnsForMonth(month)
        .where((Txn t) => t.isIncome)
        .fold(0.0, (double sum, Txn t) => sum + t.amount);
  }

  double expenseForMonth(DateTime month) {
    return txnsForMonth(month)
        .where((Txn t) => !t.isIncome)
        .fold(0.0, (double sum, Txn t) => sum + t.amount);
  }

  /// All-time income minus all-time expense.
  double get balance {
    double total = 0;
    for (final Txn t in _txns) {
      total += t.isIncome ? t.amount : -t.amount;
    }
    return total;
  }

  /// Expense totals per category for one month.
  Map<String, double> expenseByCategory(DateTime month) {
    final Map<String, double> result = <String, double>{};
    for (final Txn t in txnsForMonth(month)) {
      if (t.isIncome) {
        continue;
      }
      result[t.category] = (result[t.category] ?? 0) + t.amount;
    }
    return result;
  }

  /// Expense totals for the last [count] months, oldest first.
  /// Each entry is a record with the month (first day) and the total.
  List<({DateTime month, double total})> monthlyExpenses([int count = 6]) {
    final DateTime now = DateTime.now();
    final List<({DateTime month, double total})> result =
        <({DateTime month, double total})>[];
    for (int i = count - 1; i >= 0; i--) {
      final DateTime month = DateTime(now.year, now.month - i, 1);
      result.add((month: month, total: expenseForMonth(month)));
    }
    return result;
  }

  /// Share of the monthly budget already spent in [category], as a
  /// ratio: 0.5 means half spent, 1.0 means fully spent, values above
  /// 1.0 mean over budget. Returns 0 when no budget is set.
  double budgetProgress(String category, DateTime month) {
    final double budget = budgetFor(category);
    if (budget <= 0) {
      return 0;
    }
    final double spent = expenseByCategory(month)[category] ?? 0;
    return spent / budget;
  }

  Map<String, double> _defaultBudgets() {
    return <String, double>{
      'Food': 10000,
      'Transport': 3000,
      'Bills': 8000,
      'Shopping': 5000,
      'Health': 4000,
      'Education': 5000,
      'Entertainment': 3000,
      'Other': 3000,
    };
  }

  /// A date inside the month that is [monthOffset] months before the
  /// current month, clamped to a valid day of that month.
  DateTime _demoDate(int monthOffset, int day) {
    final DateTime now = DateTime.now();
    final DateTime base = DateTime(now.year, now.month - monthOffset, 1);
    final int lastDay = DateTime(base.year, base.month + 1, 0).day;
    final int clampedDay = day.clamp(1, lastDay);
    DateTime date = DateTime(base.year, base.month, clampedDay);
    if (monthOffset == 0 && date.isAfter(now)) {
      date = DateTime(now.year, now.month, now.day);
    }
    return date;
  }

  List<Txn> _demoTxns() {
    Txn demo(
      int index,
      int monthOffset,
      int day,
      bool isIncome,
      String category,
      double amount,
      String note,
    ) {
      return Txn(
        id: 'demo-$index',
        amount: amount,
        isIncome: isIncome,
        category: category,
        date: _demoDate(monthOffset, day),
        note: note,
      );
    }

    return <Txn>[
      demo(1, 0, 1, true, 'Salary', 45000, 'Monthly salary'),
      demo(2, 0, 6, true, 'Freelance', 8500, 'Freelance project payment'),
      demo(3, 0, 2, false, 'Food', 1250, 'Groceries for home'),
      demo(4, 0, 3, false, 'Transport', 420, 'Rickshaw and bus fares'),
      demo(5, 0, 4, false, 'Bills', 3850, 'Electricity and internet bills'),
      demo(6, 0, 7, false, 'Shopping', 2750, 'New shoes and shirt'),
      demo(7, 0, 8, false, 'Food', 860, 'Restaurant dinner'),
      demo(8, 0, 9, false, 'Health', 1500, 'Medicine and checkup'),
      demo(9, 1, 1, true, 'Salary', 45000, 'Monthly salary'),
      demo(10, 1, 5, false, 'Bills', 3600, 'Electricity and mobile bills'),
      demo(11, 1, 10, false, 'Food', 1980, 'Weekly groceries'),
      demo(12, 1, 12, false, 'Education', 2200, 'Course and books'),
      demo(13, 1, 15, false, 'Entertainment', 950, 'Movie and streaming'),
      demo(14, 1, 18, false, 'Transport', 780, 'Travel within Dhaka'),
    ];
  }
}
