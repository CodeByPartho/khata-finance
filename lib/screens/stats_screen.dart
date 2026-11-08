import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/categories.dart';
import '../state/finance_provider.dart';
import '../utils/format.dart';
import '../widgets/monthly_bar_chart.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FinanceProvider provider = context.watch<FinanceProvider>();
    final ThemeData theme = Theme.of(context);
    final DateTime now = DateTime.now();

    final double income = provider.incomeForMonth(now);
    final double expense = provider.expenseForMonth(now);
    final double net = income - expense;
    final Map<String, double> byCategory = provider.expenseByCategory(now);
    final List<MapEntry<String, double>> sorted = byCategory.entries.toList()
      ..sort(
        (MapEntry<String, double> a, MapEntry<String, double> b) =>
            b.value.compareTo(a.value),
      );

    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: <Widget>[
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Net worth',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    fmtMoney(provider.netWorth),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: provider.netWorth < 0
                          ? const Color(0xFFE57373)
                          : theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SummaryRow(
                    label: 'In accounts',
                    value: fmtMoney(provider.totalBalance),
                    color: theme.colorScheme.primary,
                  ),
                  const Divider(height: 18),
                  _SummaryRow(
                    label: 'They owe me',
                    value: fmtMoney(provider.totalLentRemaining),
                    color: theme.colorScheme.primary,
                  ),
                  const Divider(height: 18),
                  _SummaryRow(
                    label: 'I owe',
                    value: fmtMoney(provider.totalBorrowedRemaining),
                    color: const Color(0xFFE57373),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            fmtMonthYear(now),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: <Widget>[
                  _SummaryRow(
                    label: 'Income',
                    value: fmtMoney(income),
                    color: theme.colorScheme.primary,
                  ),
                  const Divider(height: 20),
                  _SummaryRow(
                    label: 'Expense',
                    value: fmtMoney(expense),
                    color: const Color(0xFFE57373),
                  ),
                  const Divider(height: 20),
                  _SummaryRow(
                    label: 'Net',
                    value: fmtMoney(net),
                    color: net < 0
                        ? const Color(0xFFE57373)
                        : theme.colorScheme.primary,
                    bold: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Spending by category',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          if (sorted.isEmpty)
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: Text('No expenses recorded this month.'),
              ),
            )
          else
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: <Widget>[
                    for (int i = 0; i < sorted.length; i++) ...<Widget>[
                      _CategoryShareRow(
                        name: sorted[i].key,
                        total: sorted[i].value,
                        totalExpense: expense,
                      ),
                      if (i < sorted.length - 1) const SizedBox(height: 14),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 22),
          Text(
            'Expenses, last 6 months',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: MonthlyBarChart(data: provider.monthlyExpenses()),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Income vs expense, last 6 months',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: IncomeExpenseChart(
                data: provider.monthlyIncomeVsExpense(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(label, style: theme.textTheme.bodyLarge),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CategoryShareRow extends StatelessWidget {
  final String name;
  final double total;
  final double totalExpense;

  const _CategoryShareRow({
    required this.name,
    required this.total,
    required this.totalExpense,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CategoryInfo info = categoryByName(name, isIncome: false);
    final double share = totalExpense <= 0 ? 0 : total / totalExpense;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(info.icon, size: 18, color: info.color),
            const SizedBox(width: 8),
            Expanded(child: Text(name, style: theme.textTheme.bodyLarge)),
            Text(
              fmtMoney(total),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(share * 100).round()}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: share.clamp(0, 1).toDouble(),
            minHeight: 7,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(info.color),
          ),
        ),
      ],
    );
  }
}
