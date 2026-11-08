import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/categories.dart';
import '../state/finance_provider.dart';
import '../utils/format.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: const <Widget>[BudgetsBody()],
      ),
    );
  }
}

/// The budgets list content, without a Scaffold, so it can be
/// embedded inside the Plan tab as well as shown on its own screen.
class BudgetsBody extends StatelessWidget {
  const BudgetsBody({super.key});

  Future<void> _editBudget(
    BuildContext context,
    CategoryInfo info,
    double current,
  ) async {
    final TextEditingController controller = TextEditingController(
      text: current > 0 ? current.round().toString() : '',
    );
    final double? result = await showDialog<double>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('${info.name} budget'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Monthly budget (taka)',
              prefixText: '৳ ',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final double? value = double.tryParse(controller.text.trim());
                if (value == null || value < 0) {
                  Navigator.of(dialogContext).pop();
                  return;
                }
                Navigator.of(dialogContext).pop(value);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (result == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    await context.read<FinanceProvider>().setBudget(info.name, result);
  }

  @override
  Widget build(BuildContext context) {
    final FinanceProvider provider = context.watch<FinanceProvider>();
    final ThemeData theme = Theme.of(context);
    final DateTime now = DateTime.now();
    final Map<String, double> spentByCategory = provider.expenseByCategory(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Monthly budgets - ${fmtMonthYear(now)}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tap a category to set or change its budget.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 12),
        ...expenseCategories.map((CategoryInfo info) {
          final double budget = provider.budgetFor(info.name);
          final double spent = spentByCategory[info.name] ?? 0;
          final double progress = provider.budgetProgress(info.name, now);
          final bool over = budget > 0 && spent > budget;
          final Color barColor =
              over ? const Color(0xFFE57373) : theme.colorScheme.primary;
          return Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _editBudget(context, info, budget),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: info.color.withValues(alpha: 0.16),
                          child: Icon(
                            info.icon,
                            color: info.color,
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            info.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          budget > 0 ? fmtMoney(budget) : 'Not set',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const Icon(Icons.edit_outlined, size: 16),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0, 1).toDouble(),
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      budget <= 0
                          ? 'Spent ${fmtMoney(spent)} this month. Tap to set a budget.'
                          : over
                              ? 'Spent ${fmtMoney(spent)} of ${fmtMoney(budget)}. Over budget by ${fmtMoney(spent - budget)}.'
                              : 'Spent ${fmtMoney(spent)} of ${fmtMoney(budget)}.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: over
                            ? const Color(0xFFE57373)
                            : Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
