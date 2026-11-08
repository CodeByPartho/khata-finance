# Khata - Personal Finance Tracker

Khata (Bangla for ledger) is a personal finance app for tracking income, expenses and monthly budgets in Bangladeshi taka, built with Flutter and a hand-drawn chart engine.

## Features

- Total balance at a glance, with this month's income and expense on the home screen
- Add income and expense entries with category, date and note, with full form validation
- 8 expense categories (Food, Transport, Bills, Shopping, Health, Education, Entertainment, Other) and 4 income categories (Salary, Freelance, Business, Other Income), each with its own icon and color
- Full transaction history grouped by day, with swipe to delete and a confirm dialog
- Monthly budgets per category, with progress bars and an alert on the home screen when a category reaches 90 percent of its budget
- Stats screen with spending by category (totals and share bars) and a bar chart of the last 6 months of expenses
- Local persistence with shared_preferences: data survives restarts, no account and no server needed
- First run seeds realistic demo data in taka so the app can be explored immediately; data can be cleared or reset to demo from the provider API
- Dark Material 3 theme with a single green accent (#39FF88) on a near-black background

## Screenshots

Screenshots coming soon.

## Tech stack

- Flutter (Dart 3, null-safe) with Material 3
- State management: Provider (ChangeNotifier)
- Local storage: shared_preferences, transactions and budgets saved as JSON
- Formatting: intl (NumberFormat and DateFormat)
- Charts: hand-drawn with CustomPainter, no chart library
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
  main.dart                  App entry, theme, Provider setup
  models/
    transaction.dart         Txn model with JSON serialization
    categories.dart          Category names, icons and colors
  state/
    finance_provider.dart    ChangeNotifier state, persistence, demo seed
  widgets/
    monthly_bar_chart.dart   CustomPainter bar chart, last 6 months
  screens/
    main_shell.dart          Bottom navigation shell with Add button
    home_screen.dart         Balance card, budget alerts, recent entries
    transactions_screen.dart Full list grouped by day, swipe to delete
    stats_screen.dart        Category breakdown and monthly chart
    budgets_screen.dart      Budget list and budget editor dialog
    add_transaction_screen.dart  Add income or expense form
  utils/
    format.dart              Taka and date formatting helpers
test/
  finance_provider_test.dart Unit tests for totals, categories and budgets
```

## What this project demonstrates

- Clean state management with Provider: a single ChangeNotifier owns all finance state and notifies the UI
- Local persistence design: versioned preference keys, JSON encoding, one-time demo seeding that never overrides real user data
- Custom rendering with CustomPainter: gridlines, rounded bars, value and month labels, and graceful handling of all-zero data
- Material 3 patterns: NavigationBar, SegmentedButton, ChoiceChip, FilledButton
- Unit testing of business logic in isolation from the UI, using mocked platform storage

## Roadmap

- Edit an existing transaction
- Search and filter on the history screen
- Export transactions to CSV from inside the app
- Optional cloud backup

## Author

Built by Partho Sarothi Paik (CodeByPartho), Flutter and Full-Stack Developer, Dhaka, Bangladesh.
GitHub: https://github.com/CodeByPartho
