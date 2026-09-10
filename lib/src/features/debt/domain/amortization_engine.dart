/// One month's row in a loan's amortization schedule.
class AmortizationRow {
  final int month;
  final double payment;
  final double principalComponent;
  final double interestComponent;
  final double closingBalance;

  const AmortizationRow({
    required this.month,
    required this.payment,
    required this.principalComponent,
    required this.interestComponent,
    required this.closingBalance,
  });
}

/// A loan as seen by the payoff simulator: its current outstanding balance,
/// monthly rate, and the fixed EMI it's being paid down with.
class LoanSnapshot {
  final String id;
  final String lenderName;
  final double balance;
  final double annualRate;
  final double emiAmount;

  const LoanSnapshot({
    required this.id,
    required this.lenderName,
    required this.balance,
    required this.annualRate,
    required this.emiAmount,
  });
}

/// Result of simulating a portfolio payoff strategy: how long it takes to
/// become debt-free and how much interest is paid in total along the way,
/// holding the combined EMI budget fixed and redirecting a loan's freed-up
/// EMI to the next-priority loan the moment it's paid off.
class PayoffSimulationResult {
  final int monthsToPayoff;
  final double totalInterestPaid;

  const PayoffSimulationResult({
    required this.monthsToPayoff,
    required this.totalInterestPaid,
  });
}

/// Pure-Dart reducing-balance amortization math. No I/O, no Flutter/Riverpod
/// dependency -- every figure here is derived fresh from (principal, rate,
/// tenure, start date) rather than stored, matching how the rest of the app
/// avoids caching values that can drift out of sync with their source data.
class AmortizationEngine {
  const AmortizationEngine._();

  /// Cap on simulated months so a pathological input (e.g. an EMI too small
  /// to cover monthly interest) can't loop forever instead of just never
  /// paying the loan off.
  static const int _maxSimulationMonths = 1200; // 100 years

  static double monthlyRate(double annualRatePercent) =>
      annualRatePercent / 12 / 100;

  /// The standard reducing-balance EMI formula:
  /// EMI = P * r * (1+r)^n / ((1+r)^n - 1), with the r == 0 edge case
  /// (an interest-free loan) falling back to a plain equal split.
  static double calculateEmi({
    required double principal,
    required double annualRate,
    required int tenureMonths,
  }) {
    if (tenureMonths <= 0) return 0.0;
    final r = monthlyRate(annualRate);
    if (r == 0) return principal / tenureMonths;
    final factor = _pow(1 + r, tenureMonths);
    return principal * r * factor / (factor - 1);
  }

  /// The full month-by-month amortization table for a single loan, using
  /// the given (possibly rounded) [emiAmount] rather than recomputing the
  /// theoretical EMI, so schedules built from a real user-entered EMI stay
  /// consistent with what they actually agreed to pay. Stops early if the
  /// balance reaches zero before [tenureMonths] elapse.
  static List<AmortizationRow> generateSchedule({
    required double principal,
    required double annualRate,
    required int tenureMonths,
    required double emiAmount,
  }) {
    final r = monthlyRate(annualRate);
    var balance = principal;
    final rows = <AmortizationRow>[];

    for (var month = 1; month <= tenureMonths && balance > 0.01; month++) {
      final interest = balance * r;
      var principalPaid = emiAmount - interest;
      var payment = emiAmount;
      if (principalPaid >= balance) {
        // Final installment: don't overpay past the outstanding balance.
        principalPaid = balance;
        payment = principalPaid + interest;
      }
      balance -= principalPaid;
      if (balance < 0.01) balance = 0;
      rows.add(
        AmortizationRow(
          month: month,
          payment: payment,
          principalComponent: principalPaid,
          interestComponent: interest,
          closingBalance: balance,
        ),
      );
    }
    return rows;
  }

