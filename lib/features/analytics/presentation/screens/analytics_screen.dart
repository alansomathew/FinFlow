import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/analytics_provider.dart';
import '../../../dashboard/providers/dashboard_provider.dart';
import '../../../transactions/domain/models/category_model.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/common_widgets.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Analytics', style: AppTextStyles.headlineMedium),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _YtdStatsCard(),
          SizedBox(height: 16),
          _MonthlyTrendChart(),
          SizedBox(height: 16),
          _BucketSpendingChart(),
          SizedBox(height: 16),
          _NetWorthTrendChart(),
          SizedBox(height: 16),
          _CategoryBreakdownChart(),
          SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _YtdStatsCard extends ConsumerWidget {
  const _YtdStatsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ytdAsync = ref.watch(ytdStatsProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Year to Date', style: AppTextStyles.labelLarge),
          const SizedBox(height: 12),
          ytdAsync.when(
            data: (stats) => Row(
              children: [
                Expanded(
                  child: StatBadge(
                    label: 'Income',
                    value: CurrencyFormatter.formatCompact(
                        stats.totalIncome),
                    color: AppColors.incomeGreen,
                  ),
                ),
                Expanded(
                  child: StatBadge(
                    label: 'Expense',
                    value: CurrencyFormatter.formatCompact(
                        stats.totalExpense),
                    color: AppColors.expenseRed,
                  ),
                ),
                Expanded(
                  child: StatBadge(
                    label: 'Saved',
                    value: CurrencyFormatter.formatCompact(
                        stats.totalSavings),
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            loading: () => const ShimmerCard(height: 60),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _MonthlyTrendChart extends ConsumerWidget {
  const _MonthlyTrendChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendAsync = ref.watch(monthlyTrendProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Monthly Trend', style: AppTextStyles.labelLarge),
          const SizedBox(height: 16),
          trendAsync.when(
            data: (trends) {
              if (trends.isEmpty) {
                return const EmptyStateWidget(
                    message: 'Not enough data yet');
              }
              return SizedBox(
                height: 180,
                child: BarChart(
                  BarChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: AppColors.border, strokeWidth: 0.5),
                    ),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (val, meta) {
                            if (val.toInt() < trends.length) {
                              return Text(
                                trends[val.toInt()]
                                    .monthKey
                                    .substring(5),
                                style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (val, meta) => Text(
                            CurrencyFormatter.formatCompact(val),
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 9),
                          ),
                          reservedSize: 44,
                        ),
                      ),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(trends.length, (i) {
                      final t = trends[i];
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: t.income,
                            color: AppColors.incomeGreen,
                            width: 10,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                          BarChartRodData(
                            toY: t.expense,
                            color: AppColors.expenseRed,
                            width: 10,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              );
            },
            loading: () => const ShimmerCard(height: 180),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _CategoryBreakdownChart extends ConsumerStatefulWidget {
  const _CategoryBreakdownChart();

  @override
  ConsumerState<_CategoryBreakdownChart> createState() => _CategoryBreakdownChartState();
}

class _CategoryBreakdownChartState extends ConsumerState<_CategoryBreakdownChart> {
  AnalyticsTimeframe? _timeframe; // null means Current Month

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<CategoryBreakdown>> breakdownAsync = _timeframe == null
        ? ref.watch(categoryBreakdownProvider)
        : ref.watch(categoryTimeframeExpensesProvider(_timeframe!));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Spending by Category', style: AppTextStyles.labelLarge),
              Text(
                _timeframe == null
                    ? 'Current Month'
                    : _timeframe == AnalyticsTimeframe.lastMonth
                        ? 'Last Month'
                        : _timeframe == AnalyticsTimeframe.last6Months
                            ? 'Last 6 Months'
                            : 'Last 1 Year',
                style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Timeframe selector row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTimeframeChip(null, 'Current'),
                const SizedBox(width: 8),
                _buildTimeframeChip(AnalyticsTimeframe.lastMonth, 'Last Month'),
                const SizedBox(width: 8),
                _buildTimeframeChip(AnalyticsTimeframe.last6Months, 'Last 6M'),
                const SizedBox(width: 8),
                _buildTimeframeChip(AnalyticsTimeframe.lastYear, 'Last 1Y'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          breakdownAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return const EmptyStateWidget(message: 'No expenses for this period');
              }
              final total = items.fold(0.0, (sum, item) => sum + item.amount);
              return Column(
                children: [
                  ...items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Text(item.category.emoji, style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(item.category.name, style: AppTextStyles.bodySmall),
                                      Text(
                                        '${item.percent.toStringAsFixed(1)}%',
                                        style: AppTextStyles.caption.copyWith(color: item.category.color, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: item.percent / 100,
                                      backgroundColor: AppColors.surfaceElevated,
                                      valueColor: AlwaysStoppedAnimation(item.category.color),
                                      minHeight: 6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              CurrencyFormatter.formatCompact(item.amount),
                              style: AppTextStyles.labelSmall,
                            ),
                          ],
                        ),
                      )),
                  const Divider(color: AppColors.border, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Expenses', style: AppTextStyles.labelLarge),
                      Text(
                        CurrencyFormatter.format(total),
                        style: AppTextStyles.labelLarge.copyWith(color: AppColors.expenseRed, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ],
              );
            },
            loading: () => const ShimmerCard(height: 180),
            error: (e, _) => Center(child: Text('Error: $e', style: AppTextStyles.bodyMedium)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframeChip(AnalyticsTimeframe? timeframe, String label) {
    final isSelected = _timeframe == timeframe;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _timeframe = timeframe;
        });
      },
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}

class _BucketSpendingChart extends ConsumerWidget {
  const _BucketSpendingChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breakdownAsync = ref.watch(categoryBreakdownProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('50/30/20 Actual Spending', style: AppTextStyles.labelLarge),
          const SizedBox(height: 16),
          breakdownAsync.when(
            data: (items) {
              double needsSpent = 0;
              double wantsSpent = 0;
              double savingsSpent = 0;

              for (final item in items) {
                switch (item.category.bucket) {
                  case BudgetBucket.needs:
                    needsSpent += item.amount;
                    break;
                  case BudgetBucket.wants:
                    wantsSpent += item.amount;
                    break;
                  case BudgetBucket.savings:
                    savingsSpent += item.amount;
                    break;
                }
              }

              final total = needsSpent + wantsSpent + savingsSpent;
              if (total == 0) {
                return const EmptyStateWidget(message: 'No expenses this month');
              }

              return Row(
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 28,
                        sections: [
                          PieChartSectionData(
                            value: needsSpent,
                            color: AppColors.needsColor,
                            radius: 18,
                            showTitle: false,
                          ),
                          PieChartSectionData(
                            value: wantsSpent,
                            color: AppColors.wantsColor,
                            radius: 18,
                            showTitle: false,
                          ),
                          PieChartSectionData(
                            value: savingsSpent,
                            color: AppColors.savingsColor,
                            radius: 18,
                            showTitle: false,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _BucketStatTile(
                          label: 'Needs (50%)',
                          amount: needsSpent,
                          percent: total > 0 ? (needsSpent / total) * 100 : 0,
                          color: AppColors.needsColor,
                        ),
                        const SizedBox(height: 8),
                        _BucketStatTile(
                          label: 'Wants (30%)',
                          amount: wantsSpent,
                          percent: total > 0 ? (wantsSpent / total) * 100 : 0,
                          color: AppColors.wantsColor,
                        ),
                        const SizedBox(height: 8),
                        _BucketStatTile(
                          label: 'Savings (20%)',
                          amount: savingsSpent,
                          percent: total > 0 ? (savingsSpent / total) * 100 : 0,
                          color: AppColors.savingsColor,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
            loading: () => const ShimmerCard(height: 120),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _BucketStatTile extends StatelessWidget {
  final String label;
  final double amount;
  final double percent;
  final Color color;

  const _BucketStatTile({
    required this.label,
    required this.amount,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ColorDot(color: color, size: 8),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: AppTextStyles.caption),
                  Text(
                    '${percent.toStringAsFixed(1)}%',
                    style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: color),
                  ),
                ],
              ),
              Text(
                CurrencyFormatter.formatCompact(amount),
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NetWorthTrendChart extends ConsumerWidget {
  const _NetWorthTrendChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(netWorthHistoryProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Net Worth History (6 Months)', style: AppTextStyles.labelLarge),
          const SizedBox(height: 16),
          historyAsync.when(
            data: (history) {
              if (history.every((v) => v == 0)) {
                return const EmptyStateWidget(message: 'No net worth history recorded yet');
              }

              return SizedBox(
                height: 180,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: AppColors.border, strokeWidth: 0.5),
                    ),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (val, meta) {
                            final idx = val.toInt();
                            final months = DateFormatter.lastNMonths(6);
                            if (idx >= 0 && idx < months.length) {
                              return Text(
                                DateFormatter.firestoreMonthKey(months[idx]).substring(5),
                                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (val, meta) => Text(
                            CurrencyFormatter.formatCompact(val),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 9,
                            ),
                          ),
                          reservedSize: 44,
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(
                          history.length,
                          (i) => FlSpot(i.toDouble(), history[i]),
                        ),
                        isCurved: true,
                        color: AppColors.primary,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.primary.withOpacity(0.15),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const ShimmerCard(height: 180),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
