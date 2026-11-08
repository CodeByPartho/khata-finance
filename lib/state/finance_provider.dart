import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/account.dart';
import '../models/debt_entry.dart';
import '../models/goal.dart';
import '../models/recurring_rule.dart';
import '../models/transaction.dart';
import '../models/transfer.dart';
import '../utils/format.dart';

/// App state for Khata: transactions, budgets, accounts, transfers,
/// recurring rules, savings goals and debts, persisted locally as
/// JSON in shared_preferences.
class FinanceProvider extends ChangeNotifier {
  static const String _txnsKey = 'khata_txns_v1';
  static const String _budgetsKey = 'khata_budgets_v1';
  static const String _seededKey = 'khata_seeded_v1';
  static const String _accountsKey = 'khata_accounts_v1';
  static const String _transfersKey = 'khata_transfers_v1';
  static const String _rulesKey = 'khata_rules_v1';
  static const String _goalsKey = 'khata_goals_v1';
  static const String _debtsKey = 'khata_debts_v1';
  static const String _hideAmountsKey = 'khata_hide_amounts_v1';
  static const String _pinHashKey = 'khata_pin_hash_v1';

  List<Txn> _txns = <Txn>[];
  Map<String, double> _budgets = <String, double>{};
  List<Account> _accounts = <Account>[];
  List<Transfer> _transfers = <Transfer>[];
  List<RecurringRule> _rules = <RecurringRule>[];
  List<Goal> _goals = <Goal>[];
  List<DebtEntry> _debts = <DebtEntry>[];
  bool _hideAmounts = false;
  String? _pinHash;
  bool _loaded = false;

  FinanceProvider() {
    load();
  }

  bool get isLoaded => _loaded;

