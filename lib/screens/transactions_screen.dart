import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart';
import '../state/finance_provider.dart';
import '../utils/format.dart';
import 'home_screen.dart';

enum _TxnFilter { all, income, expense }

/// Full transaction list, grouped by day, with search, type filter
/// and swipe to delete.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  _TxnFilter _filter = _TxnFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(Txn txn) {
    if (_filter == _TxnFilter.income && !txn.isIncome) {
      return false;
    }
    if (_filter == _TxnFilter.expense && txn.isIncome) {
      return false;
    }
    if (_query.isEmpty) {
      return true;
    }
    final String q = _query.toLowerCase();
    return txn.note.toLowerCase().contains(q) ||
        txn.category.toLowerCase().contains(q) ||
        txn.tag.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final FinanceProvider provider = context.watch<FinanceProvider>();
    final ThemeData theme = Theme.of(context);
    final List<Txn> filtered = provider.txns.where(_matches).toList();

    double filteredNet = 0;
    for (final Txn txn in filtered) {
      filteredNet += txn.isIncome ? txn.amount : -txn.amount;
    }

    final Map<DateTime, List<Txn>> byDay = <DateTime, List<Txn>>{};
    for (final Txn txn in filtered) {
      final DateTime day =
          DateTime(txn.date.year, txn.date.month, txn.date.day);
      byDay.putIfAbsent(day, () => <Txn>[]).add(txn);
    }
    final List<DateTime> days = byDay.keys.toList()
      ..sort((DateTime a, DateTime b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(title: const Text('All transactions')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search note, category or tag',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _query = '';
                          });
                        },
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (String value) {
                setState(() {
                  _query = value.trim();
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
            child: Row(
              children: <Widget>[
                ChoiceChip(
                  label: const Text('All'),
                  selected: _filter == _TxnFilter.all,
                  onSelected: (_) {
                    setState(() {
                      _filter = _TxnFilter.all;
                    });
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Income'),
                  selected: _filter == _TxnFilter.income,
                  onSelected: (_) {
                    setState(() {
                      _filter = _TxnFilter.income;
                    });
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Expense'),
                  selected: _filter == _TxnFilter.expense,
                  onSelected: (_) {
                    setState(() {
                      _filter = _TxnFilter.expense;
                    });
                  },
                ),
                const Spacer(),
                Text(
                  '${filtered.length} results',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Filtered total',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  fmtMoney(filteredNet),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: filteredNet < 0
                        ? const Color(0xFFE57373)
                        : theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: !provider.isLoaded
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No transactions match. Try a different search or filter.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: days.length,
                        itemBuilder: (BuildContext context, int index) {
                          final DateTime day = days[index];
                          final List<Txn> dayTxns = byDay[day]!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 14,
                                  bottom: 8,
                                ),
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
                                          title:
                                              const Text('Delete transaction?'),
                                          content: Text(
                                            'Remove "${txn.note.isNotEmpty ? txn.note : txn.category}" (${fmtMoney(txn.amount)})? This cannot be undone.',
                                          ),
                                          actions: <Widget>[
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(dialogContext)
                                                      .pop(false),
                                              child: const Text('Cancel'),
                                            ),
                                            FilledButton(
                                              onPressed: () =>
                                                  Navigator.of(dialogContext)
                                                      .pop(true),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                    return ok ?? false;
                                  },
                                  onDismissed: (_) {
                                    context
                                        .read<FinanceProvider>()
                                        .deleteTxn(txn.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Transaction deleted'),
                                      ),
                                    );
                                  },
                                  child: TxnRow(txn: txn),
                                );
                              }),
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
