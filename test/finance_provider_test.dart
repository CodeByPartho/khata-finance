import 'package:flutter_test/flutter_test.dart';
import 'package:khata_finance/models/transaction.dart';
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
    DateTime? date,
  }) {
    return Txn(
      id: id,
      amount: amount,
      isIncome: isIncome,
      category: category,
      date: date ?? DateTime.now(),
      note: 'test $id',
    );
  }

  test('adding income and expense updates balance and monthly totals',
      () async {
    final FinanceProvider provider = await emptyProvider();
    final DateTime now = DateTime.now();

    await provider.addTxn(
      makeTxn(id: 't1', amount: 10000, isIncome: true, category: 'Salary'),
    );
    await provider.addTxn(
      makeTxn(id: 't2', amount: 2500, isIncome: false, category: 'Food'),
    );

    expect(provider.balance, 7500);
    expect(provider.incomeForMonth(now), 10000);
    expect(provider.expenseForMonth(now), 2500);
    expect(provider.txnsForMonth(now).length, 2);
  });

  test('expenseByCategory sums correctly per category', () async {
    final FinanceProvider provider = await emptyProvider();
    final DateTime now = DateTime.now();

    await provider.addTxn(
      makeTxn(id: 'a', amount: 1000, isIncome: false, category: 'Food'),
    );
    await provider.addTxn(
      makeTxn(id: 'b', amount: 500, isIncome: false, category: 'Food'),
    );
    await provider.addTxn(
      makeTxn(id: 'c', amount: 300, isIncome: false, category: 'Transport'),
    );
    await provider.addTxn(
      makeTxn(id: 'd', amount: 9000, isIncome: true, category: 'Salary'),
    );

    final Map<String, double> result = provider.expenseByCategory(now);
    expect(result['Food'], 1500);
    expect(result['Transport'], 300);
    expect(result.containsKey('Salary'), isFalse);
  });

  test('monthlyExpenses returns the last 6 months including current', () async {
    final FinanceProvider provider = await emptyProvider();

    await provider.addTxn(
      makeTxn(id: 'm1', amount: 700, isIncome: false, category: 'Bills'),
    );

    final List<({DateTime month, double total})> months =
        provider.monthlyExpenses();
    expect(months.length, 6);
    expect(months.last.total, 700);
    expect(months.first.total, 0);
  });

  test('budgetProgress returns the expected ratio', () async {
    final FinanceProvider provider = await emptyProvider();
    final DateTime now = DateTime.now();

    await provider.setBudget('Food', 2000);
    expect(provider.budgetProgress('Food', now), 0);

    await provider.addTxn(
      makeTxn(id: 'p1', amount: 500, isIncome: false, category: 'Food'),
    );
    expect(provider.budgetProgress('Food', now), 0.25);

    await provider.addTxn(
      makeTxn(id: 'p2', amount: 1500, isIncome: false, category: 'Food'),
    );
    expect(provider.budgetProgress('Food', now), 1.0);

    await provider.addTxn(
      makeTxn(id: 'p3', amount: 1000, isIncome: false, category: 'Food'),
    );
    expect(provider.budgetProgress('Food', now), 1.5);
  });
}
