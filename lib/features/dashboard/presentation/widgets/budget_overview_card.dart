import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../../budget/presentation/providers/budget_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/common_widgets.dart';

class BudgetOverviewCard extends ConsumerWidget {
  const BudgetOverviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bucketAsync = ref.watch(bucketSummaryProvider);

    return AppCard(
      onTap: () => context.go('/budget'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: 'Budget Overview', onSeeAll: () => context.go('/budget')),
          const SizedBox(height: 12),
          bucketAsync.when(
            data: (bucket) => Row(
              children: [
                // Donut chart
                SizedBox(
                  width: 100,
                  height: 100,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 28,
                      sections: [
                        PieChartSectionData(
                          value: bucket.needsSpent,
                          color: AppColors.needsColor,
                          radius: 18,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          value: bucket.wantsSpent,
                          color: AppColors.wantsColor,
                          radius: 18,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          value: bucket.savingsSpent,
                          color: AppColors.savingsColor,
                          radius: 18,
                          showTitle: false,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Bucket breakdowns
                Expanded(
                  child: Column(
                    children: [
                      _BucketRow(
                        label: 'Needs 50%',
                        spent: bucket.needsSpent,
                        allocated: bucket.needsAllocated,
                        color: AppColors.needsColor,
                      ),
                      const SizedBox(height: 8),
                      _BucketRow(
                        label: 'Wants 30%',
                        spent: bucket.wantsSpent,
                        allocated: bucket.wantsAllocated,
                        color: AppColors.wantsColor,
                      ),
                      const SizedBox(height: 8),
                      _BucketRow(
                        label: 'Savings 20%',
                        spent: bucket.savingsSpent,
                        allocated: bucket.savingsAllocated,
                        color: AppColors.savingsColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            loading: () => const ShimmerCard(height: 100),
            error: (_, __) => const EmptyStateWidget(
              message: 'Set up your budget to see overview',
            ),
          ),
        ],
      ),
    );
  }
}

class _BucketRow extends StatelessWidget {
  final String label;
  final double spent;
  final double allocated;
  final Color color;

  const _BucketRow({
    required this.label,
    required this.spent,
    required this.allocated,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
            Text(
              '${CurrencyFormatter.formatCompact(spent)} / ${CurrencyFormatter.formatCompact(allocated)}',
              style: AppTextStyles.caption,
            ),
          ],
        ),
        const SizedBox(height: 4),
        BudgetProgressBar(
          spent: spent,
          total: allocated,
          color: color,
        ),
      ],
    );
  }
}
