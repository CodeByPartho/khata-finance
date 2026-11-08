import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/categories.dart';
import '../models/transaction.dart';
import '../state/finance_provider.dart';
import '../utils/format.dart';
import 'transactions_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FinanceProvider provider = context.watch<FinanceProvider>();
    final ThemeData theme = Theme.of(context);
    final DateTime now = DateTime.now();
    final double income = provider.incomeForMonth(now);
    final double expense = provider.expenseForMonth(now);
    final List<Txn> recent = provider.txns.take(8).toList();

    final List<String> alerts = <String>[];
    for (final CategoryInfo info in expenseCategories) {
      final double progress = provider.budgetProgress(info.name, now);
      if (provider.budgetFor(info.name) > 0 && progress >= 0.9) {
        alerts.add('${info.name} at ${(progress * 100).round()}%');
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Khata'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: <Widget>[
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Total balance',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    fmtMoney(provider.balance),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: provider.balance < 0
                          ? const Color(0xFFE57373)
                          : theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fmtMonthYear(now),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _SummaryColumn(
                          label: 'Income',
                          value: fmtMoney(income),
                          icon: Icons.arrow_downward,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Expanded(
                        child: _SummaryColumn(
                          label: 'Expense',
                          value: fmtMoney(expense),
                          icon: Icons.arrow_upward,
                          color: const Color(0xFFE57373),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (alerts.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              color: const Color(0xFF3A1518),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFFFAB91),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Budget alert: ${alerts.take(2).join(', ')} of the monthly budget.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFFFCCBC),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Recent transactions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TransactionsScreen(),
                    ),
                  );
                },
                child: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (!provider.isLoaded)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (recent.isEmpty)
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No transactions yet. Tap Add to record your first income or expense.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...recent.map((Txn txn) => TxnRow(txn: txn)),
        ],
      ),
    );
  }
}

class _SummaryColumn extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryColumn({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        CircleAvatar(
          radius: 16,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One transaction row, shared by Home and the full list screen.
class TxnRow extends StatelessWidget {
  final Txn txn;

  const TxnRow({super.key, required this.txn});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CategoryInfo info =
        categoryByName(txn.category, isIncome: txn.isIncome);
    final Color amountColor =
        txn.isIncome ? theme.colorScheme.primary : const Color(0xFFE57373);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: info.color.withValues(alpha: 0.16),
          child: Icon(info.icon, color: info.color, size: 20),
        ),
        title: Text(
          txn.note.isNotEmpty ? txn.note : txn.category,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('${txn.category} - ${fmtDateShort(txn.date)}'),
        trailing: Text(
          fmtMoneySigned(txn.amount, isIncome: txn.isIncome),
          style: theme.textTheme.titleSmall?.copyWith(
            color: amountColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
