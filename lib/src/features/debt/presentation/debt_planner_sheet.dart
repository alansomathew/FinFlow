import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_sizes.dart';
import '../../../services/pro_tier_service.dart';
import '../data/debt_repository.dart';
import '../domain/amortization_engine.dart';
import 'loan_form_sheet.dart';

class DebtPlannerSheet extends ConsumerWidget {
  const DebtPlannerSheet({super.key});

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(amount);
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const LoanFormSheet(),
    );
  }

  void _showEditSheet(BuildContext context, LoanModel loan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LoanFormSheet(existing: loan),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    LoanModel loan,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        title: const Text(
          'Delete Loan?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'This removes "${loan.lenderName}" from your debt portfolio.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(loanListProvider.notifier).remove(loan.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(loanListProvider);
    final isPro = ref.watch(isProProvider).valueOrNull ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Debt Payoff Planner',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            tooltip: 'Add Loan',
            onPressed: () => _showAddSheet(context),
          ),
        ],
      ),
      body: SafeArea(
        child: loansAsync.when(
          data: (loans) {
            if (loans.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'No active loans tracked.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    AppSizes.h12,
                    ElevatedButton.icon(
                      onPressed: () => _showAddSheet(context),
                      icon: const Icon(Icons.add_rounded, color: Colors.white),
                      label: const Text(
                        'Add Loan',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Every figure below is derived live from (principal, rate,
            // tenure, start date) via AmortizationEngine -- nothing here is
            // a stored running balance that could drift out of sync.
            final snapshots = loans.map((l) {
              final balance = AmortizationEngine.outstandingBalance(
                principal: l.loanAmount,
                annualRate: l.interestRate,
                tenureMonths: l.tenureMonths,
                emiAmount: l.emiAmount,
                startDate: DateTime.tryParse(l.startDate) ?? DateTime.now(),
              );
              return LoanSnapshot(
                id: l.id,
                lenderName: l.lenderName,
                balance: balance,
                annualRate: l.interestRate,
                emiAmount: l.emiAmount,
              );
            }).toList();

            final totalOutstanding = snapshots.fold(
              0.0,
              (sum, s) => sum + s.balance,
            );

            final snowball = AmortizationEngine.simulatePayoff(
              snapshots,
              priority: AmortizationEngine.snowballPriority,
            );
            final avalanche = AmortizationEngine.simulatePayoff(
              snapshots,
              priority: AmortizationEngine.avalanchePriority,
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Total Debt Card
                  Container(
                    padding: const EdgeInsets.all(AppSizes.md),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'TOTAL OUTSTANDING DEBT',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        AppSizes.h8,
                        Text(
                          _formatCurrency(totalOutstanding),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSizes.h16,

                  const Text(
                    'Active Loan Breakdown',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  AppSizes.h8,

                  ...List.generate(loans.length, (i) {
                    final l = loans[i];
                    final balance = snapshots[i].balance;
                    return Card(
                      color: AppColors.cardBg,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () => _showEditSheet(context, l),
                        onLongPress: () => _confirmDelete(context, ref, l),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.error.withValues(
                            alpha: 0.15,
                          ),
                          child: const Icon(
                            Icons.credit_score_rounded,
                            color: AppColors.error,
                          ),
                        ),
                        title: Text(
                          l.lenderName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          'Rate: ${l.interestRate}% • Tenure: ${l.tenureMonths} mos',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatCurrency(balance),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'EMI: ${_formatCurrency(l.emiAmount)}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  AppSizes.h16,
                  const Text(
                    'Payoff Method Analysis',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  AppSizes.h8,

                  if (!isPro)
                    Container(
                      padding: const EdgeInsets.all(AppSizes.md),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(
                                Icons.workspace_premium_rounded,
                                color: AppColors.warning,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Pro Feature',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          AppSizes.h8,
                          const Text(
                            'Snowball vs Avalanche payoff simulation is a Pro feature. Upgrade to see which method saves you the most interest across your actual loan portfolio.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: _PayoffMethodCard(
                            title: 'Snowball Method',
                            subtitle: 'Priority: Smallest balance first',
                            color: AppColors.wants,
                            result: snowball,
                            formatCurrency: _formatCurrency,
                          ),
                        ),
                        AppSizes.w12,
                        Expanded(
                          child: _PayoffMethodCard(
                            title: 'Avalanche Method',
                            subtitle: 'Priority: Highest interest first',
                            color: AppColors.success,
                            result: avalanche,
                            formatCurrency: _formatCurrency,
                          ),
                        ),
                      ],
                    ),
                    AppSizes.h16,
                    _buildRecommendation(snowball, avalanche),
                  ],
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  Widget _buildRecommendation(
    PayoffSimulationResult snowball,
    PayoffSimulationResult avalanche,
  ) {
    final interestDiff =
        (snowball.totalInterestPaid - avalanche.totalInterestPaid).abs();
    final monthsDiff = (snowball.monthsToPayoff - avalanche.monthsToPayoff).abs();

    final String message;
    if (interestDiff < 1 && monthsDiff == 0) {
      message =
          'Both methods produce the same result for your current loan mix -- '
          'there\'s no interest-rate spread wide enough for the order to matter.';
    } else {
      final avalancheWins = avalanche.totalInterestPaid <= snowball.totalInterestPaid;
      final winner = avalancheWins ? 'Avalanche' : 'Snowball';
      final loser = avalancheWins ? 'Snowball' : 'Avalanche';
      message =
          'The $winner method is recommended for your loans. It saves '
          '${_formatCurrency(interestDiff)} in total interest compared to '
          '$loser'
          '${monthsDiff > 0 ? ' and pays off your debt portfolio $monthsDiff month${monthsDiff == 1 ? '' : 's'} sooner' : ''}.';
    }

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.insights_rounded, color: AppColors.success, size: 24),
          AppSizes.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recommendation:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                AppSizes.h4,
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PayoffMethodCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final PayoffSimulationResult result;
  final String Function(double) formatCurrency;

  const _PayoffMethodCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.result,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.cardBg,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            AppSizes.h8,
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
            AppSizes.h12,
            Text(
              'Interest: ${formatCurrency(result.totalInterestPaid)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            AppSizes.h4,
            Text(
              'Debt-free in ${result.monthsToPayoff} months',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