  static DateTime _today() {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  // ---------------------------------------------------------------
  // Transactions
  // ---------------------------------------------------------------

  /// All transactions, newest first.
  List<Txn> get txns {
    final List<Txn> sorted = List<Txn>.from(_txns);
    sorted.sort((Txn a, Txn b) => b.date.compareTo(a.date));
    return List<Txn>.unmodifiable(sorted);
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

  /// All-time income minus all-time expense, across every account.
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

  /// Income and expense totals for the last [count] months,
  /// oldest first.
  List<({DateTime month, double income, double expense})>
      monthlyIncomeVsExpense([int count = 6]) {
    final DateTime now = DateTime.now();
    final List<({DateTime month, double income, double expense})> result =
        <({DateTime month, double income, double expense})>[];
    for (int i = count - 1; i >= 0; i--) {
      final DateTime month = DateTime(now.year, now.month - i, 1);
      result.add((
        month: month,
        income: incomeForMonth(month),
        expense: expenseForMonth(month),
      ));
    }
    return result;
  }

  // ---------------------------------------------------------------
  // Budgets
  // ---------------------------------------------------------------

  Map<String, double> get budgets => Map<String, double>.unmodifiable(_budgets);

  double budgetFor(String category) {
    return _budgets[category] ?? 0;
  }

  Future<void> setBudget(String category, double amount) async {
    _budgets = <String, double>{..._budgets, category: amount};
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _saveBudgets(prefs);
    notifyListeners();
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

  double get _totalBudgets {
    return _budgets.values.fold(0.0, (double sum, double v) => sum + v);
  }

  bool get hasBudgets => _totalBudgets > 0;

  /// Spending pace for the current month: actual expenses divided by
  /// the share of the total budget that should be used by today.
  /// Below 1.0 is on track, above 1.0 is spending fast. Null when no
  /// budgets are set.
  double? budgetPace() {
    final double total = _totalBudgets;
    if (total <= 0) {
      return null;
    }
    final DateTime now = DateTime.now();
    final int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final double expected = total * (now.day / daysInMonth);
    if (expected <= 0) {
      return null;
    }
    return expenseForMonth(now) / expected;
  }

  /// Money that can still be spent this month without breaking the
  /// plan: total budgets (or this month's income when no budgets are
  /// set), minus expenses so far, minus recurring expenses still due
  /// before the month ends.
  double safeToSpend() {
    final DateTime now = DateTime.now();
    final DateTime lastDay = DateTime(now.year, now.month + 1, 0);
    final double upcoming = _upcomingExpenseBetween(_today(), lastDay);
    final double spent = expenseForMonth(now);
    if (hasBudgets) {
      return _totalBudgets - spent - upcoming;
    }
    return incomeForMonth(now) - spent - upcoming;
  }

  // ---------------------------------------------------------------
  // Accounts and transfers
  // ---------------------------------------------------------------

  List<Account> get accounts => List<Account>.unmodifiable(_accounts);

  Account? accountById(String id) {
    for (final Account account in _accounts) {
      if (account.id == id) {
        return account;
      }
    }
    return null;
  }

  String accountName(String id) {
    return accountById(id)?.name ?? id;
  }

  Future<void> addAccount(Account account) async {
    _accounts = <Account>[..._accounts, account];
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _saveAccounts(prefs);
    notifyListeners();
  }

  /// Balance of one account: opening balance plus its income minus
  /// its expenses, plus transfers in, minus transfers out and minus
  /// transfer fees charged to it.
  double accountBalance(String accountId) {
    double total = accountById(accountId)?.openingBalance ?? 0;
    for (final Txn t in _txns) {
      if (t.accountId == accountId) {
        total += t.isIncome ? t.amount : -t.amount;
      }
    }
    for (final Transfer transfer in _transfers) {
      if (transfer.toAccountId == accountId) {
        total += transfer.amount;
      }
      if (transfer.fromAccountId == accountId) {
        total -= transfer.amount + transfer.fee;
      }
    }
    return total;
  }

  /// Sum of every account balance.
  double get totalBalance {
    double total = 0;
    for (final Account account in _accounts) {
      total += accountBalance(account.id);
    }
    return total;
  }

  /// All transfers, newest first.
  List<Transfer> get transfers {
    final List<Transfer> sorted = List<Transfer>.from(_transfers);
    sorted.sort((Transfer a, Transfer b) => b.date.compareTo(a.date));
    return List<Transfer>.unmodifiable(sorted);
  }

  Future<void> addTransfer(Transfer transfer) async {
    _transfers = <Transfer>[..._transfers, transfer];
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _saveTransfers(prefs);
    notifyListeners();
  }

  Future<void> deleteTransfer(String id) async {
    _transfers = _transfers.where((Transfer t) => t.id != id).toList();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _saveTransfers(prefs);
    notifyListeners();
  }

  // ---------------------------------------------------------------
  // Recurring rules and bills
  // ---------------------------------------------------------------

  List<RecurringRule> get rules => List<RecurringRule>.unmodifiable(_rules);

  Future<void> addRule(RecurringRule rule) async {
    _rules = <RecurringRule>[..._rules, rule];
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _saveRules(prefs);
    notifyListeners();
  }

  Future<void> deleteRule(String id) async {
    _rules = _rules.where((RecurringRule r) => r.id != id).toList();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _saveRules(prefs);
    notifyListeners();
  }

  Future<void> setRuleActive(String id, bool active) async {
    _rules = _rules.map((RecurringRule r) {
      return r.id == id ? r.copyWith(active: active) : r;
    }).toList();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _saveRules(prefs);
    notifyListeners();
  }

  /// Posts a transaction for every due occurrence of every active
  /// rule, advancing each rule's next due date past today. Called on
  /// load and safe to call again: already posted occurrences are
  /// never posted twice. Returns how many transactions were posted.
  Future<int> processDueRecurring() async {
    final DateTime today = _today();
    int posted = 0;
    bool changed = false;
    final List<RecurringRule> updated = <RecurringRule>[];
    for (final RecurringRule rule in _rules) {
      RecurringRule current = rule;
      if (rule.active) {
        DateTime due = _dateOnly(rule.nextDue);
        while (!due.isAfter(today)) {
          _txns = <Txn>[
            ..._txns,
            Txn(
              id: 'rec-${rule.id}-${due.toIso8601String()}',
              amount: rule.amount,
              isIncome: rule.isIncome,
              category: rule.category,
              date: due,
              note: rule.note.isNotEmpty ? rule.note : rule.category,
              accountId: rule.accountId,
              tag: 'recurring',
            ),
          ];
          posted++;
          changed = true;
          due = advanceDate(due, rule.frequency);
        }
        if (due != _dateOnly(rule.nextDue)) {
          current = rule.copyWith(nextDue: due);
          changed = true;
        }
      }
      updated.add(current);
    }
    if (changed) {
      _rules = updated;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await _saveTxns(prefs);
      await _saveRules(prefs);
      notifyListeners();
    }
    return posted;
  }

  /// Occurrences of active rules due within the next [days] days,
  /// starting today, sorted by date. Nothing is posted.
  List<({RecurringRule rule, DateTime date})> upcomingBills(int days) {
    final DateTime today = _today();
    final DateTime end = today.add(Duration(days: days));
    final List<({RecurringRule rule, DateTime date})> result =
        <({RecurringRule rule, DateTime date})>[];
    for (final RecurringRule rule in _rules) {
      if (!rule.active) {
        continue;
      }
      DateTime due = _dateOnly(rule.nextDue);
      int guard = 0;
      while (!due.isAfter(end) && guard < 600) {
        guard++;
        if (!due.isBefore(today)) {
          result.add((rule: rule, date: due));
        }
        due = advanceDate(due, rule.frequency);
      }
    }
    result.sort(
      (({RecurringRule rule, DateTime date}) a,
              ({RecurringRule rule, DateTime date}) b) =>
          a.date.compareTo(b.date),
    );
    return result;
  }

  /// Total of recurring expenses (active rules only) with an
  /// occurrence between [from] and [to], both inclusive.
  double _upcomingExpenseBetween(DateTime from, DateTime to) {
    double total = 0;
    for (final RecurringRule rule in _rules) {
      if (!rule.active || rule.isIncome) {
        continue;
      }
      DateTime due = _dateOnly(rule.nextDue);
      int guard = 0;
      while (!due.isAfter(to) && guard < 600) {
        guard++;
        if (!due.isBefore(from)) {
          total += rule.amount;
        }
        due = advanceDate(due, rule.frequency);
      }
    }
    return total;
  }

  /// Active recurring expense rules, the subscriptions view.
  List<RecurringRule> get subscriptionRules {
    return _rules.where((RecurringRule r) => r.active && !r.isIncome).toList();
  }

  /// Monthly cost of one rule, normalized by its frequency.
  double monthlyCostOf(RecurringRule rule) {
    return rule.amount * rule.frequency.monthlyFactor;
  }

  /// Total monthly cost of all active subscriptions.
  double get totalMonthlySubscriptionCost {
    return subscriptionRules.fold(
      0.0,
      (double sum, RecurringRule r) => sum + monthlyCostOf(r),
    );
  }

  // ---------------------------------------------------------------
  // Savings goals
  // ---------------------------------------------------------------

  List<Goal> get goals => List<Goal>.unmodifiable(_goals);

  Future<void> addGoal(Goal goal) async {
    _goals = <Goal>[..._goals, goal];
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _saveGoals(prefs);
    notifyListeners();
  }

  Future<void> deleteGoal(String id) async {
    _goals = _goals.where((Goal g) => g.id != id).toList();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _saveGoals(prefs);
    notifyListeners();
  }

  /// Adds [amount] to a goal's savings (negative removes). The saved
  /// amount is clamped between 0 and the target.
  Future<void> addToGoal(String id, double amount) async {
    _goals = _goals.map((Goal g) {
      if (g.id != id) {
        return g;
      }
      double next = g.saved + amount;
      if (next < 0) {
        next = 0;
      }
      if (next > g.target) {
        next = g.target;
      }
      return g.copyWith(saved: next);
    }).toList();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _saveGoals(prefs);
    notifyListeners();
  }

  // ---------------------------------------------------------------
  // Debts (dena paona)
  // ---------------------------------------------------------------

  /// All debt entries, newest first.
  List<DebtEntry> get debts {
    final List<DebtEntry> sorted = List<DebtEntry>.from(_debts);
    sorted.sort((DebtEntry a, DebtEntry b) => b.date.compareTo(a.date));
    return List<DebtEntry>.unmodifiable(sorted);
  }

  Future<void> addDebt(DebtEntry entry) async {
    _debts = <DebtEntry>[..._debts, entry];
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _saveDebts(prefs);
    notifyListeners();
  }

  Future<void> deleteDebt(String id) async {
    _debts = _debts.where((DebtEntry d) => d.id != id).toList();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _saveDebts(prefs);
    notifyListeners();
  }

  /// Records a repayment against an entry. The settled total is
  /// clamped so it never goes below 0 or above the entry amount.
  Future<void> recordSettlement(String id, double amount) async {
    _debts = _debts.map((DebtEntry d) {
      if (d.id != id) {
        return d;
      }
      double next = d.settled + amount;
      if (next < 0) {
        next = 0;
      }
      if (next > d.amount) {
        next = d.amount;
      }
      return d.copyWith(settled: next);
    }).toList();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _saveDebts(prefs);
    notifyListeners();
  }

  /// Total still owed to the user by other people.
  double get totalLentRemaining {
    return _debts
        .where((DebtEntry d) => d.iLent)
        .fold(0.0, (double sum, DebtEntry d) => sum + d.remaining);
  }

  /// Total the user still owes to other people.
  double get totalBorrowedRemaining {
    return _debts
        .where((DebtEntry d) => !d.iLent)
        .fold(0.0, (double sum, DebtEntry d) => sum + d.remaining);
  }

  /// Plain text statement of every entry for one person, with the
  /// outstanding balance, ready to paste into WhatsApp.
  String statementFor(String person) {
    final String wanted = person.trim().toLowerCase();
    final List<DebtEntry> entries = _debts
        .where((DebtEntry d) => d.person.trim().toLowerCase() == wanted)
        .toList()
      ..sort((DebtEntry a, DebtEntry b) => a.date.compareTo(b.date));
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('Dena paona statement for $person');
    double lentRemaining = 0;
    double borrowedRemaining = 0;
    for (final DebtEntry entry in entries) {
      final String direction = entry.iLent ? 'Lent' : 'Borrowed';
      String line =
          '${fmtDate(entry.date)} - $direction - ${fmtMoney(entry.amount)}';
      if (entry.note.isNotEmpty) {
        line = '$line - ${entry.note}';
      }
      buffer.writeln(line);
      if (entry.settled > 0) {
        buffer.writeln('  Settled: ${fmtMoney(entry.settled)}');
      }
      if (entry.iLent) {
        lentRemaining += entry.remaining;
      } else {
        borrowedRemaining += entry.remaining;
      }
    }
    if (lentRemaining > 0) {
      buffer.writeln('They still owe you: ${fmtMoney(lentRemaining)}');
    }
    if (borrowedRemaining > 0) {
      buffer.writeln('You still owe them: ${fmtMoney(borrowedRemaining)}');
    }
    if (lentRemaining <= 0 && borrowedRemaining <= 0) {
      buffer.writeln('All settled.');
    }
    return buffer.toString().trim();
  }

  // ---------------------------------------------------------------
  // Net worth
  // ---------------------------------------------------------------

  /// Accounts total plus money others owe the user, minus money the
  /// user owes others.
  double get netWorth {
    return totalBalance + totalLentRemaining - totalBorrowedRemaining;
  }

  // ---------------------------------------------------------------
  // Settings and PIN lock
  // ---------------------------------------------------------------

  bool get hideAmounts => _hideAmounts;

  Future<void> setHideAmounts(bool value) async {
    _hideAmounts = value;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hideAmountsKey, value);
    notifyListeners();
  }

  bool get hasPin => _pinHash != null && _pinHash!.isNotEmpty;

  String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }

  Future<void> setPin(String pin) async {
    _pinHash = _hashPin(pin);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinHashKey, _pinHash!);
    notifyListeners();
  }

