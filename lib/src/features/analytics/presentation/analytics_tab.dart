import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';

import '../../../constants/app_theme.dart';
import '../../../constants/app_sizes.dart';
import '../../../services/export_service.dart';
import '../../../services/pro_tier_service.dart';
import '../../../widgets/app_state_message.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../debt/data/debt_repository.dart';
import '../../investments/data/investments_repository.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/domain/transaction.dart';
import '../../budget/data/budget_repository.dart';
import '../data/net_worth_repository.dart';
import '../domain/net_worth_calculator.dart';

const _rangePresets = ['This Month', 'Last 3 Months', 'This Year', 'All Time'];

class AnalyticsTab extends ConsumerStatefulWidget {
  const AnalyticsTab({super.key});

  @override
  ConsumerState<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends ConsumerState<AnalyticsTab> {
  String _rangePreset = 'This Month';
  bool _exporting = false;

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(amount);
  }

  DateTimeRange _resolveRange() {
    final now = DateTime.now();
    switch (_rangePreset) {
      case 'Last 3 Months':
        return DateTimeRange(
          start: DateTime(now.year, now.month - 2, 1),
          end: now,
        );
      case 'This Year':
        return DateTimeRange(start: DateTime(now.year, 1, 1), end: now);
      case 'All Time':
        return DateTimeRange(start: DateTime(2000), end: now);
      case 'This Month':
      default:
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
    }
  }

  List<TransactionModel> _filterByRange(List<TransactionModel> txs) {
    final range = _resolveRange();
    final endExclusive = range.end.add(const Duration(days: 1));
    return txs
        .where(
          (t) => !t.date.isBefore(range.start) && t.date.isBefore(endExclusive),
        )
        .toList();
  }

