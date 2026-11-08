import 'package:flutter/material.dart';

/// Kind of money account or wallet.
enum AccountKind { cash, bank, mfs, other }

extension AccountKindInfo on AccountKind {
  String get label {
    switch (this) {
      case AccountKind.cash:
        return 'Cash';
      case AccountKind.bank:
        return 'Bank';
      case AccountKind.mfs:
        return 'MFS wallet';
      case AccountKind.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case AccountKind.cash:
        return Icons.money;
      case AccountKind.bank:
        return Icons.account_balance;
      case AccountKind.mfs:
        return Icons.phone_android;
      case AccountKind.other:
        return Icons.wallet;
    }
  }
}

AccountKind accountKindFromName(String? name) {
  for (final AccountKind kind in AccountKind.values) {
    if (kind.name == name) {
      return kind;
    }
  }
  return AccountKind.other;
}

/// A wallet or account that holds money, for example cash in hand,
/// a bKash wallet or a bank account.
class Account {
  final String id;
  final String name;
  final AccountKind kind;
  final double openingBalance;

  const Account({
    required this.id,
    required this.name,
    required this.kind,
    this.openingBalance = 0,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'kind': kind.name,
      'openingBalance': openingBalance,
    };
  }

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Account',
      kind: accountKindFromName(json['kind'] as String?),
      openingBalance: (json['openingBalance'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// The preset wallets created on first run. The cash account id is
/// also the default account for transactions saved by older versions.
List<Account> presetAccounts() {
  return const <Account>[
    Account(id: 'cash', name: 'Cash', kind: AccountKind.cash),
    Account(id: 'bkash', name: 'bKash', kind: AccountKind.mfs),
    Account(id: 'nagad', name: 'Nagad', kind: AccountKind.mfs),
    Account(id: 'rocket', name: 'Rocket', kind: AccountKind.mfs),
    Account(id: 'bank', name: 'Bank', kind: AccountKind.bank),
  ];
}
