import '../../accounts/data/accounts_repository.dart';
import '../../debt/data/debt_repository.dart';
import '../../debt/domain/amortization_engine.dart';
import '../../investments/data/investments_repository.dart';

/// Assets minus liabilities, computed fresh from every module that
/// contributes to either side -- never stored except as an explicit daily
/// snapshot (see NetWorthRepository), so today's figure always reflects
/// today's actual accounts/investments/loans.
class NetWorthTotals {
  final double assets;
  final double liabilities;

  const NetWorthTotals({required this.assets, required this.liabilities});

  double get netWorth => assets - liabilities;
}

class NetWorthCalculator {
  const NetWorthCalculator._();

  /// Assets = every non-credit-card account balance + the current market
  /// value of every investment. Liabilities = credit card outstanding
  /// balances + every loan's outstanding principal (derived live via
  /// [AmortizationEngine], never a stored running balance).
  static NetWorthTotals compute({
    required List<AccountModel> accounts,
    required List<InvestmentModel> investments,
    required List<LoanModel> loans,
  }) {
    double assets = 0;
    double liabilities = 0;

    for (final a in accounts) {
      if (a.type == 'credit_card') {
        liabilities += a.balance.abs();
      } else {
        assets += a.balance;
      }
    }

    for (final inv in investments) {
      assets += inv.unitsQuantity * inv.currentPrice;
    }

    for (final l in loans) {
      liabilities += AmortizationEngine.outstandingBalance(
        principal: l.loanAmount,
        annualRate: l.interestRate,
        tenureMonths: l.tenureMonths,
        emiAmount: l.emiAmount,
        startDate: DateTime.tryParse(l.startDate) ?? DateTime.now(),
      );
    }

    return NetWorthTotals(assets: assets, liabilities: liabilities);
  }
}
