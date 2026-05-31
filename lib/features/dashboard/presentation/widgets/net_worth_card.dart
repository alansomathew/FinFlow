import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../../accounts/presentation/providers/account_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/common_widgets.dart';

class NetWorthCard extends ConsumerWidget {
  const NetWorthCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final netWorthAsync = ref.watch(netWorthProvider);
    final historyAsync = ref.watch(netWorthHistoryProvider);

    return GestureDetector(
      onTap: () => GoRouter.of(context).go('/accounts'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.netWorthGradient,
          borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Net Worth',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: Colors.white70),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'This Month',
                  style: AppTextStyles.caption
                      .copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          netWorthAsync.when(
            data: (value) => Text(
              CurrencyFormatter.format(value),
              style: AppTextStyles.amountLarge
                  .copyWith(color: Colors.white, fontSize: 32),
            ),
            loading: () =>
                const ShimmerCard(height: 38, width: 180),
            error: (_, __) => Text(
              '—',
              style: AppTextStyles.amountLarge
                  .copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          // Sparkline chart
          historyAsync.when(
            data: (history) {
              if (history.every((v) => v == 0)) {
                return Text(
                  'No history yet',
                  style: AppTextStyles.caption
                      .copyWith(color: Colors.white60),
                );
              }
              return SizedBox(
                height: 50,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(
                          history.length,
                          (i) =>
                              FlSpot(i.toDouble(), history[i]),
                        ),
                        isCurved: true,
                        color: Colors.white,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () =>
                const ShimmerCard(height: 50),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          // Account breakdown
          ref.watch(accountsStreamProvider).when(
                data: (accounts) => Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: accounts.take(3).map((acc) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(acc.emoji,
                              style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(
                            CurrencyFormatter.formatCompact(acc.balance),
                            style: AppTextStyles.caption
                                .copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
        ],
      ),
    ),
  );
}
}
