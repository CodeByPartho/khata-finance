import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/main_shell.dart';
import 'screens/settings_screen.dart';
import 'state/finance_provider.dart';

const Color kAccent = Color(0xFF39FF88);
const Color kBackground = Color(0xFF0B0F0C);

/// Decides what to show on start: a loading spinner while data
/// loads, the lock screen when a PIN is set, or the main shell.
class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  bool _unlocked = false;

  @override
  Widget build(BuildContext context) {
    final FinanceProvider provider = context.watch<FinanceProvider>();
    if (!provider.isLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (provider.hasPin && !_unlocked) {
      return LockScreen(
        onUnlocked: () {
          setState(() {
            _unlocked = true;
          });
        },
      );
    }
    return const MainShell();
  }
}

void main() {
  runApp(const KhataApp());
}

class KhataApp extends StatelessWidget {
  const KhataApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<FinanceProvider>(
      create: (_) => FinanceProvider(),
      child: MaterialApp(
        title: 'Khata - Personal Finance Tracker',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const AppGate(),
      ),
    );
  }

  ThemeData _buildTheme() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: kAccent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: kAccent,
      onPrimary: const Color(0xFF06280F),
      surface: const Color(0xFF121713),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: kBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: kBackground,
        elevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF121713),
        indicatorColor: kAccent.withValues(alpha: 0.18),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: kAccent,
          foregroundColor: const Color(0xFF06280F),
        ),
      ),
    );
  }
}
