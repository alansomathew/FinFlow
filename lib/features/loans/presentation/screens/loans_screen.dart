import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/loan_provider.dart';
import '../../domain/models/loan_model.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/common_widgets.dart';

class LoansScreen extends ConsumerWidget {
  const LoansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(loansStreamProvider);
    final totalDebtAsync = ref.watch(totalDebtProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Loans & EMIs', style: AppTextStyles.headlineMedium),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Column(
        children: [
          totalDebtAsync.when(
            data: (debt) => _DebtSummaryBanner(totalDebt: debt),
            loading: () => const ShimmerCard(height: 72),
            error: (_, __) => const SizedBox.shrink(),
          ),
          Expanded(
            child: loansAsync.when(
              data: (loans) {
                if (loans.isEmpty) {
                  return const EmptyStateWidget(
                    message: 'No active loans.\nTap + to add one.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: loans.length,
                  itemBuilder: (_, i) => _LoanTile(loan: loans[i]),
                );
              },
              loading: () => ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 3,
                itemBuilder: (_, __) =>
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: ShimmerCard(height: 88),
                    ),
              ),
              error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: AppTextStyles.bodyMedium)),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-loan'),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _DebtSummaryBanner extends StatelessWidget {
  final double totalDebt;

  const _DebtSummaryBanner({required this.totalDebt});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.expenseRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.expenseRed.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Outstanding',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary)),
              Text(
                CurrencyFormatter.format(totalDebt),
                style: AppTextStyles.amountMedium
                    .copyWith(color: AppColors.expenseRed),
              ),
            ],
          ),
          const Icon(Icons.credit_score_rounded,
              color: AppColors.expenseRed, size: 32),
        ],
      ),
    );
  }
}

class _LoanTile extends StatelessWidget {
  final LoanModel loan;

  const _LoanTile({required this.loan});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loan.lenderName,
                        style: AppTextStyles.bodyMedium),
                    Text(loan.typeLabel,
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'EMI ${CurrencyFormatter.formatCompact(loan.emiAmount)}',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: AppColors.expenseRed),
                  ),
                  Text(
                    '${loan.monthsRemaining} months left',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Outstanding: ${CurrencyFormatter.formatCompact(loan.outstandingPrincipal)}',
                style: AppTextStyles.caption,
              ),
              Text(
                'Principal: ${CurrencyFormatter.formatCompact(loan.principalAmount)}',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          BudgetProgressBar(
            spent: loan.principalAmount - loan.outstandingPrincipal,
            total: loan.principalAmount,
            color: AppColors.accent,
          ),
        ],
      ),
    );
  }
}
