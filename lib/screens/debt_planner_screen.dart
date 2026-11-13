import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/debt_planner.dart';
import '../models/debt_entry.dart';
import '../state/finance_provider.dart';
import '../utils/format.dart';

/// Debt payoff planner section on the Plan tab. It plans only money
/// the user owes (borrowed entries with a remaining balance). The
/// user picks Avalanche or Snowball and a monthly extra payment, and
/// sees the payoff order, months to debt free, and interest saved
/// compared with paying only the minimums.
class DebtPlannerBody extends StatefulWidget {
  const DebtPlannerBody({super.key});

  @override
  State<DebtPlannerBody> createState() => _DebtPlannerBodyState();
}

class _DebtPlannerBodyState extends State<DebtPlannerBody> {
  PayoffStrategy _strategy = PayoffStrategy.avalanche;
  final TextEditingController _extraController = TextEditingController();
  PayoffPlan? _plan;
  String? _error;

  @override
  void dispose() {
    _extraController.dispose();
    super.dispose();
  }

  PlannerDebt _toPlannerDebt(DebtEntry entry) {
    final double balance = entry.remaining;
    final double minPayment = entry.minPayment > 0
        ? entry.minPayment
        : balance * 0.05;
    return PlannerDebt(
      id: entry.id,
      name: entry.person,
      balance: balance,
      annualRatePercent: entry.annualRatePercent,
      minPayment: minPayment,
    );
  }

  void _compute(List<DebtEntry> owed) {
    final double extra = double.tryParse(_extraController.text.trim()) ?? 0;
    final List<PlannerDebt> debts =
        owed.map(_toPlannerDebt).toList();
    final PayoffPlan? plan = planDebts(debts, _strategy, extra);
    setState(() {
      _plan = plan;
      _error = plan == null
          ? 'The minimum payments do not cover the interest, so these debts never clear. Raise the monthly payment.'
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final FinanceProvider provider = context.watch<FinanceProvider>();
    final ThemeData theme = Theme.of(context);
    final List<DebtEntry> owed = provider.debts
        .where((DebtEntry d) => !d.iLent && d.remaining > 0)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Debt payoff planner',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        if (owed.isEmpty)
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No money owed right now. Add a borrowed entry in Dena Paona to plan its payoff here.',
              ),
            ),
          )
        else ...<Widget>[
          Text(
            'Plans money you owe, in payoff order. Debts without a minimum payment use 5 percent of the balance as the assumed minimum.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<PayoffStrategy>(
            segments: const <ButtonSegment<PayoffStrategy>>[
              ButtonSegment<PayoffStrategy>(
                value: PayoffStrategy.avalanche,
                label: Text('Avalanche'),
              ),
              ButtonSegment<PayoffStrategy>(
                value: PayoffStrategy.snowball,
                label: Text('Snowball'),
              ),
            ],
            selected: <PayoffStrategy>{_strategy},
            onSelectionChanged: (Set<PayoffStrategy> selection) {
              setState(() {
                _strategy = selection.first;
                _plan = null;
                _error = null;
              });
            },
          ),
          const SizedBox(height: 8),
          Text(
            _strategy == PayoffStrategy.avalanche
                ? 'Avalanche pays the highest interest rate first.'
                : 'Snowball pays the smallest balance first.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _extraController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Extra payment per month (taka)',
              prefixText: '৳ ',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) {
              setState(() {
                _plan = null;
                _error = null;
              });
            },
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _compute(owed),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Show payoff plan'),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFE57373),
              ),
            ),
          ],
          if (_plan != null) ...<Widget>[
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Debt free in ${_plan!.totalMonths} months',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Total interest ${fmtMoney(_plan!.totalInterest)}. Extra payments save ${fmtMoney(_plan!.interestSaved)} compared with minimum payments only.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            ..._plan!.steps.map((PayoffStep step) {
              return Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerLow,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary
                        .withValues(alpha: 0.15),
                    child: Text(
                      '${step.order}',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(step.debt.name),
                  subtitle: Text(
                    '${fmtMoney(step.debt.balance)} at ${step.debt.annualRatePercent.toStringAsFixed(1)}% per year',
                  ),
                  trailing: Text(
                    '${step.monthsToClear} mo',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ],
    );
  }
}
