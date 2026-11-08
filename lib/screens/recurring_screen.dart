import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../models/categories.dart';
import '../models/recurring_rule.dart';
import '../state/finance_provider.dart';
import '../utils/format.dart';

/// Recurring entries, subscriptions total and upcoming bills.
class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FinanceProvider provider = context.watch<FinanceProvider>();
    final ThemeData theme = Theme.of(context);
    final List<RecurringRule> rules = provider.rules;
    final List<({RecurringRule rule, DateTime date})> upcoming =
        provider.upcomingBills(30);

    return Scaffold(
      appBar: AppBar(title: const Text('Recurring and Bills')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AddRecurringScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add rule'),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Subscriptions',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${provider.subscriptionRules.length} active',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        fmtMoney(provider.totalMonthlySubscriptionCost),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        'per month',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Rules',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (rules.isEmpty)
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No recurring rules yet. Add rent, salary, internet bill or a subscription and Khata will post it on schedule.',
                ),
              ),
            )
          else
            ...rules.map((RecurringRule rule) {
              final CategoryInfo info =
                  categoryByName(rule.category, isIncome: rule.isIncome);
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
                    child: Icon(info.icon, color: info.color, size: 19),
                  ),
                  title: Text(
                    rule.note.isNotEmpty ? rule.note : rule.category,
                  ),
                  subtitle: Text(
                    '${rule.frequency.label} - Next: ${fmtDate(rule.nextDue)} - ${provider.accountName(rule.accountId)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        fmtMoneySigned(rule.amount, isIncome: rule.isIncome),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: rule.isIncome
                              ? theme.colorScheme.primary
                              : const Color(0xFFE57373),
                        ),
                      ),
                      Switch(
                        value: rule.active,
                        onChanged: (bool value) {
                          context
                              .read<FinanceProvider>()
                              .setRuleActive(rule.id, value);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 19),
                        onPressed: () {
                          context.read<FinanceProvider>().deleteRule(rule.id);
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 20),
          Text(
            'Upcoming bills, next 30 days',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (upcoming.isEmpty)
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Nothing due in the next 30 days.'),
              ),
            )
          else
            ...upcoming.map((({RecurringRule rule, DateTime date}) item) {
              final CategoryInfo info = categoryByName(
                item.rule.category,
                isIncome: item.rule.isIncome,
              );
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
                    child: Icon(info.icon, color: info.color, size: 19),
                  ),
                  title: Text(
                    item.rule.note.isNotEmpty
                        ? item.rule.note
                        : item.rule.category,
                  ),
                  subtitle: Text(fmtDate(item.date)),
                  trailing: Text(
                    fmtMoney(item.rule.amount),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Form for creating a recurring rule.
class AddRecurringScreen extends StatefulWidget {
  const AddRecurringScreen({super.key});

  @override
  State<AddRecurringScreen> createState() => _AddRecurringScreenState();
}

class _AddRecurringScreenState extends State<AddRecurringScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  bool _isIncome = false;
  String _category = expenseCategories.first.name;
  String? _accountId;
  RecurringFrequency _frequency = RecurringFrequency.monthly;
  DateTime _nextDue = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  List<CategoryInfo> get _currentCategories =>
      _isIncome ? incomeCategories : expenseCategories;

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _nextDue,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      setState(() {
        _nextDue = picked;
      });
    }
  }

  void _save() {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    final RecurringRule rule = RecurringRule(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      amount: double.parse(_amountController.text.trim()),
      isIncome: _isIncome,
      category: _category,
      accountId: _accountId ?? 'cash',
      note: _noteController.text.trim(),
      frequency: _frequency,
      nextDue: _nextDue,
    );
    context.read<FinanceProvider>().addRule(rule);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final FinanceProvider provider = context.watch<FinanceProvider>();
    final List<Account> accounts = provider.accounts;
    _accountId ??= accounts.isNotEmpty ? accounts.first.id : 'cash';

    return Scaffold(
      appBar: AppBar(title: const Text('Add recurring rule')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            SegmentedButton<bool>(
              segments: const <ButtonSegment<bool>>[
                ButtonSegment<bool>(
                  value: false,
                  icon: Icon(Icons.arrow_upward),
                  label: Text('Expense'),
                ),
                ButtonSegment<bool>(
                  value: true,
                  icon: Icon(Icons.arrow_downward),
                  label: Text('Income'),
                ),
              ],
              selected: <bool>{_isIncome},
              onSelectionChanged: (Set<bool> selection) {
                setState(() {
                  _isIncome = selection.first;
                  _category = _currentCategories.first.name;
                });
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
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
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _currentCategories.map((CategoryInfo info) {
                final bool selected = info.name == _category;
                return ChoiceChip(
                  label: Text(info.name),
                  avatar: Icon(
                    info.icon,
                    size: 16,
                    color: selected ? null : info.color,
                  ),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _category = info.name;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _accountId,
              decoration: const InputDecoration(
                labelText: 'Account',
                border: OutlineInputBorder(),
              ),
              items: accounts
                  .map((Account a) => DropdownMenuItem<String>(
                        value: a.id,
                        child: Text(a.name),
                      ))
                  .toList(),
              onChanged: (String? value) {
                setState(() {
                  _accountId = value;
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<RecurringFrequency>(
              initialValue: _frequency,
              decoration: const InputDecoration(
                labelText: 'Frequency',
                border: OutlineInputBorder(),
              ),
              items: RecurringFrequency.values
                  .map((RecurringFrequency f) =>
                      DropdownMenuItem<RecurringFrequency>(
                        value: f,
                        child: Text(f.label),
                      ))
                  .toList(),
              onChanged: (RecurringFrequency? value) {
                if (value != null) {
                  setState(() {
                    _frequency = value;
                  });
                }
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
                leading: const Icon(Icons.event_outlined),
                title: const Text('First due date'),
                subtitle: Text(fmtDate(_nextDue)),
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
                hintText: 'For example: House rent',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('Save rule'),
            ),
          ],
        ),
      ),
    );
  }
}
