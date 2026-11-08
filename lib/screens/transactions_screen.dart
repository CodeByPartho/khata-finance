import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart';
import '../state/finance_provider.dart';
import '../utils/format.dart';
import 'home_screen.dart';

/// Full transaction list, grouped by day, with swipe to delete.
class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FinanceProvider provider = context.watch<FinanceProvider>();
    final ThemeData theme = Theme.of(context);
    final List<Txn> all = provider.txns;

    if (provider.isLoaded && all.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('All transactions')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No transactions yet. Tap Add to record your first income or expense.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final Map<DateTime, List<Txn>> byDay = <DateTime, List<Txn>>{};
    for (final Txn txn in all) {
      final DateTime day =
          DateTime(txn.date.year, txn.date.month, txn.date.day);
      byDay.putIfAbsent(day, () => <Txn>[]).add(txn);
    }
    final List<DateTime> days = byDay.keys.toList()
      ..sort((DateTime a, DateTime b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(title: const Text('All transactions')),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: days.length,
        itemBuilder: (BuildContext context, int index) {
          final DateTime day = days[index];
          final List<Txn> dayTxns = byDay[day]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 8),
                child: Text(
                  fmtDayHeader(day),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ...dayTxns.map((Txn txn) {
                return Dismissible(
                  key: ValueKey<String>(txn.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5A1D20),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFFFAB91),
                    ),
                  ),
                  confirmDismiss: (_) async {
                    final bool? ok = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext dialogContext) {
                        return AlertDialog(
                          title: const Text('Delete transaction?'),
                          content: Text(
                            'Remove "${txn.note.isNotEmpty ? txn.note : txn.category}" (${fmtMoney(txn.amount)})? This cannot be undone.',
                          ),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(true),
                              child: const Text('Delete'),
                            ),
                          ],
                        );
                      },
                    );
                    return ok ?? false;
                  },
                  onDismissed: (_) {
                    context.read<FinanceProvider>().deleteTxn(txn.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Transaction deleted')),
                    );
                  },
                  child: TxnRow(txn: txn),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