  Future<void> _handleExport(
    List<TransactionModel> txs,
    Future<void> Function(List<TransactionModel>) exporter,
  ) async {
    setState(() => _exporting = true);
    try {
      await exporter(txs);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final transactionsAsync = ref.watch(transactionListProvider);
    final budgetsAsync = ref.watch(budgetListProvider);
    final isPro = ref.watch(isProProvider).valueOrNull ?? false;

    return Scaffold(
      backgroundColor: colors.background,
      body: transactionsAsync.when(
        data: (allTxs) {
          if (allTxs.isEmpty) {
            return AppStateMessage.empty(
              'No transaction data available for charts.',
              icon: Icons.bar_chart_rounded,
            );
          }

          final txs = _filterByRange(allTxs);

          // Compute 50/30/20 spending ratios over the selected range
          double needs = 0;
          double wants = 0;
          double savings = 0;

          for (var t in txs) {
            if (t.bucket == BudgetBucket.needs) {
              needs += t.amount;
            } else if (t.bucket == BudgetBucket.wants) {
              wants += t.amount;
            } else if (t.bucket == BudgetBucket.savings) {
              savings += t.amount;
            }
          }

          final total = needs + wants + savings;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Exporter Action Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Spend Analytics',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          if (isPro)
                            IconButton(
                              tooltip: 'Export PDF',
                              onPressed: _exporting
                                  ? null
                                  : () => _handleExport(
                                      txs,
                                      ExportService.exportPdf,
                                    ),
                              icon: Icon(
                                Icons.picture_as_pdf_rounded,
                                color: colors.textSecondary,
                              ),
                            ),
                          ElevatedButton.icon(
                            onPressed: _exporting
                                ? null
                                : () => _handleExport(
                                    txs,
                                    ExportService.exportCsv,
                                  ),
                            icon: _exporting
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.download_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                            label: const Text(
                              'Export CSV',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radiusSm,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  AppSizes.h12,

                  // Date range filter
                  SizedBox(
                    height: 32,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _rangePresets.map((preset) {
                        final selected = _rangePreset == preset;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            selected: selected,
                            onSelected: (_) =>
                                setState(() => _rangePreset = preset),
                            label: Text(preset),
                            labelStyle: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : colors.textSecondary,
                              fontSize: 12,
                            ),
                            selectedColor: colors.primary,
                            backgroundColor: colors.cardBg,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  AppSizes.h16,

                  // 50/30/20 Donut Pie Chart Card
                  Card(
                    color: colors.cardBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '50/30/20 Distribution',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          AppSizes.h16,
                          if (total == 0)
                            SizedBox(
                              height: 200,
                              child: Center(
                                child: Text(
                                  'No spending in this period.',
                                  style: TextStyle(color: colors.textSecondary),
                                ),
                              ),
                            )
                          else ...[
                            SizedBox(
                              height: 200,
                              child: PieChart(
                                PieChartData(
                                  sectionsSpace: 4,
                                  centerSpaceRadius: 60,
                                  sections: [
                                    PieChartSectionData(
                                      value: needs,
                                      title:
                                          '${(needs / total * 100).toStringAsFixed(0)}%',
                                      color: colors.needs,
                                      radius: 20,
                                      titleStyle: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    PieChartSectionData(
                                      value: wants,
                                      title:
                                          '${(wants / total * 100).toStringAsFixed(0)}%',
                                      color: colors.wants,
                                      radius: 20,
                                      titleStyle: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    PieChartSectionData(
                                      value: savings,
                                      title:
                                          '${(savings / total * 100).toStringAsFixed(0)}%',
                                      color: colors.savings,
                                      radius: 20,
                                      titleStyle: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            AppSizes.h12,
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildLegendItem(
                                  colors,
                                  'Needs',
                                  _formatCurrency(needs),
                                  colors.needs,
                                ),
                                _buildLegendItem(
                                  colors,
                                  'Wants',
                                  _formatCurrency(wants),
                                  colors.wants,
                                ),
                                _buildLegendItem(
                                  colors,
                                  'Savings',
                                  _formatCurrency(savings),
                                  colors.savings,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  AppSizes.h16,

                  // Budgets vs Spending Bar Chart Card -- always reflects
                  // *this* calendar month's budgets, regardless of the
                  // date-range filter above, since "budget adherence" is
                  // inherently a this-month concept.
                  budgetsAsync.when(
                    data: (budgets) {
                      if (budgets.isEmpty) return const SizedBox.shrink();
                      return _BudgetAdherenceCard(budgets: budgets);
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (e, _) => AppStateMessage.error('$e'),
                  ),

                  if (!isPro) ...[
                    AppSizes.h16,
                    const _AdvancedAnalyticsUpsell(),
                  ] else ...[
                    AppSizes.h16,
                    const _TopCategoriesCard(),
                    AppSizes.h16,
                    const _MonthlyTrendCard(),
                    AppSizes.h16,
                    const _NetWorthTrendCard(),
                  ],
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppStateMessage.error('$e'),
      ),
    );
  }

  Widget _buildLegendItem(
    AppColorExtension colors,
    String title,
    String subtitle,
    Color color,
  ) {
    return Column(
      children: [
        Row(
          children: [
            CircleAvatar(radius: 4, backgroundColor: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(color: colors.textSecondary, fontSize: 11),
            ),
          ],
        ),
        AppSizes.h4,
        Text(
          subtitle,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _BudgetAdherenceCard extends StatelessWidget {
  final List<BudgetModel> budgets;
  const _BudgetAdherenceCard({required this.budgets});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
      color: colors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Budget Adherence by Envelope (This Month)',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            AppSizes.h24,
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, meta) {
                          final idx = val.toInt();
                          if (idx < 0 || idx >= budgets.length) {
                            return Container();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              budgets[idx].category.substring(
                                0,
                                min(budgets[idx].category.length, 4),
                              ),
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 9,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(budgets.length, (idx) {
                    final b = budgets[idx];
                    return BarChartGroupData(
                      x: idx,
                      barRods: [
                        BarChartRodData(
                          toY: b.spentAmount,
                          color: colors.primary,
                          width: 8,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        BarChartRodData(
                          toY: b.limitAmount,
                          color: colors.border,
                          width: 8,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
            AppSizes.h8,
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(radius: 4, backgroundColor: colors.primary),
                const SizedBox(width: 6),
                Text(
                  'Spent',
                  style: TextStyle(color: colors.textSecondary, fontSize: 10),
                ),
                const SizedBox(width: 16),
                CircleAvatar(radius: 4, backgroundColor: colors.border),
                const SizedBox(width: 6),
                Text(
                  'Limit',
                  style: TextStyle(color: colors.textSecondary, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdvancedAnalyticsUpsell extends StatelessWidget {
  const _AdvancedAnalyticsUpsell();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: colors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            color: colors.warning,
            size: 20,
          ),
          AppSizes.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pro Analytics',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                AppSizes.h8,
                Text(
                  'Upgrade to Pro for top-category breakdowns, a 6-month income vs. expense trend, PDF export, and a net worth tracker.',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
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

class _TopCategoriesCard extends ConsumerWidget {
  const _TopCategoriesCard();

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(amount);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final transactionsAsync = ref.watch(transactionListProvider);
    return transactionsAsync.when(
      data: (txs) {
        final byCategory = <String, double>{};
        for (final t in txs) {
          if (t.bucket == BudgetBucket.income) continue;
          byCategory[t.category] = (byCategory[t.category] ?? 0) + t.amount;
        }
        final sorted = byCategory.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final top = sorted.take(6).toList();
        if (top.isEmpty) return const SizedBox.shrink();
        final maxVal = top.first.value;

        return Card(
          color: colors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Top Spending Categories (All Time)',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                AppSizes.h16,
                ...top.map((e) {
                  final cat = TransactionCategory.getByName(e.key);
                  final ratio = maxVal > 0 ? e.value / maxVal : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${cat.icon} ${e.key}',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _formatCurrency(e.value),
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        AppSizes.h4,
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: ratio,
                            backgroundColor: colors.border,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              cat.bucket.color,
                            ),
                            minHeight: 5,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, _) => AppStateMessage.error('$e'),
    );
  }
}

class _MonthlyTrendCard extends ConsumerWidget {
  const _MonthlyTrendCard();

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(amount);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final transactionsAsync = ref.watch(transactionListProvider);
    return transactionsAsync.when(
      data: (txs) {
        final now = DateTime.now();
        final months = List.generate(6, (i) {
          final d = DateTime(now.year, now.month - (5 - i), 1);
          return d;
        });

        final income = <double>[];
        final expense = <double>[];
        for (final month in months) {
          double inc = 0, exp = 0;
          for (final t in txs) {
            if (t.date.year == month.year && t.date.month == month.month) {
              if (t.bucket == BudgetBucket.income) {
                inc += t.amount;
              } else {
                exp += t.amount;
              }
            }
          }
          income.add(inc);
          expense.add(exp);
        }

        final maxY = [...income, ...expense].fold(0.0, (m, v) => v > m ? v : m);

        return Card(
          color: colors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Income vs Expense (6 Months)',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                AppSizes.h24,
                SizedBox(
                  height: 200,
                  child: maxY == 0
                      ? Center(
                          child: Text(
                            'No data in this period.',
                            style: TextStyle(color: colors.textSecondary),
                          ),
                        )
                      : BarChart(
                          BarChartData(
                            maxY: maxY * 1.15,
                            borderData: FlBorderData(show: false),
                            gridData: const FlGridData(show: false),
                            titlesData: FlTitlesData(
                              show: true,
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              leftTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (val, meta) {
                                    final idx = val.toInt();
                                    if (idx < 0 || idx >= months.length) {
                                      return Container();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        DateFormat('MMM').format(months[idx]),
                                        style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 9,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            barGroups: List.generate(months.length, (idx) {
                              return BarChartGroupData(
                                x: idx,
                                barRods: [
                                  BarChartRodData(
                                    toY: income[idx],
                                    color: colors.success,
                                    width: 8,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  BarChartRodData(
                                    toY: expense[idx],
                                    color: colors.error,
                                    width: 8,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                ),
                AppSizes.h8,
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(radius: 4, backgroundColor: colors.success),
                    const SizedBox(width: 6),
                    Text(
                      'Income',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(width: 16),
                    CircleAvatar(radius: 4, backgroundColor: colors.error),
                    const SizedBox(width: 6),
                    Text(
                      'Expense',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                if (maxY > 0) ...[
                  AppSizes.h4,
                  Center(
                    child: Text(
                      'Net this month: ${_formatCurrency(income.last - expense.last)}',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, _) => AppStateMessage.error('$e'),
    );
  }
}

class _NetWorthTrendCard extends ConsumerStatefulWidget {
  const _NetWorthTrendCard();

  @override
  ConsumerState<_NetWorthTrendCard> createState() => _NetWorthTrendCardState();
}

class _NetWorthTrendCardState extends ConsumerState<_NetWorthTrendCard> {
  Future<List<NetWorthHistoryPoint>>? _historyFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recordAndLoad());
  }

  Future<void> _recordAndLoad() async {
    if (!mounted) return;
    final accounts = await ref.read(accountsRepositoryProvider).getAccounts();
    final investments = await ref
        .read(investmentsRepositoryProvider)
        .getInvestments();
    final loans = await ref.read(debtRepositoryProvider).getLoans();
    final totals = NetWorthCalculator.compute(
      accounts: accounts,
      investments: investments,
      loans: loans,
    );
    final repo = ref.read(netWorthRepositoryProvider);
    await repo.recordTodaySnapshot(totals);
    if (!mounted) return;
    setState(() => _historyFuture = repo.getHistory());
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
      color: colors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Net Worth Trend',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            AppSizes.h4,
            Text(
              'Recorded once per day you open this screen -- history starts building from today.',
              style: TextStyle(color: colors.textMuted, fontSize: 10),
            ),
            AppSizes.h16,
            SizedBox(
              height: 180,
              child: _historyFuture == null
                  ? const Center(child: CircularProgressIndicator())
                  : FutureBuilder<List<NetWorthHistoryPoint>>(
                      future: _historyFuture,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final points = snapshot.data!;
                        if (points.length < 2) {
                          return Center(
                            child: Text(
                              points.isEmpty
                                  ? 'No net worth history yet.'
                                  : 'Today\'s net worth: ${_formatCurrency(points.first.netWorth)}\nCheck back tomorrow to see a trend.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }
                        return LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            titlesData: const FlTitlesData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: [
                                  for (var i = 0; i < points.length; i++)
                                    FlSpot(i.toDouble(), points[i].netWorth),
                                ],
                                isCurved: true,
                                color: colors.primary,
                                barWidth: 3,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: colors.primary.withValues(alpha: 0.12),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
