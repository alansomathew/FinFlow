import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:math';

import '../../../constants/app_colors.dart';
import '../../../constants/app_sizes.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/domain/transaction.dart';
import '../../budget/data/budget_repository.dart';

class AnalyticsTab extends ConsumerWidget {
  const AnalyticsTab({super.key});

  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(amount);
  }

  // Exports all transactions to a CSV file in the docs directory
  Future<void> _exportCsvLedger(BuildContext context, List<TransactionModel> txs) async {
    try {
      final buffer = StringBuffer();
      // CSV Headers
      buffer.writeln("Transaction ID,Date,Payee/Merchant,Category,Bucket,Amount,Note,Reference ID");
      
      for (var t in txs) {
        final dateStr = DateFormat('yyyy-MM-dd').format(t.date);
        final escapedPayee = t.payee.replaceAll('"', '""');
        final escapedNote = t.note.replaceAll('"', '""');
        buffer.writeln(
          '"${t.id}","$dateStr","$escapedPayee","${t.category}","${t.bucket.displayName}",${t.amount},"$escapedNote","${t.refId}"'
        );
      }

      final docsDir = Directory("d:\\FinFlow\\docs");
      if (!docsDir.existsSync()) {
        docsDir.createSync(recursive: true);
      }
      
      final exportFile = File("d:\\FinFlow\\docs\\FinFlow_Ledger_Export.csv");
      await exportFile.writeAsString(buffer.toString());

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ledger successfully exported to ${exportFile.path}!'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionListProvider);
    final budgetsAsync = ref.watch(budgetListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: transactionsAsync.when(
        data: (txs) {
          if (txs.isEmpty) {
            return const Center(
              child: Text(
                'No transaction data available for charts.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          // Compute 50/30/20 spending ratios
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
                      const Text(
                        'Spend Analytics',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _exportCsvLedger(context, txs),
                        icon: const Icon(Icons.download_rounded, color: Colors.white, size: 16),
                        label: const Text('Export CSV', style: TextStyle(color: Colors.white, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusSm)),
                        ),
                      ),
                    ],
                  ),
                  AppSizes.h16,

                  // 50/30/20 Donut Pie Chart Card
                  Card(
                    color: AppColors.cardBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMd)),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            '50/30/20 Distribution',
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          AppSizes.h16,
                          if (total == 0)
                            const SizedBox(
                              height: 200,
                              child: Center(
                                child: Text('Add expense items to view allocations.', style: TextStyle(color: AppColors.textSecondary)),
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
                                      title: '${(needs / total * 100).toStringAsFixed(0)}%',
                                      color: AppColors.needs,
                                      radius: 20,
                                      titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    PieChartSectionData(
                                      value: wants,
                                      title: '${(wants / total * 100).toStringAsFixed(0)}%',
                                      color: AppColors.wants,
                                      radius: 20,
                                      titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    PieChartSectionData(
                                      value: savings,
                                      title: '${(savings / total * 100).toStringAsFixed(0)}%',
                                      color: AppColors.savings,
                                      radius: 20,
                                      titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            AppSizes.h12,
                            // Legends Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildLegendItem('Needs', _formatCurrency(needs), AppColors.needs),
                                _buildLegendItem('Wants', _formatCurrency(wants), AppColors.wants),
                                _buildLegendItem('Savings', _formatCurrency(savings), AppColors.savings),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  AppSizes.h16,

                  // Budgets vs Spending Bar Chart Card
                  budgetsAsync.when(
                    data: (budgets) {
                      if (budgets.isEmpty) return Container();

                      return Card(
                        color: AppColors.cardBg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMd)),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSizes.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Budget Adherence by Envelope',
                                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
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
                                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (val, meta) {
                                            final idx = val.toInt();
                                            if (idx < 0 || idx >= budgets.length) return Container();
                                            return Padding(
                                              padding: const EdgeInsets.only(top: 6),
                                              child: Text(
                                                budgets[idx].category.substring(0, min(budgets[idx].category.length, 4)),
                                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 9),
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
                                            color: AppColors.primary,
                                            width: 8,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                          BarChartRodData(
                                            toY: b.limitAmount,
                                            color: AppColors.border,
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
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircleAvatar(radius: 4, backgroundColor: AppColors.primary),
                                  SizedBox(width: 6),
                                  Text('Spent', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                                  SizedBox(width: 16),
                                  CircleAvatar(radius: 4, backgroundColor: AppColors.border),
                                  SizedBox(width: 6),
                                  Text('Limit', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    loading: () => Container(),
                    error: (_, __) => Container(),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildLegendItem(String title, String subtitle, Color color) {
    return Column(
      children: [
        Row(
          children: [
            CircleAvatar(radius: 4, backgroundColor: color),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
        AppSizes.h4,
        Text(subtitle, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
