import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/budget_provider.dart';
import '../../domain/models/budget_model.dart';
import '../../../transactions/domain/models/category_model.dart';
import '../../../transactions/presentation/providers/category_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/ai/gemini_api.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetAsync = ref.watch(budgetWithSpendingProvider);
    final bucketAsync = ref.watch(bucketSummaryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Budget', style: AppTextStyles.headlineMedium),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => _showBudgetSetupSheet(context, ref),
          ),
        ],
      ),
      body: budgetAsync.when(
        data: (budget) {
          if (budget == null) {
            return _NoBudgetView(
              onSetup: () => _showBudgetSetupSheet(context, ref),
            );
          }
          return _BudgetContent(
              budget: budget, bucketAsync: bucketAsync);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Error: $e', style: AppTextStyles.bodyMedium)),
      ),
    );
  }

  void _showBudgetSetupSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _BudgetSetupSheet(),
    );
  }
}


class _BudgetContent extends ConsumerWidget {
  final BudgetModel budget;
  final AsyncValue<BucketSummary> bucketAsync;

  const _BudgetContent({required this.budget, required this.bucketAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allCats = ref.watch(allCategoriesProvider);
    final List<BudgetCategory> mergedCategories = [];
    
    for (final cat in allCats) {
      if (cat.group == CategoryGroup.income) continue; // no budgets for income
      
      final existing = budget.categories.firstWhere(
        (c) => c.categoryId == cat.id,
        orElse: () => BudgetCategory(categoryId: cat.id, allocated: 0, spent: 0),
      );
      mergedCategories.add(existing);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        // AI Insight
        bucketAsync.when(
          data: (b) => Column(
            children: [
              _AIInsightWidget(
                needs: b.needsSpent,
                wants: b.wantsSpent,
                savings: b.savingsSpent,
                income: budget.monthlyIncome,
              ),
              const SizedBox(height: 16),
              _BudgetComparisonChart(bucket: b),
              const SizedBox(height: 16),
              _BucketDonut(bucket: b),
            ],
          ),
          loading: () => const ShimmerCard(height: 220),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 24),
        
        // Category list grouped by rule bucket
        for (final bucket in BudgetBucket.values)
          _BucketSection(
            bucket: bucket,
            budget: budget,
            categories: mergedCategories
                .where((c) =>
                    CategoryModel.byId(c.categoryId).bucket == bucket && c.spent > 0)
                .toList(),
          ),
      ],
    );
  }
}

class _BudgetComparisonChart extends StatelessWidget {
  final BucketSummary bucket;

  const _BudgetComparisonChart({required this.bucket});

