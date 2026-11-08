import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/finance_provider.dart';

/// Settings: privacy (hide amounts), PIN lock, backup export and
/// import, CSV export, and data danger zone.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<String?> _askPin(
    BuildContext context, {
    required String title,
    required String label,
  }) async {
    final TextEditingController controller = TextEditingController();
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final String value = controller.text.trim();
                if (value.length < 4) {
                  Navigator.of(dialogContext).pop();
                  return;
                }
                Navigator.of(dialogContext).pop(value);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
    return result;
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _setOrChangePin(BuildContext context) async {
    final FinanceProvider provider = context.read<FinanceProvider>();
    if (provider.hasPin) {
      final String? current = await _askPin(
        context,
        title: 'Change PIN',
        label: 'Current PIN',
      );
      if (current == null) {
        return;
      }
      if (!provider.verifyPin(current)) {
        if (context.mounted) {
          _snack(context, 'Current PIN is wrong.');
        }
        return;
      }
    }
    if (!context.mounted) {
      return;
    }
    final String? next = await _askPin(
      context,
      title: provider.hasPin ? 'Change PIN' : 'Set PIN',
      label: 'New PIN (4 or more digits)',
    );
    if (next == null) {
      return;
    }
    await provider.setPin(next);
    if (context.mounted) {
      _snack(context, 'PIN saved. The app will ask for it on start.');
    }
  }

  Future<void> _removePin(BuildContext context) async {
    final FinanceProvider provider = context.read<FinanceProvider>();
    final String? current = await _askPin(
      context,
      title: 'Remove PIN',
      label: 'Current PIN',
    );
    if (current == null) {
      return;
    }
    if (!provider.verifyPin(current)) {
      if (context.mounted) {
        _snack(context, 'Current PIN is wrong.');
      }
      return;
    }
    await provider.clearPin();
    if (context.mounted) {
      _snack(context, 'PIN removed.');
    }
  }

  Future<void> _exportBackup(BuildContext context) async {
    final String json = context.read<FinanceProvider>().exportJson();
    await Clipboard.setData(ClipboardData(text: json));
    if (!context.mounted) {
      return;
    }
    _snack(context, 'Backup copied. Paste it somewhere safe.');
  }

  Future<void> _importBackup(BuildContext context) async {
    final TextEditingController controller = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Import backup'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'Paste a Khata backup below. This replaces all current data.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Backup JSON',
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
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Import and overwrite'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    final bool ok =
        await context.read<FinanceProvider>().importJson(controller.text);
    if (!context.mounted) {
      return;
    }
    _snack(
      context,
      ok ? 'Backup imported.' : 'That backup could not be read.',
    );
  }

  Future<void> _showCsv(BuildContext context) async {
    final String csv = context.read<FinanceProvider>().exportCsv();
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Transactions CSV'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(
                csv,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: csv));
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Copy CSV'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Yes, continue'),
            ),
          ],
        );
      },
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final FinanceProvider provider = context.watch<FinanceProvider>();
    final ThemeData theme = Theme.of(context);

    Text sectionTitle(String text) {
      return Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          sectionTitle('Privacy'),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            child: SwitchListTile(
              title: const Text('Hide amounts'),
              subtitle: const Text(
                'Show dots instead of money amounts on the home and accounts screens.',
              ),
              value: provider.hideAmounts,
              onChanged: (bool value) {
                context.read<FinanceProvider>().setHideAmounts(value);
              },
            ),
          ),
          const SizedBox(height: 20),
          sectionTitle('PIN lock'),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: Text(
                    provider.hasPin ? 'Change PIN' : 'Set a PIN',
                  ),
                  subtitle: Text(
                    provider.hasPin
                        ? 'A PIN is set. The app asks for it on start.'
                        : 'Lock the app with a PIN of 4 or more digits.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _setOrChangePin(context),
                ),
                if (provider.hasPin)
                  ListTile(
                    leading: const Icon(Icons.lock_open_outlined),
                    title: const Text('Remove PIN'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _removePin(context),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          sectionTitle('Backup'),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.copy_outlined),
                  title: const Text('Export backup'),
                  subtitle: const Text(
                    'Copy all app data as JSON to the clipboard.',
                  ),
                  onTap: () => _exportBackup(context),
                ),
                ListTile(
                  leading: const Icon(Icons.paste_outlined),
                  title: const Text('Import backup'),
                  subtitle: const Text(
                    'Paste a backup JSON and replace all data.',
                  ),
                  onTap: () => _importBackup(context),
                ),
                ListTile(
                  leading: const Icon(Icons.table_chart_outlined),
                  title: const Text('Export transactions CSV'),
                  subtitle: const Text(
                    'View and copy transactions as CSV for spreadsheets.',
                  ),
                  onTap: () => _showCsv(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          sectionTitle('Danger zone'),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: const Color(0xFF2A1215),
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(
                    Icons.restore,
                    color: Color(0xFFFFAB91),
                  ),
                  title: const Text('Reset demo data'),
                  subtitle: const Text(
                    'Bring back the sample transactions and budgets.',
                  ),
                  onTap: () async {
                    final bool ok = await _confirm(
                      context,
                      title: 'Reset demo data?',
                      message:
                          'This replaces all current data with the demo data set.',
                    );
                    if (ok && context.mounted) {
                      await context.read<FinanceProvider>().resetToDemo();
                      if (context.mounted) {
                        _snack(context, 'Demo data restored.');
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever_outlined,
                    color: Color(0xFFFFAB91),
                  ),
                  title: const Text('Clear all data'),
                  subtitle: const Text(
                    'Delete every transaction, account, rule, goal and debt.',
                  ),
                  onTap: () async {
                    final bool ok = await _confirm(
                      context,
                      title: 'Clear all data?',
                      message:
                          'Everything will be deleted. This cannot be undone. Export a backup first if you need one.',
                    );
                    if (ok && context.mounted) {
                      await context.read<FinanceProvider>().clearAllData();
                      if (context.mounted) {
                        _snack(context, 'All data cleared.');
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown on app start when a PIN is set. Calls [onUnlocked] after a
/// correct PIN is entered.
class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _tryUnlock() {
    final FinanceProvider provider = context.read<FinanceProvider>();
    if (provider.verifyPin(_controller.text.trim())) {
      widget.onUnlocked();
    } else {
      setState(() {
        _error = 'Wrong PIN, try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.lock_outline,
                size: 52,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Khata is locked',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your PIN to continue.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                obscureText: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
                decoration: InputDecoration(
                  labelText: 'PIN',
                  errorText: _error,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _tryUnlock(),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _tryUnlock,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
