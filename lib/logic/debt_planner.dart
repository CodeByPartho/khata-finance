/// Debt payoff planner: Avalanche (highest interest first) and
/// Snowball (smallest balance first). Pure logic, no Flutter imports.
enum PayoffStrategy { avalanche, snowball }

/// One debt the user owes, with the minimum monthly payment and an
/// optional annual interest rate in percent (0 means interest free).
class PlannerDebt {
  final String id;
  final String name;
  final double balance;
  final double annualRatePercent;
  final double minPayment;

  const PlannerDebt({
    required this.id,
    required this.name,
    required this.balance,
    this.annualRatePercent = 0,
    required this.minPayment,
  });
}

/// One line of the payoff plan: which debt, in which order, how many
/// months it takes to clear, and the interest paid on it.
class PayoffStep {
  final PlannerDebt debt;
  final int order;
  final int monthsToClear;
  final double interestPaid;

  const PayoffStep({
    required this.debt,
    required this.order,
    required this.monthsToClear,
    required this.interestPaid,
  });
}

/// Result of a payoff plan: the ordered steps, total months until
/// debt free, total interest paid, and interest saved compared with
/// paying only the minimums on every debt.
class PayoffPlan {
  final List<PayoffStep> steps;
  final int totalMonths;
  final double totalInterest;
  final double interestSaved;

  const PayoffPlan({
    required this.steps,
    required this.totalMonths,
    required this.totalInterest,
    required this.interestSaved,
  });

  double get totalDebt =>
      steps.fold(0.0, (double sum, PayoffStep s) => sum + s.debt.balance);
}

/// Orders the debts for the chosen strategy. Avalanche sorts by
/// interest rate descending (ties: larger balance first). Snowball
/// sorts by balance ascending (ties: higher rate first).
List<PlannerDebt> orderDebts(
  List<PlannerDebt> debts,
  PayoffStrategy strategy,
) {
  final List<PlannerDebt> sorted = List<PlannerDebt>.from(debts);
  if (strategy == PayoffStrategy.avalanche) {
    sorted.sort((PlannerDebt a, PlannerDebt b) {
      final int byRate =
          b.annualRatePercent.compareTo(a.annualRatePercent);
      if (byRate != 0) {
        return byRate;
      }
      return b.balance.compareTo(a.balance);
    });
  } else {
    sorted.sort((PlannerDebt a, PlannerDebt b) {
      final int byBalance = a.balance.compareTo(b.balance);
      if (byBalance != 0) {
        return byBalance;
      }
      return b.annualRatePercent.compareTo(a.annualRatePercent);
    });
  }
  return sorted;
}

class _SimDebt {
  final PlannerDebt debt;
  double balance;
  double interestPaid = 0;
  int monthsToClear = 0;

  _SimDebt(this.debt) : balance = debt.balance;
}

/// Simulates month by month. Every month each open debt is charged
/// interest, then its minimum is paid. The extra pot (the monthly
/// extra plus the minimums of debts cleared in earlier months) goes
/// to the first open debt in the payoff order. Returns null when the
/// plan can never finish (minimums do not cover the interest).
({List<PayoffStep> steps, int months, double interest})? simulatePayoff(
  List<PlannerDebt> ordered,
  double extraPerMonth,
) {
  final List<_SimDebt> debts =
      ordered.map((PlannerDebt d) => _SimDebt(d)).toList();
  const int maxMonths = 1200;
  int month = 0;
  while (debts.any((_SimDebt d) => d.balance > 0.005)) {
    month++;
    if (month > maxMonths) {
      return null;
    }
    for (final _SimDebt d in debts) {
      if (d.balance <= 0.005) {
        continue;
      }
      final double interest =
          d.balance * (d.debt.annualRatePercent / 100) / 12;
      d.balance += interest;
      d.interestPaid += interest;
      double payment = d.debt.minPayment;
      if (payment > d.balance) {
        payment = d.balance;
      }
      d.balance -= payment;
      if (d.balance <= 0.005) {
        d.balance = 0;
        d.monthsToClear = month;
      }
    }
    // Extra pot: the monthly extra plus the minimums of debts
    // already cleared in earlier months.
    double extra = extraPerMonth;
    for (final _SimDebt d in debts) {
      if (d.balance <= 0.005 &&
          d.monthsToClear > 0 &&
          d.monthsToClear < month) {
        extra += d.debt.minPayment;
      }
    }
    for (final _SimDebt d in debts) {
      if (extra <= 0) {
        break;
      }
      if (d.balance <= 0.005) {
        continue;
      }
      double payment = extra;
      if (payment > d.balance) {
        payment = d.balance;
      }
      d.balance -= payment;
      extra -= payment;
      if (d.balance <= 0.005) {
        d.balance = 0;
        d.monthsToClear = month;
      }
    }
  }
  final List<PayoffStep> steps = <PayoffStep>[];
  for (int i = 0; i < debts.length; i++) {
    steps.add(
      PayoffStep(
        debt: debts[i].debt,
        order: i + 1,
        monthsToClear: debts[i].monthsToClear,
        interestPaid: debts[i].interestPaid,
      ),
    );
  }
  final double interest = debts.fold(
    0.0,
    (double sum, _SimDebt d) => sum + d.interestPaid,
  );
  return (steps: steps, months: month, interest: interest);
}

/// Builds the full plan for [debts] under [strategy] with
/// [extraPerMonth] paid on top of the minimums. The interest saved
/// is measured against paying only the minimums with no extra.
/// Returns null when the debts can never be cleared.
PayoffPlan? planDebts(
  List<PlannerDebt> debts,
  PayoffStrategy strategy,
  double extraPerMonth,
) {
  final List<PlannerDebt> open =
      debts.where((PlannerDebt d) => d.balance > 0).toList();
  if (open.isEmpty) {
    return const PayoffPlan(
      steps: <PayoffStep>[],
      totalMonths: 0,
      totalInterest: 0,
      interestSaved: 0,
    );
  }
  final List<PlannerDebt> ordered = orderDebts(open, strategy);
  final double extra = extraPerMonth < 0 ? 0 : extraPerMonth;
  final ({List<PayoffStep> steps, int months, double interest})? planned =
      simulatePayoff(ordered, extra);
  if (planned == null) {
    return null;
  }
  final ({List<PayoffStep> steps, int months, double interest})? baseline =
      simulatePayoff(ordered, 0);
  final double baselineInterest = baseline?.interest ?? planned.interest;
  return PayoffPlan(
    steps: planned.steps,
    totalMonths: planned.months,
    totalInterest: planned.interest,
    interestSaved: baselineInterest - planned.interest,
  );
}
