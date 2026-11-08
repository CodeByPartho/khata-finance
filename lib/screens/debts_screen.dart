import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/debt_entry.dart';
import '../state/finance_provider.dart';
import '../utils/format.dart';

/// Dena Paona: money lent to people and money borrowed from them,
/// with settlements and a copyable per-person statement.
class DebtsScreen extends StatelessWidget {
  const DebtsScreen({super.key});

  Future<void> _recordPayment(
    BuildContext context,
    DebtEntry entry,
  ) async {
    final TextEditingController controller = TextEditingController();
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Record payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '${entry.person} - remaining ${fmtMoney(entry.remaining)}',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Payment amount (taka)',
                  prefixText: '৳ ',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final double? value = double.tryParse(controller.text.trim());
                if (value == null || value <= 0) {
                  Navigator.of(dialogContext).pop(false);
                  return;
                }
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (saved != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    await context
        .read<FinanceProvider>()
        .recordSettlement(entry.id, double.parse(controller.text.trim()));
  }

  Future<void> _copyStatement(BuildContext context, String person) async {
    final String statement =
        context.read<FinanceProvider>().statementFor(person);
    await Clipboard.setData(ClipboardData(text: statement));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Statement copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final FinanceProvider provider = context.watch<FinanceProvider>();
    final ThemeData theme = Theme.of(context);
    final List<DebtEntry> entries = provider.debts;

    return Scaffold(
      appBar: AppBar(title: const Text('Dena Paona')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AddDebtScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add entry'),
      ),
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
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'They owe me',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fmtMoney(provider.totalLentRemaining),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'I owe',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fmtMoney(provider.totalBorrowedRemaining),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFE57373),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No entries yet. Add money you lent to someone or borrowed from someone, and track repayments here.',
                ),
              ),
            )
          else
            ...entries.map((DebtEntry entry) {
              final Color directionColor = entry.iLent
                  ? theme.colorScheme.primary
                  : const Color(0xFFE57373);
              return Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerLow,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: directionColor.withValues(alpha: 0.15),
                    child: Icon(
                      entry.iLent ? Icons.arrow_upward : Icons.arrow_downward,
                      color: directionColor,
                      size: 19,
                    ),
                  ),
                  title: Text(entry.person),
                  subtitle: Text(
                    '${entry.iLent ? 'Lent' : 'Borrowed'} on ${fmtDateShort(entry.date)}'
                    '${entry.note.isNotEmpty ? ' - ${entry.note}' : ''}'
                    '${entry.settled > 0 ? ' - Settled ${fmtMoney(entry.settled)}' : ''}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Text(
                            fmtMoney(entry.remaining),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: directionColor,
                            ),
                          ),
                          Text(
                            entry.isSettled ? 'settled' : 'remaining',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                      PopupMenuButton<String>(
                        onSelected: (String action) {
                          if (action == 'pay') {
                            _recordPayment(context, entry);
                          } else if (action == 'copy') {
                            _copyStatement(context, entry.person);
                          } else if (action == 'delete') {
                            context
                                .read<FinanceProvider>()
                                .deleteDebt(entry.id);
                          }
                        },
                        itemBuilder: (BuildContext context) {
                          return const <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: 'pay',
                              child: Text('Record payment'),
                            ),
                            PopupMenuItem<String>(
                              value: 'copy',
                              child: Text('Copy statement'),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Text('Delete entry'),
                            ),
                          ];
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Form for adding a lent or borrowed entry.
class AddDebtScreen extends StatefulWidget {
  const AddDebtScreen({super.key});

  @override
  State<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends State<AddDebtScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _personController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  bool _iLent = true;
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _personController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
      });
    }
  }

  void _save() {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    final DebtEntry entry = DebtEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      person: _personController.text.trim(),
      amount: double.parse(_amountController.text.trim()),
      iLent: _iLent,
      date: _date,
      note: _noteController.text.trim(),
    );
    context.read<FinanceProvider>().addDebt(entry);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add dena paona entry')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            SegmentedButton<bool>(
              segments: const <ButtonSegment<bool>>[
                ButtonSegment<bool>(
                  value: true,
                  icon: Icon(Icons.arrow_upward),
                  label: Text('I lent'),
                ),
                ButtonSegment<bool>(
                  value: false,
                  icon: Icon(Icons.arrow_downward),
                  label: Text('I borrowed'),
                ),
              ],
              selected: <bool>{_iLent},
              onSelectionChanged: (Set<bool> selection) {
                setState(() {
                  _iLent = selection.first;
                });
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _personController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Person',
                hintText: 'Who is this with?',
                border: OutlineInputBorder(),
              ),
              validator: (String? value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter a name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '৳ ',
                border: OutlineInputBorder(),
              ),
              validator: (String? value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter an amount';
                }
                final double? parsed = double.tryParse(value.trim());
                if (parsed == null || parsed <= 0) {
                  return 'Amount must be more than 0';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Date'),
                subtitle: Text(fmtDate(_date)),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickDate,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('Save entry'),
            ),
          ],
        ),
      ),
    );
  }
}
