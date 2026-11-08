# Khata - Personal Finance Tracker

Khata (Bangla for ledger) is a personal finance app for tracking income, expenses and monthly budgets in Bangladeshi taka, built with Flutter and a hand-drawn chart engine.

Feature set benchmarked against leading finance apps (YNAB, Rocket Money, Monarch, Wallet by BudgetBakers, Spendee, Monefy, Money Manager) and Bangladesh money apps, November 2026.

## What is new in 1.1

- Multiple wallets and accounts: Cash, bKash, Nagad, Rocket and Bank presets, plus custom accounts with opening balances
- Transfers between accounts with an optional fee, for example an MFS cash out fee; transfers never distort income, expense or budget totals
- Recurring income and bills: rules post automatically when due, with an upcoming bills view for the next 7 and 30 days
- Subscriptions view: every active recurring expense normalized to a monthly cost, with a total per month
- Safe to Spend card on the home screen, based on budgets or income, minus expenses and bills still due this month, with a budget pace indicator
- Savings goals with progress bars and quick add or remove of savings
- Dena Paona ledger: money lent and borrowed per person, repayments, and a statement you can copy into WhatsApp
- Net worth on the Stats screen: accounts total plus money owed to you, minus money you owe
- Search and filters on the transaction history (note, category, tag; All, Income, Expense) with a filtered total
- Tags and per-transaction account selection in the add form
- Privacy: hide amounts with one tap, and an optional PIN lock (stored as a SHA-256 hash) asked on app start
- Backup and restore: export all data as JSON, import it back, and export transactions as CSV for spreadsheets

## Features

- Total balance at a glance, with this month's income and expense on the home screen, plus a wallets strip with the balance of every account
- Add income and expense entries with category, account, tag, date and note, with full form validation
- 8 expense categories (Food, Transport, Bills, Shopping, Health, Education, Entertainment, Other) and 4 income categories (Salary, Freelance, Business, Other Income), each with its own icon and color
- Full transaction history grouped by day, with search, type filters, swipe to delete and a confirm dialog
- Monthly budgets per category, with progress bars and an alert on the home screen when a category reaches 90 percent of its budget
- Stats screen with a net worth card, spending by category (totals and share bars), a bar chart of the last 6 months of expenses, and a grouped income vs expense chart
- Accounts, recurring rules, savings goals and debts, all persisted locally
- Local persistence with shared_preferences: data survives restarts, no account and no server needed
- First run seeds realistic demo data in taka so the app can be explored immediately; demo data can be restored or everything cleared from Settings
- Dark Material 3 theme with a single green accent (#39FF88) on a near-black background

## Screenshots

Screenshots coming soon.

## Tech stack

- Flutter (Dart 3, null-safe) with Material 3
- State management: Provider (ChangeNotifier)
- Local storage: shared_preferences, all data saved as JSON under versioned keys
- Formatting: intl (NumberFormat and DateFormat)
- Charts: hand-drawn with CustomPainter, no chart library
- Security: PIN stored as a SHA-256 hash (crypto package), never in plain text and never in backups
- Tests: flutter_test with mocked shared_preferences

## How to run

```bash
flutter pub get
flutter run
```

To run the unit tests:

```bash
flutter test
```

## Project structure

```text
lib/
  main.dart                  App entry, theme, Provider setup, PIN lock gate
  models/
    transaction.dart         Txn model with account and tag, JSON serialization
    categories.dart          Category names, icons and colors
    account.dart             Account and wallet model with preset wallets
    transfer.dart            Transfer between accounts, with fee
    recurring_rule.dart      Recurring rule model, frequency date math
    goal.dart                Savings goal model with progress
    debt_entry.dart          Dena paona (debt) entry model
  state/
    finance_provider.dart    ChangeNotifier state, persistence, recurring
                             engine, safe to spend, net worth, PIN, backup
  widgets/
    monthly_bar_chart.dart   CustomPainter charts: expenses and income
                             vs expense, last 6 months
  screens/
    main_shell.dart          Bottom navigation shell (Home, Stats, Plan,
                             More) with Add button
    home_screen.dart         Wallets strip, balance, safe to spend,
                             upcoming bills, budget alerts, recent entries
    transactions_screen.dart Search, filters, grouped list, swipe to delete
    stats_screen.dart        Net worth, category breakdown, monthly charts
    plan_screen.dart         Plan tab: savings goals plus budgets
    budgets_screen.dart      Budget list and budget editor dialog
    more_screen.dart         More tab: links to accounts, recurring,
                             debts and settings
    accounts_screen.dart     Accounts list and transfer form
    recurring_screen.dart    Subscriptions, rules and upcoming bills
    debts_screen.dart        Dena Paona ledger and statements
    settings_screen.dart     Privacy, PIN lock, backup, CSV, danger zone
    add_transaction_screen.dart  Add income or expense form
  utils/
    format.dart              Taka and date formatting helpers
test/
  finance_provider_test.dart Unit tests for totals, categories and budgets
  finance_features_test.dart Unit tests for transfers, recurring rules,
                             goals, debts, safe to spend, backup and PIN
```

## What this project demonstrates

- Clean state management with Provider: a single ChangeNotifier owns all finance state and notifies the UI
- Local persistence design: versioned preference keys, JSON encoding, one-time demo seeding that never overrides real user data, and a safe upgrade path for data saved by older versions
- A small recurring engine: due rules post exactly once, with month-end date clamping (a bill due on the 31st lands on the last day of February)
- Money math that stays honest: transfers and fees are kept out of income, expense and budget totals, and safe to spend reserves money for bills still due
- Custom rendering with CustomPainter: gridlines, rounded bars, value and month labels, grouped income vs expense bars, and graceful handling of all-zero data
- Material 3 patterns: NavigationBar, SegmentedButton, ChoiceChip, FilledButton
- Unit testing of business logic in isolation from the UI, using mocked platform storage, including a backup export and import round trip

## Roadmap

- Edit an existing transaction
- Attach a receipt photo to a transaction
- Optional cloud backup sync
- Bangla language UI option

## Author

Built by Partho Sarothi Paik (CodeByPartho), Flutter and Full-Stack Developer, Dhaka, Bangladesh.
GitHub: https://github.com/CodeByPartho
