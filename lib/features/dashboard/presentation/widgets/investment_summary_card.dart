import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../investments/presentation/providers/investment_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/common_widgets.dart';

class InvestmentSummaryCard extends ConsumerWidget {
  const InvestmentSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfolioAsync = ref.watch(portfolioSummaryProvider);

    return AppCard(
      onTap: () => context.push('/investments'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Portfolio',
            onSeeAll: () => context.push('/investments'),
          ),
          const SizedBox(height: 12),
          portfolioAsync.when(
            data: (portfolio) {
              final isProfit = portfolio.absoluteReturn >= 0;
              return Row(
                children: [
                  Expanded(
                    child: _PortfolioStat(
                      label: 'Invested',
                      value: CurrencyFormatter.formatCompact(
                          portfolio.totalInvested),
                    ),
                  ),
                  Container(
                      width: 1, height: 40, color: AppColors.border),
                  Expanded(
                    child: _PortfolioStat(
                      label: 'Current',
                      value: CurrencyFormatter.formatCompact(
                          portfolio.currentValue),
                    ),
                  ),
                  Container(
                      width: 1, height: 40, color: AppColors.border),
                  Expanded(
                    child: _PortfolioStat(
                      label: 'Returns',
                      value: CurrencyFormatter.formatPercent(
                          portfolio.returnPercent),
                      valueColor: isProfit
                          ? AppColors.incomeGreen
                          : AppColors.expenseRed,
                    ),
                  ),
                ],
              );
            },
            loading: () => const ShimmerCard(height: 56),
            error: (_, __) => const EmptyStateWidget(
                message: 'Add investments to track portfolio'),
          ),
        ],
      ),
    );
  }
}

class _PortfolioStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _PortfolioStat({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.amountSmall.copyWith(
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.caption
              .copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
