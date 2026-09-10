import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_sizes.dart';
import '../../transactions/domain/transaction.dart';
import '../data/budget_repository.dart';

class BudgetTab extends ConsumerStatefulWidget {
  const BudgetTab({super.key});

  @override
  ConsumerState<BudgetTab> createState() => _BudgetTabState();
}

class _BudgetTabState extends ConsumerState<BudgetTab> {
  // Format currency
  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(amount);
  }

  // Determine progress bar color
  Color _getProgressColor(double ratio) {
    if (ratio >= 1.0) return AppColors.error;
    if (ratio >= 0.8) return AppColors.warning;
    return AppColors.success;
  }

  // Envelope Transfer Dialog
  void _showTransferDialog(BuildContext context, List<BudgetModel> budgets) {
    if (budgets.length < 2) return;
    
    BudgetModel source = budgets.first;
    BudgetModel destination = budgets[1];
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMd)),
              title: const Text('Envelope Transfer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Move money from one budget envelope to another.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  AppSizes.h12,
                  
                  // Source Dropdown
                  DropdownButtonFormField<BudgetModel>(
                    value: source,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'From (Source Envelope)', labelStyle: TextStyle(color: AppColors.textSecondary)),
                    items: budgets.map((b) {
                      return DropdownMenuItem<BudgetModel>(
                        value: b,
                        child: Text('${b.category} (Limit: ₹${b.limitAmount.toStringAsFixed(0)})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setStateDialog(() {
                          source = val;
                        });
                      }
                    },
                  ),
                  AppSizes.h12,

                  // Destination Dropdown
                  DropdownButtonFormField<BudgetModel>(
                    value: destination,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'To (Destination Envelope)', labelStyle: TextStyle(color: AppColors.textSecondary)),
                    items: budgets.where((b) => b.category != source.category).map((b) {
                      return DropdownMenuItem<BudgetModel>(
                        value: b,
                        child: Text(b.category),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setStateDialog(() {
                          destination = val;
                        });
                      }
                    },
                  ),
                  AppSizes.h12,

                  // Amount
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Transfer Amount',
                      labelStyle: const TextStyle(color: AppColors.textSecondary),
                      fillColor: AppColors.cardBg,
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.radiusSm), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final transferAmount = double.tryParse(amountController.text) ?? 0.0;
                    if (transferAmount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
                      return;
                    }
                    if (source.limitAmount < transferAmount) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insufficient funds in source envelope')));
                      return;
                    }

                    // Process envelopes limit modification
                    final notifier = ref.read(budgetListProvider.notifier);
                    await notifier.setLimit(source.category, source.limitAmount - transferAmount, source.spentAmount, source.monthYear);
                    await notifier.setLimit(destination.category, destination.limitAmount + transferAmount, destination.spentAmount, destination.monthYear);

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Transferred ${_formatCurrency(transferAmount)} from ${source.category} to ${destination.category}'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text('Transfer', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final budgetsAsync = ref.watch(budgetListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: budgetsAsync.when(
        data: (budgets) {
          if (budgets.isEmpty) {
            return const Center(child: Text('No budgets defined.', style: TextStyle(color: AppColors.textSecondary)));
          }

          // Calculate totals per 50/30/20 buckets
          double needsLimit = 0, needsSpent = 0;
          double wantsLimit = 0, wantsSpent = 0;
          double savingsLimit = 0, savingsSpent = 0;

          for (var b in budgets) {
            final cat = TransactionCategory.getByName(b.category);
            if (cat.bucket == BudgetBucket.needs) {
              needsLimit += b.limitAmount;
              needsSpent += b.spentAmount;
            } else if (cat.bucket == BudgetBucket.wants) {
              wantsLimit += b.limitAmount;
              wantsSpent += b.spentAmount;
            } else if (cat.bucket == BudgetBucket.savings) {
              savingsLimit += b.limitAmount;
              savingsSpent += b.spentAmount;
            }
          }

          final totalLimit = needsLimit + wantsLimit + savingsLimit;

          return Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Action Toolbar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Budget Limit', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        Text(_formatCurrency(totalLimit), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showTransferDialog(context, budgets),
                      icon: const Icon(Icons.compare_arrows_rounded, color: Colors.white, size: 18),
                      label: const Text('Transfer', style: TextStyle(color: Colors.white, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusSm)),
                      ),
                    ),
                  ],
                ),
                AppSizes.h16,

                // 50/30/20 Split Progress Row
                Card(
                  color: AppColors.cardBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMd)),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('50/30/20 Allocations', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        AppSizes.h12,
                        
                        // Needs Row (50%)
                        _buildBucketAllocationRow('Needs (50%)', needsSpent, needsLimit, AppColors.needs),
                        AppSizes.h8,
                        // Wants Row (30%)
                        _buildBucketAllocationRow('Wants (30%)', wantsSpent, wantsLimit, AppColors.wants),
                        AppSizes.h8,
                        // Savings Row (20%)
                        _buildBucketAllocationRow('Savings (20%)', savingsSpent, savingsLimit, AppColors.savings),
                      ],
                    ),
                  ),
                ),
                AppSizes.h16,

                const Text('Category Envelopes', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                AppSizes.h8,

                // List of category envelopes
                Expanded(
                  child: ListView.builder(
                    itemCount: budgets.length,
                    itemBuilder: (context, index) {
                      final b = budgets[index];
                      final cat = TransactionCategory.getByName(b.category);
                      final ratio = b.limitAmount > 0 ? (b.spentAmount / b.limitAmount) : 0.0;
                      final progressColor = _getProgressColor(ratio);

                      return Card(
                        color: AppColors.cardBg,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSizes.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Text(cat.icon, style: const TextStyle(fontSize: 20)),
                                  AppSizes.w8,
                                  Text(b.category, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                  const Spacer(),
                                  Text(
                                    '${_formatCurrency(b.spentAmount)} / ${_formatCurrency(b.limitAmount)}',
                                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              AppSizes.h8,
                              // Progress Bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: ratio.clamp(0.0, 1.0),
                                  backgroundColor: AppColors.border,
                                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                                  minHeight: 6,
                                ),
                              ),
                              AppSizes.h4,
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(cat.bucket.displayName, style: TextStyle(color: cat.bucket.color, fontSize: 10, fontWeight: FontWeight.bold)),
                                  Text(
                                    ratio >= 1.0
                                        ? 'Exceeded by ${_formatCurrency(b.spentAmount - b.limitAmount)}'
                                        : '₹${(b.limitAmount - b.spentAmount).toStringAsFixed(0)} left',
                                    style: TextStyle(color: ratio >= 1.0 ? AppColors.error : AppColors.textSecondary, fontSize: 10),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildBucketAllocationRow(String title, double spent, double limit, Color color) {
    final ratio = limit > 0 ? (spent / limit) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            Text('${_formatCurrency(spent)} / ${_formatCurrency(limit)}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
        AppSizes.h4,
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}