  bool verifyPin(String pin) {
    if (!hasPin) {
      return false;
    }
    return _hashPin(pin) == _pinHash;
  }

  Future<void> clearPin() async {
    _pinHash = null;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinHashKey);
    notifyListeners();
  }

  // ---------------------------------------------------------------
  // Backup: export and import
  // ---------------------------------------------------------------

  Map<String, dynamic> _dataMap() {
    return <String, dynamic>{
      'version': 1,
      'txns': _txns.map((Txn t) => t.toJson()).toList(),
      'budgets': _budgets,
      'accounts': _accounts.map((Account a) => a.toJson()).toList(),
      'transfers': _transfers.map((Transfer t) => t.toJson()).toList(),
      'rules': _rules.map((RecurringRule r) => r.toJson()).toList(),
      'goals': _goals.map((Goal g) => g.toJson()).toList(),
      'debts': _debts.map((DebtEntry d) => d.toJson()).toList(),
      'hideAmounts': _hideAmounts,
    };
  }

  /// The whole app data as one JSON string. The PIN hash is never
  /// included.
  String exportJson() {
    return jsonEncode(_dataMap());
  }

  /// Replaces all data with the contents of a backup made by
  /// [exportJson]. Returns true on success. On any problem the
  /// current data is left untouched and false is returned.
  Future<bool> importJson(String text) async {
    try {
      final dynamic decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        return false;
      }
      if (decoded['txns'] is! List) {
        return false;
      }
      final List<Txn> newTxns = (decoded['txns'] as List<dynamic>)
          .map((dynamic e) => Txn.fromJson(e as Map<String, dynamic>))
          .toList();

      Map<String, double> newBudgets = <String, double>{};
      if (decoded['budgets'] is Map) {
        final Map<String, dynamic> rawBudgets =
            (decoded['budgets'] as Map<dynamic, dynamic>)
                .cast<String, dynamic>();
        newBudgets = rawBudgets.map(
          (String key, dynamic value) =>
              MapEntry<String, double>(key, (value as num).toDouble()),
        );
      }

      List<Account> newAccounts = presetAccounts();
      if (decoded['accounts'] is List &&
          (decoded['accounts'] as List<dynamic>).isNotEmpty) {
        newAccounts = (decoded['accounts'] as List<dynamic>)
            .map((dynamic e) => Account.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      List<Transfer> newTransfers = <Transfer>[];
      if (decoded['transfers'] is List) {
        newTransfers = (decoded['transfers'] as List<dynamic>)
            .map((dynamic e) => Transfer.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      List<RecurringRule> newRules = <RecurringRule>[];
      if (decoded['rules'] is List) {
        newRules = (decoded['rules'] as List<dynamic>)
            .map(
              (dynamic e) => RecurringRule.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      }

      List<Goal> newGoals = <Goal>[];
      if (decoded['goals'] is List) {
        newGoals = (decoded['goals'] as List<dynamic>)
            .map((dynamic e) => Goal.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      List<DebtEntry> newDebts = <DebtEntry>[];
      if (decoded['debts'] is List) {
        newDebts = (decoded['debts'] as List<dynamic>)
            .map((dynamic e) => DebtEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      final bool newHide = (decoded['hideAmounts'] as bool?) ?? _hideAmounts;

      _txns = newTxns;
      _budgets = newBudgets;
      _accounts = newAccounts;
      _transfers = newTransfers;
      _rules = newRules;
      _goals = newGoals;
      _debts = newDebts;
      _hideAmounts = newHide;

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await _saveAll(prefs);
      await prefs.setBool(_hideAmountsKey, _hideAmounts);
      await prefs.setBool(_seededKey, true);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  String _csvCell(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// All transactions as CSV text: date, type, category, account,
  /// amount, tag, note. Oldest first.
  String exportCsv() {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('date,type,category,account,amount,tag,note');
    final List<Txn> sorted = List<Txn>.from(_txns)
      ..sort((Txn a, Txn b) => a.date.compareTo(b.date));
    for (final Txn txn in sorted) {
      final String date = txn.date.toIso8601String().substring(0, 10);
      final String type = txn.isIncome ? 'income' : 'expense';
      final List<String> cells = <String>[
        date,
        type,
        txn.category,
        accountName(txn.accountId),
        txn.amount.toStringAsFixed(2),
        txn.tag,
        txn.note,
      ];
      buffer.writeln(cells.map(_csvCell).join(','));
    }
    return buffer.toString().trim();
  }

  // ---------------------------------------------------------------
  // Loading, saving, demo data
  // ---------------------------------------------------------------

  /// Loads saved data. On the very first run it seeds demo data once;
  /// the seeded flag keeps the demo data from coming back after the
  /// user clears everything. Due recurring rules are posted after
  /// every load.
  Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool seeded = prefs.getBool(_seededKey) ?? false;

    if (!seeded) {
      _txns = _demoTxns();
      _budgets = _defaultBudgets();
      _accounts = presetAccounts();
      _transfers = <Transfer>[];
      _rules = <RecurringRule>[];
      _goals = <Goal>[];
      _debts = <DebtEntry>[];
      await _saveAll(prefs);
      await prefs.setBool(_seededKey, true);
    } else {
      _txns = _readTxns(prefs);
      _budgets = _readBudgets(prefs);
      _accounts = _readList<Account>(
        prefs,
        _accountsKey,
        (Map<String, dynamic> json) => Account.fromJson(json),
      );
      if (_accounts.isEmpty) {
        // Upgrade from v1.0, which had no accounts: create presets.
        _accounts = presetAccounts();
        await _saveAccounts(prefs);
      }
      _transfers = _readList<Transfer>(
        prefs,
        _transfersKey,
        (Map<String, dynamic> json) => Transfer.fromJson(json),
      );
      _rules = _readList<RecurringRule>(
        prefs,
        _rulesKey,
        (Map<String, dynamic> json) => RecurringRule.fromJson(json),
      );
      _goals = _readList<Goal>(
        prefs,
        _goalsKey,
        (Map<String, dynamic> json) => Goal.fromJson(json),
      );
      _debts = _readList<DebtEntry>(
        prefs,
        _debtsKey,
        (Map<String, dynamic> json) => DebtEntry.fromJson(json),
      );
    }
    _hideAmounts = prefs.getBool(_hideAmountsKey) ?? false;
    _pinHash = prefs.getString(_pinHashKey);
    await processDueRecurring();
    _loaded = true;
    notifyListeners();
  }

  /// Removes all financial data. Preset accounts are recreated empty
  /// so the app stays usable. The seeded flag stays set, so demo data
  /// does not return. PIN and display settings are kept.
  Future<void> clearAllData() async {
    _txns = <Txn>[];
    _budgets = <String, double>{};
    _accounts = presetAccounts();
    _transfers = <Transfer>[];
    _rules = <RecurringRule>[];
    _goals = <Goal>[];
    _debts = <DebtEntry>[];
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_txnsKey);
    await prefs.remove(_budgetsKey);
    await prefs.remove(_transfersKey);
    await prefs.remove(_rulesKey);
    await prefs.remove(_goalsKey);
    await prefs.remove(_debtsKey);
    await _saveAccounts(prefs);
    await prefs.setBool(_seededKey, true);
    notifyListeners();
  }

  /// Restores the demo transactions and default budgets, with empty
  /// preset accounts and no transfers, rules, goals or debts.
  Future<void> resetToDemo() async {
    _txns = _demoTxns();
    _budgets = _defaultBudgets();
    _accounts = presetAccounts();
    _transfers = <Transfer>[];
    _rules = <RecurringRule>[];
    _goals = <Goal>[];
    _debts = <DebtEntry>[];
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _saveAll(prefs);
    await prefs.setBool(_seededKey, true);
    notifyListeners();
  }

  List<T> _readList<T>(
    SharedPreferences prefs,
    String key,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final String? raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return <T>[];
    }
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((dynamic e) => fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return <T>[];
    }
  }

  List<Txn> _readTxns(SharedPreferences prefs) {
    return _readList<Txn>(
      prefs,
      _txnsKey,
      (Map<String, dynamic> json) => Txn.fromJson(json),
    );
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

  Future<void> _saveList<T>(
    SharedPreferences prefs,
    String key,
    List<T> items,
    Map<String, dynamic> Function(T item) toJson,
  ) async {
    final List<Map<String, dynamic>> list = items.map(toJson).toList();
    await prefs.setString(key, jsonEncode(list));
  }

  Future<void> _saveTxns(SharedPreferences prefs) async {
    await _saveList<Txn>(
      prefs,
      _txnsKey,
      _txns,
      (Txn t) => t.toJson(),
    );
  }

  Future<void> _saveBudgets(SharedPreferences prefs) async {
    await prefs.setString(_budgetsKey, jsonEncode(_budgets));
  }

  Future<void> _saveAccounts(SharedPreferences prefs) async {
    await _saveList<Account>(
      prefs,
      _accountsKey,
      _accounts,
      (Account a) => a.toJson(),
    );
  }

  Future<void> _saveTransfers(SharedPreferences prefs) async {
    await _saveList<Transfer>(
      prefs,
      _transfersKey,
      _transfers,
      (Transfer t) => t.toJson(),
    );
  }

  Future<void> _saveRules(SharedPreferences prefs) async {
    await _saveList<RecurringRule>(
      prefs,
      _rulesKey,
      _rules,
      (RecurringRule r) => r.toJson(),
    );
  }

  Future<void> _saveGoals(SharedPreferences prefs) async {
    await _saveList<Goal>(
      prefs,
      _goalsKey,
      _goals,
      (Goal g) => g.toJson(),
    );
  }

  Future<void> _saveDebts(SharedPreferences prefs) async {
    await _saveList<DebtEntry>(
      prefs,
      _debtsKey,
      _debts,
      (DebtEntry d) => d.toJson(),
    );
  }

  Future<void> _saveAll(SharedPreferences prefs) async {
    await _saveTxns(prefs);
    await _saveBudgets(prefs);
    await _saveAccounts(prefs);
    await _saveTransfers(prefs);
    await _saveRules(prefs);
    await _saveGoals(prefs);
    await _saveDebts(prefs);
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