  @override
  Widget build(BuildContext context) {
    final double maxVal = [
      bucket.needsAllocated,
      bucket.needsSpent,
      bucket.wantsAllocated,
      bucket.wantsSpent,
      bucket.savingsAllocated,
      bucket.savingsSpent,
      1000.0
    ].reduce((curr, next) => curr > next ? curr : next);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Target vs. Actual Spent', style: AppTextStyles.labelLarge),
              Row(
                children: [
                  const ColorDot(color: AppColors.primary, size: 8),
                  const SizedBox(width: 4),
                  Text('Target', style: AppTextStyles.caption),
                  const SizedBox(width: 12),
                  const ColorDot(color: AppColors.accent, size: 8),
                  const SizedBox(width: 4),
                  Text('Spent', style: AppTextStyles.caption),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: maxVal * 1.15,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (val) => FlLine(
                    color: AppColors.border.withOpacity(0.4),
                    strokeWidth: 0.5,
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        switch (val.toInt()) {
                          case 0:
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text('Needs', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                            );
                          case 1:
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text('Wants', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                            );
                          case 2:
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text('Savings', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                            );
                          default:
                            return const SizedBox.shrink();
                        }
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) => Text(
                        CurrencyFormatter.formatCompact(val),
                        style: AppTextStyles.caption.copyWith(fontSize: 9, color: AppColors.textSecondary),
                      ),
                      reservedSize: 44,
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  _buildBarGroup(0, bucket.needsAllocated, bucket.needsSpent, AppColors.needsColor),
                  _buildBarGroup(1, bucket.wantsAllocated, bucket.wantsSpent, AppColors.wantsColor),
                  _buildBarGroup(2, bucket.savingsAllocated, bucket.savingsSpent, AppColors.savingsColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, double target, double spent, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: target,
          color: AppColors.primary.withOpacity(0.8),
          width: 12,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
        BarChartRodData(
          toY: spent,
          color: spent > target ? AppColors.expenseRed : AppColors.accent,
          width: 12,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ],
    );
  }
}

class _AIInsightWidget extends StatefulWidget {
  final double needs, wants, savings, income;
  const _AIInsightWidget({required this.needs, required this.wants, required this.savings, required this.income});
  @override
  State<_AIInsightWidget> createState() => _AIInsightWidgetState();
}

class _AIInsightWidgetState extends State<_AIInsightWidget> {
  String? _insight;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchInsight();
  }

  Future<void> _fetchInsight() async {
    setState(() => _loading = true);
    final result = await GeminiAI.spendingInsight(
      needs: widget.needs,
      wants: widget.wants,
      savings: widget.savings,
      income: widget.income,
    );
    setState(() {
      _insight = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ShimmerCard(height: 60);
    }
    if (_insight != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.withOpacity(0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.auto_awesome, color: Colors.amber, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Financial Insight', style: AppTextStyles.labelMedium.copyWith(color: Colors.amber)),
                  const SizedBox(height: 4),
                  Text(_insight!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _BucketDonut extends StatelessWidget {
  final BucketSummary bucket;

  const _BucketDonut({required this.bucket});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 28,
                sections: [
                  PieChartSectionData(
                    value: bucket.needsAllocated,
                    color: AppColors.needsColor,
                    radius: 16,
                    showTitle: false,
                  ),
                  PieChartSectionData(
                    value: bucket.wantsAllocated,
                    color: AppColors.wantsColor,
                    radius: 16,
                    showTitle: false,
                  ),
                  PieChartSectionData(
                    value: bucket.savingsAllocated,
                    color: AppColors.savingsColor,
                    radius: 16,
                    showTitle: false,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BucketLegend(
                  label: 'Needs (50%) Target',
                  spent: bucket.needsSpent,
                  allocated: bucket.needsAllocated,
                  color: AppColors.needsColor,
                ),
                const SizedBox(height: 8),
                _BucketLegend(
                  label: 'Wants (30%) Target',
                  spent: bucket.wantsSpent,
                  allocated: bucket.wantsAllocated,
                  color: AppColors.wantsColor,
                ),
                const SizedBox(height: 8),
                _BucketLegend(
                  label: 'Savings (20%) Target',
                  spent: bucket.savingsSpent,
                  allocated: bucket.savingsAllocated,
                  color: AppColors.savingsColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BucketLegend extends StatelessWidget {
  final String label;
  final double spent;
  final double allocated;
  final Color color;

  const _BucketLegend({
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
          children: [
            ColorDot(color: color, size: 8),
            const SizedBox(width: 6),
            Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        BudgetProgressBar(spent: spent, total: allocated, color: color),
        Text(
          '${CurrencyFormatter.formatCompact(spent)} spent of ${CurrencyFormatter.formatCompact(allocated)}',
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _BucketSection extends StatelessWidget {
  final BudgetBucket bucket;
  final BudgetModel budget;
  final List<BudgetCategory> categories;

  const _BucketSection(
      {required this.bucket, required this.budget, required this.categories});

  @override
  Widget build(BuildContext context) {
    final label = bucket == BudgetBucket.needs
        ? 'Needs Spending'
        : bucket == BudgetBucket.wants
            ? 'Wants Spending'
            : 'Savings & Investments';
    final color = bucket == BudgetBucket.needs
        ? AppColors.needsColor
        : bucket == BudgetBucket.wants
            ? AppColors.wantsColor
            : AppColors.savingsColor;

    if (categories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              ColorDot(color: color, size: 8),
              const SizedBox(width: 8),
              Text(label,
                  style: AppTextStyles.labelLarge.copyWith(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        ...categories.map((cat) => _CategoryBudgetTile(
              budgetCategory: cat,
              budget: budget,
            )),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _CategoryBudgetTile extends StatelessWidget {
  final BudgetCategory budgetCategory;
  final BudgetModel budget;

  const _CategoryBudgetTile({required this.budgetCategory, required this.budget});

  @override
  Widget build(BuildContext context) {
    final cat = CategoryModel.byId(budgetCategory.categoryId);
    final percentOfIncome = budget.monthlyIncome > 0
        ? (budgetCategory.spent / budget.monthlyIncome) * 100
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(cat.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cat.name, style: AppTextStyles.bodyMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${percentOfIncome.toStringAsFixed(1)}% of total income',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                Text(
                  CurrencyFormatter.format(budgetCategory.spent),
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoBudgetView extends StatelessWidget {
  final VoidCallback onSetup;

  const _NoBudgetView({required this.onSetup});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📊', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('No Budget Set',
                style: AppTextStyles.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Set up your monthly budget to track the 50/30/20 rule',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GradientButton(
                label: 'Set Up Budget', onTap: onSetup),
          ],
        ),
      ),
    );
  }
}

class _BudgetSetupSheet extends ConsumerStatefulWidget {
  const _BudgetSetupSheet();

  @override
  ConsumerState<_BudgetSetupSheet> createState() =>
      _BudgetSetupSheetState();
}

class _BudgetSetupSheetState
    extends ConsumerState<_BudgetSetupSheet> {
  final _incomeController = TextEditingController();

  @override
  void dispose() {
    _incomeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Set Monthly Budget',
              style: AppTextStyles.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Enter your monthly income and we\'ll auto-calculate the 50/30/20 split.',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _incomeController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Monthly Income',
              prefixText: '₹ ',
            ),
          ),
          const SizedBox(height: 24),
          GradientButton(
            label: 'Create 50/30/20 Budget',
            onTap: _createBudget,
          ),
        ],
      ),
    );
  }

  Future<void> _createBudget() async {
    final income = double.tryParse(
            _incomeController.text.replaceAll(',', '')) ??
        0;
    if (income <= 0) return;

    final now = DateTime.now();
    final budget = BudgetModel.from5030_20(
      userId: '',
      monthKey: '${now.year}-${now.month.toString().padLeft(2, '0')}',
      income: income,
      resetDate: DateTime(now.year, now.month, 1),
    );

    await ref
        .read(budgetNotifierProvider.notifier)
        .createOrUpdateBudget(budget);

    if (mounted) Navigator.pop(context);
  }
}
