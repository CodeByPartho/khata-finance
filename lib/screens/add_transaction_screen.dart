import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/bangla_parser.dart';
import '../logic/receipt_parser.dart';
import '../models/account.dart';
import '../models/categories.dart';
import '../models/transaction.dart';
import '../state/finance_provider.dart';
import '../utils/format.dart';
import '../utils/receipt_scan.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _quickAddController = TextEditingController();

  ParsedQuickEntry? _quickPreview;
  String? _quickError;
  bool _scanning = false;

  bool _isIncome = false;
  String _category = expenseCategories.first.name;
  String? _accountId;
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _tagController.dispose();
    _quickAddController.dispose();
    super.dispose();
  }

  void _parseQuickAdd() {
    final ParsedQuickEntry? parsed =
        parseQuickEntry(_quickAddController.text);
    setState(() {
      _quickPreview = parsed;
      _quickError = parsed == null
          ? 'Type a note and an amount, for example: bazar 500'
          : null;
    });
  }

  void _useQuickPreview() {
    final ParsedQuickEntry? preview = _quickPreview;
    if (preview == null) {
      return;
    }
    setState(() {
      _isIncome = preview.isIncome;
      _category = preview.category;
      _amountController.text = preview.amount.toStringAsFixed(
        preview.amount.truncateToDouble() == preview.amount ? 0 : 2,
      );
      _noteController.text = preview.note;
      _quickPreview = null;
      _quickAddController.clear();
    });
  }

  Future<void> _scanReceipt() async {
    setState(() {
      _scanning = true;
    });
    final String? text = await scanReceipt();
    if (!mounted) {
      return;
    }
    setState(() {
      _scanning = false;
    });
    if (text == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No text found on the receipt. Try again.'),
        ),
      );
      return;
    }
    final ParsedReceipt parsed = parseReceiptText(text);
    if (parsed.total == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No total amount found on the receipt.'),
        ),
      );
      return;
    }
    setState(() {
      _isIncome = false;
      _category = 'Shopping';
      _amountController.text = parsed.total!.toStringAsFixed(2);
      if (parsed.merchant.isNotEmpty) {
        _noteController.text = parsed.merchant;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Receipt filled in. Check it and save.'),
      ),
    );
  }

  List<CategoryInfo> get _currentCategories =>
      _isIncome ? incomeCategories : expenseCategories;

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
    final double amount = double.parse(_amountController.text.trim());
    final Txn txn = Txn(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      amount: amount,
      isIncome: _isIncome,
      category: _category,
      date: _date,
      note: _noteController.text.trim(),
      accountId: _accountId ?? kDefaultAccountId,
      tag: _tagController.text.trim(),
    );
    context.read<FinanceProvider>().addTxn(txn);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final FinanceProvider provider = context.watch<FinanceProvider>();
    final List<Account> accounts = provider.accounts;
    if (_accountId == null && accounts.isNotEmpty) {
      _accountId = accounts.any((Account a) => a.id == kDefaultAccountId)
          ? kDefaultAccountId
          : accounts.first.id;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Add transaction')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            TextField(
              controller: _quickAddController,
              decoration: InputDecoration(
                labelText: 'Quick add (Bangla or Banglish)',
                hintText: 'For example: bazar 500 or বাজার ৫০০',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.auto_awesome),
                  tooltip: 'Parse quick add',
                  onPressed: _parseQuickAdd,
                ),
              ),
              onSubmitted: (_) => _parseQuickAdd(),
            ),
            if (_quickError != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _quickError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFE57373),
                ),
              ),
            ],
            if (_quickPreview != null) ...<Widget>[
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '${_quickPreview!.isIncome ? 'Income' : 'Expense'} - ${_quickPreview!.category} - ${fmtMoney(_quickPreview!.amount)} - ${_quickPreview!.note}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _useQuickPreview,
                        child: const Text('Use this'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (isReceiptScanSupported)
              OutlinedButton.icon(
                onPressed: _scanning ? null : _scanReceipt,
                icon: const Icon(Icons.document_scanner_outlined),
                label: Text(
                  _scanning ? 'Scanning receipt...' : 'Scan receipt',
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              )
            else
              Text(
                'Receipt scanning needs Android. On this device, type the amount above instead.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            const SizedBox(height: 20),
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
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              style: theme.textTheme.headlineSmall,
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
                if (parsed == null) {
                  return 'Enter a valid number';
                }
                if (parsed <= 0) {
                  return 'Amount must be more than 0';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Category',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
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
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
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
                hintText: 'What was this for?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tagController,
              decoration: const InputDecoration(
                labelText: 'Tag (optional)',
                hintText: 'For example: family, office, recurring',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('Save transaction'),
            ),
          ],
        ),
      ),
    );
  }
}
