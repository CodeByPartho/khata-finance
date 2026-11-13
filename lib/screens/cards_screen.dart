import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../models/payment_card.dart';
import '../state/finance_provider.dart';
import '../utils/format.dart';

/// Cards and billing cycles: add a bank or credit card with a cycle
/// start day and a due day, and see current cycle spend, days left
/// in the cycle, and the due date.
class CardsScreen extends StatelessWidget {
  const CardsScreen({super.key});

  Future<void> _addCardDialog(BuildContext context) async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController startController =
        TextEditingController(text: '1');
    final TextEditingController dueController =
        TextEditingController(text: '15');
    bool isCredit = true;
    String accountId = '';
    final FinanceProvider provider = context.read<FinanceProvider>();
    final List<Account> accounts = provider.accounts;
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Add card'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Card name',
                        hintText: 'For example: City Bank Visa',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<bool>(
                      segments: const <ButtonSegment<bool>>[
                        ButtonSegment<bool>(
                          value: true,
                          label: Text('Credit card'),
                        ),
                        ButtonSegment<bool>(
                          value: false,
                          label: Text('Bank card'),
                        ),
                      ],
                      selected: <bool>{isCredit},
                      onSelectionChanged: (Set<bool> selection) {
                        setDialogState(() {
                          isCredit = selection.first;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: startController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Billing cycle start day (1-31)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: dueController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Due day (1-31)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: '',
                      decoration: const InputDecoration(
                        labelText: 'Linked account (optional)',
                        border: OutlineInputBorder(),
                      ),
                      items: <DropdownMenuItem<String>>[
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('All accounts'),
                        ),
                        ...accounts.map(
                          (Account a) => DropdownMenuItem<String>(
                            value: a.id,
                            child: Text(a.name),
                          ),
                        ),
                      ],
                      onChanged: (String? value) {
                        setDialogState(() {
                          accountId = value ?? '';
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final int? start =
                        int.tryParse(startController.text.trim());
                    final int? due = int.tryParse(dueController.text.trim());
                    if (nameController.text.trim().isEmpty ||
                        start == null ||
                        start < 1 ||
                        start > 31 ||
                        due == null ||
                        due < 1 ||
                        due > 31) {
                      Navigator.of(dialogContext).pop(false);
                      return;
                    }
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
    if (saved != true || !context.mounted) {
      return;
    }
    final PaymentCard card = PaymentCard(
      id: 'card-${DateTime.now().microsecondsSinceEpoch}',
      name: nameController.text.trim(),
      isCredit: isCredit,
      billingStartDay: int.parse(startController.text.trim()),
      dueDay: int.parse(dueController.text.trim()),
      accountId: accountId,
    );
    await context.read<FinanceProvider>().addCard(card);
  }

  @override
  Widget build(BuildContext context) {
    final FinanceProvider provider = context.watch<FinanceProvider>();
    final ThemeData theme = Theme.of(context);
    final DateTime now = DateTime.now();
    final List<PaymentCard> cards = provider.cards;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cards and billing cycles'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add card',
            onPressed: () => _addCardDialog(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          if (cards.isEmpty)
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No cards yet. Add a bank or credit card with its billing cycle start day and due day to track cycle spend and the next due date.',
                ),
              ),
            )
          else
            ...cards.map((PaymentCard card) {
              final double spend =
                  provider.cardCycleSpend(card, now: now);
              final int daysLeft = card.cycle.daysLeftInCycle(now);
              final DateTime due = card.cycle.dueDate(now);
              final int daysUntilDue = card.cycle.daysUntilDue(now);
              final String dueLine = daysUntilDue < 0
                  ? 'Due date passed ${-daysUntilDue} days ago'
                  : daysUntilDue == 0
                      ? 'Payment due today'
                      : 'Payment due in $daysUntilDue days';
              return Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerLow,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          CircleAvatar(
                            backgroundColor: theme.colorScheme.primary
                                .withValues(alpha: 0.15),
                            child: Icon(
                              Icons.credit_card,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  card.name,
                                  style: theme.textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  card.isCredit ? 'Credit card' : 'Bank card',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () {
                              context
                                  .read<FinanceProvider>()
                                  .deleteCard(card.id);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          const Text('Spent this cycle'),
                          Text(
                            fmtMoney(spend),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          const Text('Days left in cycle'),
                          Text(
                            '$daysLeft',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          const Text('Due date'),
                          Text(
                            fmtDate(due),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        dueLine,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: daysUntilDue <= 3
                              ? const Color(0xFFE57373)
                              : theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
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