  /// The loan's remaining principal as of today, derived by walking the
  /// schedule forward from [startDate] rather than storing a running
  /// balance anywhere -- never out of sync with (principal, rate, tenure).
  static double outstandingBalance({
    required double principal,
    required double annualRate,
    required int tenureMonths,
    required double emiAmount,
    required DateTime startDate,
    DateTime? asOf,
  }) {
    final now = asOf ?? DateTime.now();
    final elapsedMonths = _monthsBetween(startDate, now);
    if (elapsedMonths <= 0) return principal;

    final schedule = generateSchedule(
      principal: principal,
      annualRate: annualRate,
      tenureMonths: tenureMonths,
      emiAmount: emiAmount,
    );
    if (elapsedMonths >= schedule.length) return 0.0;
    return schedule[elapsedMonths - 1].closingBalance;
  }

  /// Total interest paid over the full life of the loan.
  static double totalInterest({
    required double principal,
    required double annualRate,
    required int tenureMonths,
    required double emiAmount,
  }) {
    final schedule = generateSchedule(
      principal: principal,
      annualRate: annualRate,
      tenureMonths: tenureMonths,
      emiAmount: emiAmount,
    );
    return schedule.fold(0.0, (sum, row) => sum + row.interestComponent);
  }

  /// Simulates paying off every loan in [loans] using a combined monthly
  /// budget equal to the sum of their EMIs, held fixed for the whole
  /// simulation. Each month, every active loan gets its own EMI paid; any
  /// budget freed up because a loan has already finished (or finishes this
  /// month with less than a full EMI remaining) is redirected as extra
  /// principal to whichever active loan [priority] ranks first. This is
  /// what actually makes Snowball (smallest balance first) and Avalanche
  /// (highest rate first) produce different results -- without redirecting
  /// freed EMI, paying loans independently gives identical total interest
  /// regardless of order.
  static PayoffSimulationResult simulatePayoff(
    List<LoanSnapshot> loans, {
    required Comparator<LoanSnapshot> priority,
  }) {
    final balances = {for (final l in loans) l.id: l.balance};
    final rates = {for (final l in loans) l.id: monthlyRate(l.annualRate)};
    final emis = {for (final l in loans) l.id: l.emiAmount};
    final totalBudget = loans.fold(0.0, (sum, l) => sum + l.emiAmount);

    var totalInterestPaid = 0.0;
    var month = 0;

    while (balances.values.any((b) => b > 0.01) &&
        month < _maxSimulationMonths) {
      month++;
      var minPaymentsThisMonth = 0.0;

      for (final l in loans) {
        final balance = balances[l.id]!;
        if (balance <= 0) continue;
        final interest = balance * rates[l.id]!;
        totalInterestPaid += interest;
        var newBalance = balance + interest;
        final payment = emis[l.id]! >= newBalance ? newBalance : emis[l.id]!;
        newBalance -= payment;
        balances[l.id] = newBalance < 0.01 ? 0 : newBalance;
        minPaymentsThisMonth += payment;
      }

      final freedBudget = totalBudget - minPaymentsThisMonth;
      if (freedBudget > 0.01) {
        final active = loans.where((l) => balances[l.id]! > 0).toList()
          ..sort(priority);
        if (active.isNotEmpty) {
          final target = active.first;
          final extra = freedBudget < balances[target.id]!
              ? freedBudget
              : balances[target.id]!;
          balances[target.id] = balances[target.id]! - extra;
        }
      }
    }

    return PayoffSimulationResult(
      monthsToPayoff: month,
      totalInterestPaid: totalInterestPaid,
    );
  }

  /// Smallest-balance-first: pay off the loan with the least remaining
  /// principal before any other, regardless of its interest rate.
  static int snowballPriority(LoanSnapshot a, LoanSnapshot b) =>
      a.balance.compareTo(b.balance);

  /// Highest-rate-first: pay off the loan costing the most in interest
  /// before any other, regardless of its remaining balance.
  static int avalanchePriority(LoanSnapshot a, LoanSnapshot b) =>
      b.annualRate.compareTo(a.annualRate);

  static double _pow(double base, int exponent) {
    var result = 1.0;
    for (var i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }

  static int _monthsBetween(DateTime start, DateTime end) {
    var months = (end.year - start.year) * 12 + (end.month - start.month);
    if (end.day < start.day) months -= 1;
    return months < 0 ? 0 : months;
  }
}
