import 'package:flutter_test/flutter_test.dart';
import 'package:finflow/src/features/debt/domain/amortization_engine.dart';

void main() {
  group('AmortizationEngine.calculateEmi', () {
    test('matches the textbook reference EMI for ₹1,00,000 at 12% / 12mo', () {
      final emi = AmortizationEngine.calculateEmi(
        principal: 100000,
        annualRate: 12,
        tenureMonths: 12,
      );
      expect(emi, closeTo(8884.88, 0.5));
    });

    test('interest-free loan splits principal evenly across the tenure', () {
      final emi = AmortizationEngine.calculateEmi(
        principal: 12000,
        annualRate: 0,
        tenureMonths: 12,
      );
      expect(emi, closeTo(1000, 0.001));
    });
  });

  group('AmortizationEngine.generateSchedule', () {
    test('a fully-amortizing EMI pays the loan off to zero within tenure', () {
      const principal = 250000.0;
      const rate = 9.5;
      const tenure = 36;
      final emi = AmortizationEngine.calculateEmi(
        principal: principal,
        annualRate: rate,
        tenureMonths: tenure,
      );
      final schedule = AmortizationEngine.generateSchedule(
        principal: principal,
        annualRate: rate,
        tenureMonths: tenure,
        emiAmount: emi,
      );
      expect(schedule.length, tenure);
      expect(schedule.last.closingBalance, closeTo(0, 0.01));
    });

    test('an under-sized EMI never pays off the loan within tenure', () {
      const principal = 100000.0;
      const rate = 24.0; // high rate, so a too-small EMI barely covers interest
      final schedule = AmortizationEngine.generateSchedule(
        principal: principal,
        annualRate: rate,
        tenureMonths: 12,
        emiAmount: 1500, // well under the true required EMI
      );
      // Every row should still owe a positive balance -- the loan never
      // clears within the requested tenure.
      expect(schedule.length, 12);
      expect(schedule.last.closingBalance, greaterThan(0));
    });
  });

  group('AmortizationEngine.outstandingBalance', () {
    test('equals the full principal on the loan start date', () {
      final balance = AmortizationEngine.outstandingBalance(
        principal: 500000,
        annualRate: 10,
        tenureMonths: 60,
        emiAmount: AmortizationEngine.calculateEmi(
          principal: 500000,
          annualRate: 10,
          tenureMonths: 60,
        ),
        startDate: DateTime(2026, 1, 10),
        asOf: DateTime(2026, 1, 10),
      );
      expect(balance, closeTo(500000, 0.01));
    });

    test('reaches zero once the full tenure has elapsed', () {
      final emi = AmortizationEngine.calculateEmi(
        principal: 500000,
        annualRate: 10,
        tenureMonths: 60,
      );
      final balance = AmortizationEngine.outstandingBalance(
        principal: 500000,
        annualRate: 10,
        tenureMonths: 60,
        emiAmount: emi,
        startDate: DateTime(2020, 1, 10),
        asOf: DateTime(2026, 1, 10), // exactly 72 months later
      );
      expect(balance, 0.0);
    });

    test('decreases monotonically partway through the tenure', () {
      final emi = AmortizationEngine.calculateEmi(
        principal: 500000,
        annualRate: 10,
        tenureMonths: 60,
      );
      final balanceEarly = AmortizationEngine.outstandingBalance(
        principal: 500000,
        annualRate: 10,
        tenureMonths: 60,
        emiAmount: emi,
        startDate: DateTime(2025, 1, 10),
        asOf: DateTime(2025, 7, 10), // 6 months in
      );
      final balanceLater = AmortizationEngine.outstandingBalance(
        principal: 500000,
        annualRate: 10,
        tenureMonths: 60,
        emiAmount: emi,
        startDate: DateTime(2025, 1, 10),
        asOf: DateTime(2026, 1, 10), // 12 months in
      );
      expect(balanceLater, lessThan(balanceEarly));
      expect(balanceEarly, lessThan(500000));
    });
  });

  group('AmortizationEngine.simulatePayoff (Snowball vs Avalanche)', () {
    test('Avalanche never pays more total interest than Snowball when rates differ', () {
      // Three loans: A is small and clears first regardless of method (no
      // redirection is possible until *something* frees up budget, since
      // the combined minimum EMIs exactly equal the total budget). Once A
      // clears, B and C disagree on which method should go first -- B has
      // the smaller balance but the lower rate, C has the larger balance
      // but the higher rate -- so this is exactly the case where Snowball
      // (smallest balance) and Avalanche (highest rate) diverge.
      final loans = [
        const LoanSnapshot(
          id: 'small-first',
          lenderName: 'A',
          balance: 15000,
          annualRate: 5,
          emiAmount: 3000,
        ),
        const LoanSnapshot(
          id: 'small-balance-low-rate',
          lenderName: 'B',
          balance: 40000,
          annualRate: 8,
          emiAmount: 1500,
        ),
        const LoanSnapshot(
          id: 'large-balance-high-rate',
          lenderName: 'C',
          balance: 90000,
          annualRate: 24,
          emiAmount: 3500,
        ),
      ];

      final snowball = AmortizationEngine.simulatePayoff(
        loans,
        priority: AmortizationEngine.snowballPriority,
      );
      final avalanche = AmortizationEngine.simulatePayoff(
        loans,
        priority: AmortizationEngine.avalanchePriority,
      );

      expect(avalanche.totalInterestPaid, lessThan(snowball.totalInterestPaid));
    });

    test('order has no effect on interest when every loan shares the same rate', () {
      final loans = [
        const LoanSnapshot(
          id: 'loan-1',
          lenderName: 'A',
          balance: 50000,
          annualRate: 10,
          emiAmount: 3000,
        ),
        const LoanSnapshot(
          id: 'loan-2',
          lenderName: 'B',
          balance: 80000,
          annualRate: 10,
          emiAmount: 4000,
        ),
      ];

      final snowball = AmortizationEngine.simulatePayoff(
        loans,
        priority: AmortizationEngine.snowballPriority,
      );
      final avalanche = AmortizationEngine.simulatePayoff(
        loans,
        priority: AmortizationEngine.avalanchePriority,
      );

      expect(avalanche.totalInterestPaid, closeTo(snowball.totalInterestPaid, 0.5));
      expect(avalanche.monthsToPayoff, snowball.monthsToPayoff);
    });

    test('an empty portfolio pays off instantly with no interest', () {
      final result = AmortizationEngine.simulatePayoff(
        [],
        priority: AmortizationEngine.snowballPriority,
      );
      expect(result.monthsToPayoff, 0);
      expect(result.totalInterestPaid, 0.0);
    });
  });
}
