import 'package:flutter_test/flutter_test.dart';
import 'package:khata_finance/models/debt_entry.dart';
import 'package:khata_finance/models/goal.dart';
import 'package:khata_finance/models/recurring_rule.dart';
import 'package:khata_finance/models/transaction.dart';
import 'package:khata_finance/models/transfer.dart';
import 'package:khata_finance/state/finance_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<FinanceProvider> emptyProvider() async {
    final FinanceProvider provider = FinanceProvider();
    await provider.load();
    await provider.clearAllData();
    return provider;
  }

  Txn makeTxn({
    required String id,
    required double amount,
    required bool isIncome,
    required String category,
    String accountId = 'cash',
    DateTime? date,
  }) {
    return Txn(
      id: id,
      amount: amount,
      isIncome: isIncome,
      category: category,
      date: date ?? DateTime.now(),
      note: 'test $id',
      accountId: accountId,
    );
  }

  test('transfer moves balance between accounts and fee reduces source',
      () async {
    final FinanceProvider provider = await emptyProvider();
    final DateTime now = DateTime.now();

    await provider.addTxn(
      makeTxn(id: 'in1', amount: 10000, isIncome: true, category: 'Salary'),
    );
    await provider.addTransfer(
      Transfer(
        id: 'tr1',
        fromAccountId: 'cash',
        toAccountId: 'bkash',
        amount: 3000,
        fee: 50,
        date: now,
      ),
    );

    expect(provider.accountBalance('cash'), 6950);
    expect(provider.accountBalance('bkash'), 3000);
    expect(provider.totalBalance, 9950);
    // A transfer is not income or expense.
    expect(provider.incomeForMonth(now), 10000);
    expect(provider.expenseForMonth(now), 0);
  });

  test('due recurring rule posts a txn and advances nextDue past today',
      () async {
    final FinanceProvider provider = await emptyProvider();
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    await provider.addRule(
      RecurringRule(
        id: 'r1',
        amount: 1200,
        isIncome: false,
        category: 'Bills',
        accountId: 'cash',
        note: 'Internet bill',
        frequency: RecurringFrequency.monthly,
        nextDue: today,
      ),
    );

    final int posted = await provider.processDueRecurring();
    expect(posted, 1);
    expect(provider.txns.length, 1);
    expect(provider.txns.first.amount, 1200);
    expect(provider.txns.first.category, 'Bills');
    expect(provider.txns.first.tag, 'recurring');
    expect(provider.expenseForMonth(now), 1200);

    final RecurringRule rule = provider.rules.first;
    expect(rule.nextDue.isAfter(today), isTrue);

    // Calling again posts nothing new.
    final int postedAgain = await provider.processDueRecurring();
    expect(postedAgain, 0);
    expect(provider.txns.length, 1);
  });

  test('goal savings accumulate and clamp at the target', () async {
    final FinanceProvider provider = await emptyProvider();

    await provider.addGoal(
      const Goal(id: 'g1', name: 'New phone', target: 10000),
    );
    await provider.addToGoal('g1', 4000);
    expect(provider.goals.first.saved, 4000);
    expect(provider.goals.first.progress, 0.4);

    await provider.addToGoal('g1', 9000);
    expect(provider.goals.first.saved, 10000);
    expect(provider.goals.first.progress, 1.0);

    await provider.addToGoal('g1', -2500);
    expect(provider.goals.first.saved, 7500);
  });

  test('debt remaining falls with settlements and clamps at zero', () async {
    final FinanceProvider provider = await emptyProvider();

    await provider.addDebt(
      DebtEntry(
        id: 'd1',
        person: 'Rahim',
        amount: 5000,
        iLent: true,
        date: DateTime.now(),
        note: 'Lunch and travel',
      ),
    );
    expect(provider.totalLentRemaining, 5000);
    expect(provider.totalBorrowedRemaining, 0);

    await provider.recordSettlement('d1', 2000);
    expect(provider.debts.first.remaining, 3000);
    expect(provider.totalLentRemaining, 3000);

    await provider.recordSettlement('d1', 9999);
    expect(provider.debts.first.remaining, 0);
    expect(provider.totalLentRemaining, 0);
    expect(
      provider.statementFor('Rahim'),
      contains('All settled.'),
    );
  });

  test('safeToSpend uses budgets minus expenses and upcoming bills', () async {
    final FinanceProvider provider = await emptyProvider();
    final DateTime now = DateTime.now();
    final DateTime lastDay = DateTime(now.year, now.month + 1, 0);

    await provider.setBudget('Food', 10000);
    await provider.setBudget('Bills', 5000);
    await provider.addTxn(
      makeTxn(id: 'e1', amount: 3000, isIncome: false, category: 'Food'),
    );
    await provider.addRule(
      RecurringRule(
        id: 'r-bill',
        amount: 2000,
        isIncome: false,
        category: 'Bills',
        accountId: 'cash',
        note: 'Internet bill',
        frequency: RecurringFrequency.monthly,
        nextDue: lastDay,
      ),
    );

    // 15000 budgets - 3000 spent - 2000 still due this month.
    expect(provider.safeToSpend(), 10000);
  });

  test('exportJson then importJson restores txns and balances', () async {
    final FinanceProvider provider = await emptyProvider();
    final DateTime now = DateTime.now();

    await provider.addTxn(
      makeTxn(id: 'x1', amount: 20000, isIncome: true, category: 'Salary'),
    );
    await provider.addTxn(
      makeTxn(
        id: 'x2',
        amount: 5000,
        isIncome: false,
        category: 'Food',
        accountId: 'bkash',
      ),
    );
    await provider.addTransfer(
      Transfer(
        id: 'tr-x',
        fromAccountId: 'cash',
        toAccountId: 'bkash',
        amount: 4000,
        fee: 40,
        date: now,
      ),
    );

    final int txnCount = provider.txns.length;
    final double cashBalance = provider.accountBalance('cash');
    final double bkashBalance = provider.accountBalance('bkash');
    final double total = provider.totalBalance;
    expect(cashBalance, 15960);
    expect(bkashBalance, -1000);

    final String backup = provider.exportJson();
    expect(backup.contains('pin'), isFalse);

    await provider.clearAllData();
    expect(provider.txns.length, 0);
    expect(provider.totalBalance, 0);

    final bool ok = await provider.importJson(backup);
    expect(ok, isTrue);
    expect(provider.txns.length, txnCount);
    expect(provider.accountBalance('cash'), cashBalance);
    expect(provider.accountBalance('bkash'), bkashBalance);
    expect(provider.totalBalance, total);
    expect(provider.transfers.length, 1);

    final bool bad = await provider.importJson('not json at all');
    expect(bad, isFalse);
    expect(provider.txns.length, txnCount);
  });

  test('pin is stored as a hash and verifies correctly', () async {
    final FinanceProvider provider = await emptyProvider();
    expect(provider.hasPin, isFalse);

    await provider.setPin('2468');
    expect(provider.hasPin, isTrue);
    expect(provider.verifyPin('2468'), isTrue);
    expect(provider.verifyPin('0000'), isFalse);

    await provider.clearPin();
    expect(provider.hasPin, isFalse);
  });

  test('subscription monthly cost normalizes frequencies', () async {
    final FinanceProvider provider = await emptyProvider();
    final DateTime now = DateTime.now();

    await provider.addRule(
      RecurringRule(
        id: 'sub1',
        amount: 1200,
        isIncome: false,
        category: 'Bills',
        accountId: 'cash',
        note: 'Streaming',
        frequency: RecurringFrequency.yearly,
        nextDue: DateTime(now.year, now.month + 2, 1),
      ),
    );
    await provider.addRule(
      RecurringRule(
        id: 'sub2',
        amount: 100,
        isIncome: false,
        category: 'Entertainment',
        accountId: 'cash',
        note: 'Weekly app',
        frequency: RecurringFrequency.weekly,
        nextDue: DateTime(now.year, now.month, now.day + 3),
      ),
    );

    // 1200 yearly = 100 per month; 100 weekly = 433.33 per month.
    expect(provider.subscriptionRules.length, 2);
    expect(
      provider.totalMonthlySubscriptionCost,
      closeTo(100 + (100 * 52 / 12), 0.01),
    );
    expect(provider.netWorth, provider.totalBalance);
  });
}
