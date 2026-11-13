import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/goal.dart';
import '../state/finance_provider.dart';
import '../utils/format.dart';
import 'budgets_screen.dart';
import 'debt_planner_screen.dart';

/// Plan tab: savings goals on top, monthly budgets below.
class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: const <Widget>[
          GoalsBody(),
          SizedBox(height: 24),
          BudgetsBody(),
          SizedBox(height: 24),
          DebtPlannerBody(),
        ],
      ),
    );
  }
}

/// Savings goals list with progress, an add goal button, and a tap
/// to add or remove savings dialog.
class GoalsBody extends StatelessWidget {
  const GoalsBody({super.key});

  Future<void> _addGoalDialog(BuildContext context) async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController targetController = TextEditingController();
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('New savings goal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Goal name',
                  hintText: 'For example: New phone',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: targetController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Target amount (taka)',
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
                final double? target =
                    double.tryParse(targetController.text.trim());
                if (nameController.text.trim().isEmpty ||
                    target == null ||
                    target <= 0) {
                  Navigator.of(dialogContext).pop(false);
                  return;
                }
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Create'),
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
    final Goal goal = Goal(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: nameController.text.trim(),
      target: double.parse(targetController.text.trim()),
    );
    await context.read<FinanceProvider>().addGoal(goal);
  }

  Future<void> _adjustSavingsDialog(
    BuildContext context,
    Goal goal,
  ) async {
    final TextEditingController controller = TextEditingController();
    final int? direction = await showDialog<int>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(goal.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Saved ${fmtMoney(goal.saved)} of ${fmtMoney(goal.target)}',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount (taka)',
                  prefixText: '৳ ',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(-1),
              child: const Text('Remove'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(1),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    if (direction == null) {
      return;
    }
    final double? amount = double.tryParse(controller.text.trim());
    if (amount == null || amount <= 0) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    await context
        .read<FinanceProvider>()
        .addToGoal(goal.id, amount * direction);
  }

  @override
  Widget build(BuildContext context) {
    final FinanceProvider provider = context.watch<FinanceProvider>();
    final ThemeData theme = Theme.of(context);
    final List<Goal> goals = provider.goals;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Savings goals',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _addGoalDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New goal'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (goals.isEmpty)
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No goals yet. Create one, for example an emergency fund or a new phone, and add savings as you go.',
              ),
            ),
          )
        else
          ...goals.map((Goal goal) {
            final int percent = (goal.progress * 100).round();
            return Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _adjustSavingsDialog(context, goal),
                onLongPress: () async {
                  final bool? ok = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      return AlertDialog(
                        title: const Text('Delete goal?'),
                        content: Text('Remove "${goal.name}"?'),
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
                  if (ok == true && context.mounted) {
                    await context.read<FinanceProvider>().deleteGoal(goal.id);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: theme.colorScheme.primary
                                .withValues(alpha: 0.15),
                            child: Icon(
                              Icons.flag_outlined,
                              color: theme.colorScheme.primary,
                              size: 19,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              goal.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '$percent%',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: goal.progress,
                          minHeight: 8,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${fmtMoney(goal.saved)} saved of ${fmtMoney(goal.target)}. Tap to add or remove savings, long press to delete.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.6),
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
