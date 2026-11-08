import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../models/transfer.dart';
import '../state/finance_provider.dart';
import '../utils/format.dart';

/// Accounts list with balances, add account, and transfers between
/// accounts (with fee support for MFS cash out style charges).
class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  Future<void> _addAccountDialog(BuildContext context) async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController openingController = TextEditingController();
    AccountKind kind = AccountKind.cash;
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Add account'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Account name',
                      hintText: 'For example: City Bank',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<AccountKind>(
                    initialValue: kind,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                    items: AccountKind.values
                        .map((AccountKind k) => DropdownMenuItem<AccountKind>(
                              value: k,
                              child: Text(k.label),
                            ))
                        .toList(),
                    onChanged: (AccountKind? value) {
                      if (value != null) {
                        setDialogState(() {
                          kind = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: openingController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Opening balance (taka)',
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
                    if (nameController.text.trim().isEmpty) {
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
    if (saved != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    final Account account = Account(
      id: 'acc-${DateTime.now().microsecondsSinceEpoch}',
      name: nameController.text.trim(),
      kind: kind,
      openingBalance: double.tryParse(openingController.text.trim()) ?? 0,
    );
    await context.read<FinanceProvider>().addAccount(account);
  }

  @override
  Widget build(BuildContext context) {
    final FinanceProvider provider = context.watch<FinanceProvider>();
    final ThemeData theme = Theme.of(context);
    final bool hidden = provider.hideAmounts;

    String money(double value) => hidden ? '••••' : fmtMoney(value);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add account',
            onPressed: () => _addAccountDialog(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
                  const Text('Total across accounts'),
                  Text(
                    money(provider.totalBalance),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...provider.accounts.map((Account account) {
            final double balance = provider.accountBalance(account.id);
            return Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      theme.colorScheme.primary.withValues(alpha: 0.15),
                  child: Icon(
                    account.kind.icon,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                title: Text(account.name),
                subtitle: Text(account.kind.label),
                trailing: Text(
                  money(balance),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: balance < 0
                        ? const Color(0xFFE57373)
                        : theme.colorScheme.primary,
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const TransferFormScreen(),
                ),
              );
            },
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Transfer between accounts'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Transfer history',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (provider.transfers.isEmpty)
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No transfers yet.'),
              ),
            )
          else
            ...provider.transfers.map((Transfer transfer) {
              return Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerLow,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.swap_horiz, size: 18),
                  ),
                  title: Text(
                    '${provider.accountName(transfer.fromAccountId)} to ${provider.accountName(transfer.toAccountId)}',
                  ),
                  subtitle: Text(
                    '${fmtDateShort(transfer.date)}'
                    '${transfer.fee > 0 ? ' - Fee ${fmtMoney(transfer.fee)}' : ''}'
                    '${transfer.note.isNotEmpty ? ' - ${transfer.note}' : ''}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        money(transfer.amount),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 19),
                        onPressed: () {
                          context
                              .read<FinanceProvider>()
                              .deleteTransfer(transfer.id);
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

/// Form for moving money between two accounts, with an optional fee.
class TransferFormScreen extends StatefulWidget {
  const TransferFormScreen({super.key});

  @override
  State<TransferFormScreen> createState() => _TransferFormScreenState();
}

class _TransferFormScreenState extends State<TransferFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _feeController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String? _fromId;
  String? _toId;

  @override
  void dispose() {
    _amountController.dispose();
    _feeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    if (_fromId == null || _toId == null || _fromId == _toId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick two different accounts to transfer between.'),
        ),
      );
      return;
    }
    final Transfer transfer = Transfer(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      fromAccountId: _fromId!,
      toAccountId: _toId!,
      amount: double.parse(_amountController.text.trim()),
      fee: double.tryParse(_feeController.text.trim()) ?? 0,
      date: DateTime.now(),
      note: _noteController.text.trim(),
    );
    context.read<FinanceProvider>().addTransfer(transfer);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final FinanceProvider provider = context.watch<FinanceProvider>();
    final List<Account> accounts = provider.accounts;
    _fromId ??= accounts.isNotEmpty ? accounts.first.id : null;
    if (_toId == null && accounts.length > 1) {
      _toId = accounts[1].id;
    }

    DropdownMenuItem<String> item(Account account) {
      return DropdownMenuItem<String>(
        value: account.id,
        child: Text(account.name),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Transfer')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            DropdownButtonFormField<String>(
              initialValue: _fromId,
              decoration: const InputDecoration(
                labelText: 'From account',
                border: OutlineInputBorder(),
              ),
              items: accounts.map(item).toList(),
              onChanged: (String? value) {
                setState(() {
                  _fromId = value;
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _toId,
              decoration: const InputDecoration(
                labelText: 'To account',
                border: OutlineInputBorder(),
              ),
              items: accounts.map(item).toList(),
              onChanged: (String? value) {
                setState(() {
                  _toId = value;
                });
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
            TextFormField(
              controller: _feeController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Fee (for example MFS cash out fee)',
                prefixText: '৳ ',
                border: OutlineInputBorder(),
              ),
              validator: (String? value) {
                if (value == null || value.trim().isEmpty) {
                  return null;
                }
                final double? parsed = double.tryParse(value.trim());
                if (parsed == null || parsed < 0) {
                  return 'Fee cannot be negative';
                }
                return null;
              },
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
              child: const Text('Save transfer'),
            ),
          ],
        ),
      ),
    );
  }
}
