import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:khata_finance/logic/bangla_parser.dart';
import 'package:khata_finance/logic/card_cycle.dart';
import 'package:khata_finance/logic/debt_planner.dart';
import 'package:khata_finance/logic/receipt_parser.dart';
import 'package:khata_finance/models/debt_entry.dart';
import 'package:khata_finance/models/payment_card.dart';
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
    while (!provider.isLoaded) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await provider.clearAllData();
    return provider;
  }

  // ---------------------------------------------------------------
  // Debt payoff planner
  // ---------------------------------------------------------------

  group('debt payoff planner', () {
    test('avalanche orders by highest interest first', () {
      final List<PlannerDebt> debts = <PlannerDebt>[
        const PlannerDebt(
          id: 'a',
          name: 'Low rate',
          balance: 5000,
          annualRatePercent: 5,
          minPayment: 200,
        ),
        const PlannerDebt(
          id: 'b',
          name: 'High rate',
          balance: 1000,
          annualRatePercent: 20,
          minPayment: 100,
        ),
      ];
      final List<PlannerDebt> ordered =
          orderDebts(debts, PayoffStrategy.avalanche);
      expect(ordered.map((PlannerDebt d) => d.id).toList(), <String>[
        'b',
        'a',
      ]);
    });

    test('snowball orders by smallest balance first', () {
      final List<PlannerDebt> debts = <PlannerDebt>[
        const PlannerDebt(
          id: 'a',
          name: 'Big',
          balance: 5000,
          annualRatePercent: 20,
          minPayment: 200,
        ),
        const PlannerDebt(
          id: 'b',
          name: 'Small',
          balance: 1000,
          annualRatePercent: 5,
          minPayment: 100,
        ),
      ];
      final List<PlannerDebt> ordered =
          orderDebts(debts, PayoffStrategy.snowball);
      expect(ordered.map((PlannerDebt d) => d.id).toList(), <String>[
        'b',
        'a',
      ]);
    });

    test('interest free debt clears in balance divided by payment months',
        () {
      final PayoffPlan? plan = planDebts(
        <PlannerDebt>[
          const PlannerDebt(
            id: 'a',
            name: 'Loan',
            balance: 1000,
            minPayment: 100,
          ),
        ],
        PayoffStrategy.avalanche,
        100,
      );
      expect(plan, isNotNull);
      expect(plan!.totalMonths, 5);
      expect(plan.totalInterest, 0);
      expect(plan.interestSaved, 0);
      expect(plan.steps.first.monthsToClear, 5);
    });

    test('extra payment saves interest and shortens the plan', () {
      final List<PlannerDebt> debts = <PlannerDebt>[
        const PlannerDebt(
          id: 'a',
          name: 'Card',
          balance: 12000,
          annualRatePercent: 24,
          minPayment: 300,
        ),
        const PlannerDebt(
          id: 'b',
          name: 'Loan',
          balance: 6000,
          annualRatePercent: 12,
          minPayment: 200,
        ),
      ];
      final PayoffPlan? withExtra =
          planDebts(debts, PayoffStrategy.avalanche, 1000);
      final PayoffPlan? minimumOnly =
          planDebts(debts, PayoffStrategy.avalanche, 0);
      expect(withExtra, isNotNull);
      expect(minimumOnly, isNotNull);
      expect(
        withExtra!.totalMonths,
        lessThan(minimumOnly!.totalMonths),
      );
      expect(withExtra.interestSaved, greaterThan(0));
      expect(
        withExtra.totalInterest + withExtra.interestSaved,
        closeTo(minimumOnly.totalInterest, 0.01),
      );
    });

    test('minimum below monthly interest never clears', () {
      final PayoffPlan? plan = planDebts(
        <PlannerDebt>[
          const PlannerDebt(
            id: 'a',
            name: 'Card',
            balance: 10000,
            annualRatePercent: 24,
            minPayment: 100,
          ),
        ],
        PayoffStrategy.avalanche,
        0,
      );
      expect(plan, isNull);
    });

    test('empty debt list is debt free in zero months', () {
      final PayoffPlan? plan =
          planDebts(<PlannerDebt>[], PayoffStrategy.snowball, 500);
      expect(plan, isNotNull);
      expect(plan!.totalMonths, 0);
      expect(plan.steps, isEmpty);
    });
  });

  // ---------------------------------------------------------------
  // Separate books
  // ---------------------------------------------------------------

  group('separate books', () {
    test('a transaction in one book never appears in another', () async {
      final FinanceProvider provider = await emptyProvider();
      expect(provider.activeBook.name, 'Personal');
      await provider.addTxn(
        Txn(
          id: 'p1',
          amount: 500,
          isIncome: false,
          category: 'Food',
          date: DateTime.now(),
          note: 'personal lunch',
        ),
      );
      expect(provider.txns.length, 1);

      final String shopId = (await provider.addBook('Shop')).id;
      expect(provider.activeBookId, shopId);
      expect(provider.txns, isEmpty);
      await provider.addTxn(
        Txn(
          id: 's1',
          amount: 2000,
          isIncome: true,
          category: 'Business',
          date: DateTime.now(),
          note: 'shop sale',
        ),
      );
      expect(provider.txns.length, 1);
      expect(provider.txns.first.note, 'shop sale');

      await provider.switchBook('personal');
      expect(provider.txns.length, 1);
      expect(provider.txns.first.note, 'personal lunch');

      await provider.switchBook(shopId);
      expect(provider.txns.length, 1);
      expect(provider.txns.first.note, 'shop sale');
    });

    test('budgets and debts are separate per book', () async {
      final FinanceProvider provider = await emptyProvider();
      await provider.setBudget('Food', 10000);
      await provider.addDebt(
        DebtEntry(
          id: 'd1',
          person: 'Rahim',
          amount: 3000,
          iLent: false,
          date: DateTime.now(),
        ),
      );
      await provider.addBook('Family');
      expect(provider.budgetFor('Food'), 0);
      expect(provider.debts, isEmpty);
      await provider.switchBook('personal');
      expect(provider.budgetFor('Food'), 10000);
      expect(provider.debts.length, 1);
    });

    test('v1.1 data migrates into the Personal book once', () async {
      final Txn oldTxn = Txn(
        id: 'old1',
        amount: 750,
        isIncome: false,
        category: 'Transport',
        date: DateTime(2026, 11, 1),
        note: 'old bus fare',
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        'khata_seeded_v1': true,
        'khata_txns_v1': jsonEncode(<Map<String, dynamic>>[oldTxn.toJson()]),
        'khata_accounts_v1': jsonEncode(<Map<String, dynamic>>[]),
      });
      final FinanceProvider provider = FinanceProvider();
      while (!provider.isLoaded) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(provider.activeBook.name, 'Personal');
      expect(provider.txns.length, 1);
      expect(provider.txns.first.note, 'old bus fare');
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('khata_txns_v1'), isNull);
      expect(
        prefs.getString('khata_personal_txns_v1'),
        isNotNull,
      );
    });
  });

  // ---------------------------------------------------------------
  // Bangla entry parser
  // ---------------------------------------------------------------

  group('bangla entry parser', () {
    test('banglish bazar maps to Food expense', () {
      final ParsedQuickEntry? parsed = parseQuickEntry('bazar 500');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 500);
      expect(parsed.isIncome, isFalse);
      expect(parsed.category, 'Food');
    });

    test('bangla digits convert and match bazar', () {
      final ParsedQuickEntry? parsed = parseQuickEntry('বাজার ৫০০');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 500);
      expect(parsed.category, 'Food');
    });

    test('salary maps to income', () {
      final ParsedQuickEntry? parsed = parseQuickEntry('salary 25000');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 25000);
      expect(parsed.isIncome, isTrue);
      expect(parsed.category, 'Salary');
    });

    test('bus fare maps to Transport with bangla digits', () {
      final ParsedQuickEntry? parsed = parseQuickEntry('bus vara ১২০');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 120);
      expect(parsed.category, 'Transport');
    });

    test('amount with commas parses', () {
      final ParsedQuickEntry? parsed = parseQuickEntry('salary 25,000');
      expect(parsed, isNotNull);
      expect(parsed!.amount, 25000);
    });

    test('unknown keyword falls back to Other', () {
      final ParsedQuickEntry? parsed = parseQuickEntry('something 123');
      expect(parsed, isNotNull);
      expect(parsed!.category, 'Other');
      expect(parsed.isIncome, isFalse);
    });

    test('no amount returns null', () {
      expect(parseQuickEntry('bazar'), isNull);
      expect(parseQuickEntry(''), isNull);
    });

    test('bangla digit conversion', () {
      expect(convertBanglaDigits('৫০০'), '500');
      expect(convertBanglaDigits('১২৩৪৫৬৭৮৯০'), '1234567890');
    });
  });

  // ---------------------------------------------------------------
  // Card cycles
  // ---------------------------------------------------------------

  group('card cycle math', () {
    test('cycle starting on the 1st spans the whole month', () {
      const CardCycle cycle =
          CardCycle(billingStartDay: 1, dueDay: 15);
      final DateTime date = DateTime(2026, 11, 13);
      expect(cycle.cycleStart(date), DateTime(2026, 11, 1));
      expect(cycle.cycleEnd(date), DateTime(2026, 11, 30));
      expect(cycle.daysLeftInCycle(date), 18);
      expect(cycle.dueDate(date), DateTime(2026, 12, 15));
      expect(cycle.daysUntilDue(date), 32);
    });

    test('cycle starting mid month spans two months', () {
      const CardCycle cycle =
          CardCycle(billingStartDay: 20, dueDay: 15);
      final DateTime date = DateTime(2026, 11, 13);
      expect(cycle.cycleStart(date), DateTime(2026, 10, 20));
      expect(cycle.cycleEnd(date), DateTime(2026, 11, 19));
      expect(cycle.daysLeftInCycle(date), 7);
      expect(cycle.dueDate(date), DateTime(2026, 11, 15));
      expect(cycle.daysUntilDue(date), 2);
    });

    test('last day of the cycle has one day left', () {
      const CardCycle cycle =
          CardCycle(billingStartDay: 1, dueDay: 15);
      expect(
        cycle.daysLeftInCycle(DateTime(2026, 11, 30)),
        1,
      );
    });

    test('start day 31 clamps to the last day of short months', () {
      const CardCycle cycle =
          CardCycle(billingStartDay: 31, dueDay: 15);
      final DateTime date = DateTime(2026, 2, 15);
      expect(cycle.cycleStart(date), DateTime(2026, 1, 31));
      expect(cycle.cycleEnd(date), DateTime(2026, 2, 27));
      expect(cycle.daysLeftInCycle(date), 13);
    });

    test('card cycle spend counts only this cycle and linked account',
        () async {
      final FinanceProvider provider = await emptyProvider();
      const PaymentCard card = PaymentCard(
        id: 'c1',
        name: 'Visa',
        billingStartDay: 1,
        dueDay: 15,
        accountId: 'cash',
      );
      await provider.addCard(card);
      final DateTime now = DateTime.now();
      final DateTime thisMonth = DateTime(now.year, now.month, 5);
      final DateTime lastMonth =
          DateTime(now.year, now.month - 1, 5);
      await provider.addTxn(
        Txn(
          id: 't1',
          amount: 1000,
          isIncome: false,
          category: 'Shopping',
          date: thisMonth,
          note: 'cycle spend',
          accountId: 'cash',
        ),
      );
      await provider.addTxn(
        Txn(
          id: 't2',
          amount: 9999,
          isIncome: false,
          category: 'Shopping',
          date: lastMonth,
          note: 'old spend',
          accountId: 'cash',
        ),
      );
      await provider.addTxn(
        Txn(
          id: 't3',
          amount: 777,
          isIncome: false,
          category: 'Shopping',
          date: thisMonth,
          note: 'other account',
          accountId: 'bkash',
        ),
      );
      expect(provider.cardCycleSpend(card, now: now), 1000);
    });
  });

  // ---------------------------------------------------------------
  // Receipt text parsing
  // ---------------------------------------------------------------

  group('receipt text parsing', () {
    test('total line wins over other amounts', () {
      const String text = 'Shwapno\nRice 450.00\nOil 320.00\n'
          'Total: 1,250.00\nThank you';
      final ParsedReceipt parsed = parseReceiptText(text);
      expect(parsed.total, 1250);
      expect(parsed.merchant, 'Shwapno');
    });

    test('falls back to the largest amount without a total line', () {
      const String text = 'Corner Shop\nBread 120.00\nCake 850.00';
      final ParsedReceipt parsed = parseReceiptText(text);
      expect(parsed.total, 850);
      expect(parsed.merchant, 'Corner Shop');
    });

    test('no amounts gives null total', () {
      final ParsedReceipt parsed = parseReceiptText('Hello\nWorld');
      expect(parsed.total, isNull);
      expect(parsed.merchant, 'Hello');
    });
  });
}
