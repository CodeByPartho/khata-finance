import 'package:flutter/material.dart';

import 'accounts_screen.dart';
import 'cards_screen.dart';
import 'debts_screen.dart';
import 'recurring_screen.dart';
import 'settings_screen.dart';

/// More tab: entry points to accounts, recurring bills, debts and
/// settings.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    Widget tile({
      required IconData icon,
      required String title,
      required String subtitle,
      required Widget page,
    }) {
      return Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLow,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
            child: Icon(icon, color: theme.colorScheme.primary, size: 20),
          ),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => page),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: <Widget>[
          tile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Accounts',
            subtitle: 'Cash, bKash, Nagad, Rocket, bank and transfers',
            page: const AccountsScreen(),
          ),
          tile(
            icon: Icons.credit_card_outlined,
            title: 'Cards and billing cycles',
            subtitle: 'Cycle spend, days left and due dates',
            page: const CardsScreen(),
          ),
          tile(
            icon: Icons.repeat,
            title: 'Recurring and Bills',
            subtitle: 'Auto entries, subscriptions and upcoming bills',
            page: const RecurringScreen(),
          ),
          tile(
            icon: Icons.handshake_outlined,
            title: 'Dena Paona',
            subtitle: 'Money you lent and money you borrowed',
            page: const DebtsScreen(),
          ),
          tile(
            icon: Icons.settings_outlined,
            title: 'Settings',
            subtitle: 'Privacy, PIN lock, backup and data controls',
            page: const SettingsScreen(),
          ),
        ],
      ),
    );
  }
}
