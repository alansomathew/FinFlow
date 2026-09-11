import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_sizes.dart';
import '../../../constants/app_theme.dart';
import '../../transactions/domain/transaction.dart';
import '../data/budget_repository.dart';
import 'salary_budget_planner_sheet.dart';

class BudgetTab extends ConsumerStatefulWidget {
  const BudgetTab({super.key});

  @override
  ConsumerState<BudgetTab> createState() => _BudgetTabState();
}

class _BudgetTabState extends ConsumerState<BudgetTab> {
  // Format currency
  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(amount);
  }

  // Determine progress bar color
  Color _getProgressColor(double ratio) {
    final colors = context.colors;
    if (ratio >= 1.0) return colors.error;
    if (ratio >= 0.8) return colors.warning;
    return colors.success;
  }

  // Envelope Transfer Dialog
  void _showTransferDialog(BuildContext context, List<BudgetModel> budgets) {
    if (budgets.length < 2) return;
    final colors = context.colors;

    BudgetModel source = budgets.first;
    BudgetModel destination = budgets[1];
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final crossBucket =
                TransactionCategory.getByName(source.category).bucket !=
                TransactionCategory.getByName(destination.category).bucket;

            return AlertDialog(
              backgroundColor: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              title: const Text(
                'Envelope Transfer',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Move money from one budget envelope to another.',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                  AppSizes.h12,

                  // Source Dropdown
                  DropdownButtonFormField<BudgetModel>(
                    value: source,
                    dropdownColor: colors.surface,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'From (Source Envelope)',
                      labelStyle: TextStyle(color: colors.textSecondary),
                    ),
                    items: budgets.map((b) {
                      return DropdownMenuItem<BudgetModel>(
                        value: b,
                        child: Text(
                          '${b.category} (Limit: ₹${b.limitAmount.toStringAsFixed(0)})',
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setStateDialog(() {
                          source = val;
                          if (destination.category == source.category) {
                            destination = budgets.firstWhere(
                              (b) => b.category != source.category,
                              orElse: () => destination,
                            );
                          }
                        });
                      }
                    },
                  ),
                  AppSizes.h12,

                  // Destination Dropdown
                  DropdownButtonFormField<BudgetModel>(
                    value: destination,
                    dropdownColor: colors.surface,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'To (Destination Envelope)',
                      labelStyle: TextStyle(color: colors.textSecondary),
                    ),
                    items: budgets
                        .where((b) => b.category != source.category)
                        .map((b) {
                          return DropdownMenuItem<BudgetModel>(
                            value: b,
                            child: Text(b.category),
                          );
                        })
                        .toList(),
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
                      labelStyle: TextStyle(color: colors.textSecondary),
                      fillColor: colors.cardBg,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  if (crossBucket) ...[
                    AppSizes.h12,
                    Container(
                      padding: const EdgeInsets.all(AppSizes.sm),
                      decoration: BoxDecoration(
                        color: colors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                        border: Border.all(
                          color: colors.warning.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: colors.warning,
                            size: 18,
                          ),
                          AppSizes.w8,
                          Expanded(
                            child: Text(
                              'Cross-bucket transfer: moving money from '
                              '${TransactionCategory.getByName(source.category).bucket.displayName} '
                              'into ${TransactionCategory.getByName(destination.category).bucket.displayName} '
                              'shifts your 50/30/20 split.',
                              style: TextStyle(
                                color: colors.warning,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final transferAmount =
                        double.tryParse(amountController.text) ?? 0.0;
                    if (transferAmount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter a valid amount')),
                      );
                      return;
                    }
                    if (source.limitAmount < transferAmount) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Insufficient funds in source envelope',
                          ),
                        ),
                      );
                      return;
                    }

                    // Process envelopes limit modification
                    final notifier = ref.read(budgetListProvider.notifier);
                    await notifier.setLimit(
                      source.category,
                      source.limitAmount - transferAmount,
                      source.monthYear,
                      rolloverEnabled: source.rolloverEnabled,
                    );
                    await notifier.setLimit(
                      destination.category,
                      destination.limitAmount + transferAmount,
                      destination.monthYear,
                      rolloverEnabled: destination.rolloverEnabled,
                    );

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Transferred ${_formatCurrency(transferAmount)} from ${source.category} to ${destination.category}',
                          ),
                          backgroundColor: colors.success,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                  ),
                  child: const Text(
                    'Transfer',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSalaryPlannerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const SalaryBudgetPlannerSheet(),
    );
  }

  // Create a new category envelope for the current month
  void _showAddBudgetDialog(BuildContext context, List<BudgetModel> budgets) {
    final budgetedCategories = budgets.map((b) => b.category).toSet();
    final available = TransactionCategory.presets
        .where(
          (c) =>
              c.bucket != BudgetBucket.income &&
              !budgetedCategories.contains(c.name),
        )
        .toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Every spending category already has a budget'),
        ),
      );
      return;
    }

    TransactionCategory selected = available.first;
    final limitController = TextEditingController();
    final monthYear = budgets.isNotEmpty
        ? budgets.first.monthYear
        : DateTime.now().toIso8601String().substring(0, 7);
    final colors = context.colors;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              title: const Text(
                'New Budget Envelope',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<TransactionCategory>(
                    value: selected,
                    dropdownColor: colors.surface,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Category',
                      labelStyle: TextStyle(color: colors.textSecondary),
                    ),
                    items: available.map((c) {
                      return DropdownMenuItem<TransactionCategory>(
                        value: c,
                        child: Text('${c.icon}  ${c.name}'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setStateDialog(() => selected = val);
                      }
                    },
                  ),
                  AppSizes.h12,
                  TextField(
                    controller: limitController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Monthly Limit',
                      labelStyle: TextStyle(color: colors.textSecondary),
                      fillColor: colors.cardBg,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final limit = double.tryParse(limitController.text) ?? 0.0;
                    if (limit <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter a valid limit')),
                      );
                      return;
                    }
                    await ref
                        .read(budgetListProvider.notifier)
                        .setLimit(selected.name, limit, monthYear);
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                  ),
                  child: const Text(
                    'Create',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Edit or delete an existing envelope
  void _showEditBudgetDialog(BuildContext context, BudgetModel budget) {
    final limitController = TextEditingController(
      text: budget.limitAmount.toStringAsFixed(0),
    );
    final colors = context.colors;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          title: Text(
            'Edit ${budget.category}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: limitController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Monthly Limit',
              labelStyle: TextStyle(color: colors.textSecondary),
              fillColor: colors.cardBg,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await ref
                    .read(budgetListProvider.notifier)
                    .remove(budget.category, budget.monthYear);
              },
              child: Text('Delete', style: TextStyle(color: colors.error)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final limit = double.tryParse(limitController.text) ?? 0.0;
                if (limit <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a valid limit')),
                  );
                  return;
                }
                await ref
                    .read(budgetListProvider.notifier)
                    .setLimit(
                      budget.category,
                      limit,
                      budget.monthYear,
                      rolloverEnabled: budget.rolloverEnabled,
                    );
                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: colors.primary),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // Monthly History: pick a past month, view its (read-only) envelopes
  void _showHistorySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      // Transparent here, not colors.surface -- showModalBottomSheet's
      // backgroundColor is fixed at call time, not re-evaluated inside
      // builder, so it wouldn't track a live theme change. The Material
      // below paints the real surface color reactively instead -- a plain
      // Container/DecoratedBox would hide the ListTiles' background/ink
      // splashes, which paint on the nearest Material ancestor.
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final colors = context.colors;
        return Material(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSizes.radiusMd),
          ),
          clipBehavior: Clip.antiAlias,
          child: FutureBuilder<List<String>>(
            future: ref.read(budgetRepositoryProvider).getAvailableMonths(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final months = snapshot.data!;
              if (months.isEmpty) {
                return SizedBox(
                  height: 120,
                  child: Center(
                    child: Text(
                      'No budget history yet.',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ),
                );
              }
              return SafeArea(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(AppSizes.md),
                  itemCount: months.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: AppSizes.sm),
                        child: Text(
                          'Monthly History',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }
                    final month = months[index - 1];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        month,
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: colors.textSecondary,
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _showMonthDetailSheet(context, month);
                      },
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showMonthDetailSheet(BuildContext context, String monthYear) {
    showModalBottomSheet(
      context: context,
      // Transparent here, not colors.surface -- see _showHistorySheet.
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final colors = context.colors;
        return Material(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSizes.radiusMd),
          ),
          clipBehavior: Clip.antiAlias,
          child: FutureBuilder<List<BudgetModel>>(
            future: ref
                .read(budgetRepositoryProvider)
                .getBudgets(monthYear: monthYear),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final budgets = snapshot.data!;
              return SafeArea(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(AppSizes.md),
                  itemCount: budgets.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSizes.sm),
                        child: Text(
                          monthYear,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }
                    final b = budgets[index - 1];
                    final cat = TransactionCategory.getByName(b.category);
                    final ratio = b.limitAmount > 0
                        ? (b.spentAmount / b.limitAmount)
                        : 0.0;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Text(
                        cat.icon,
                        style: const TextStyle(fontSize: 18),
                      ),
                      title: Text(
                        b.category,
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: Text(
                        '${_formatCurrency(b.spentAmount)} / ${_formatCurrency(b.limitAmount)}',
                        style: TextStyle(
                          color: _getProgressColor(ratio),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final budgetsAsync = ref.watch(budgetListProvider);
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: budgetsAsync.when(
        data: (budgets) {
          if (budgets.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No budgets defined.',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                  AppSizes.h12,
                  ElevatedButton.icon(
                    onPressed: () => _showAddBudgetDialog(context, budgets),
                    icon: const Icon(Icons.add_rounded, color: Colors.white),
                    label: const Text(
                      'Add Budget',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                    ),
                  ),
                ],
              ),
            );
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
                        Text(
                          'Total Budget Limit',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          _formatCurrency(totalLimit),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _showSalaryPlannerSheet(context),
                          tooltip: 'Salary-Based 50/30/20 Planner',
                          icon: Icon(
                            Icons.calculate_outlined,
                            color: colors.textSecondary,
                          ),
                        ),
                        IconButton(
                          onPressed: () => _showHistorySheet(context),
                          tooltip: 'Monthly History',
                          icon: Icon(
                            Icons.history_rounded,
                            color: colors.textSecondary,
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              _showAddBudgetDialog(context, budgets),
                          tooltip: 'Add Budget',
                          icon: Icon(
                            Icons.add_circle_outline_rounded,
                            color: colors.textSecondary,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () =>
                              _showTransferDialog(context, budgets),
                          icon: const Icon(
                            Icons.compare_arrows_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: const Text(
                            'Transfer',
                            style: TextStyle(color: Colors.white, fontSize: 12),
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
                AppSizes.h16,

                // 50/30/20 Split Progress Row
                Card(
                  color: colors.cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '50/30/20 Allocations',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        AppSizes.h12,

                        // Needs Row (50%)
                        _buildBucketAllocationRow(
                          'Needs (50%)',
                          needsSpent,
                          needsLimit,
                          colors.needs,
                        ),
                        AppSizes.h8,
                        // Wants Row (30%)
                        _buildBucketAllocationRow(
                          'Wants (30%)',
                          wantsSpent,
                          wantsLimit,
                          colors.wants,
                        ),
                        AppSizes.h8,
                        // Savings Row (20%)
                        _buildBucketAllocationRow(
                          'Savings (20%)',
                          savingsSpent,
                          savingsLimit,
                          colors.savings,
                        ),
                      ],
                    ),
                  ),
                ),
                AppSizes.h16,

                const Text(
                  'Category Envelopes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                AppSizes.h8,

                // List of category envelopes
                Expanded(
                  child: ListView.builder(
                    itemCount: budgets.length,
                    itemBuilder: (context, index) {
                      final b = budgets[index];
                      final cat = TransactionCategory.getByName(b.category);
                      final ratio = b.limitAmount > 0
                          ? (b.spentAmount / b.limitAmount)
                          : 0.0;
                      final progressColor = _getProgressColor(ratio);

                      return Card(
                        color: colors.cardBg,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusMd,
                          ),
                          onTap: () => _showEditBudgetDialog(context, b),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSizes.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      cat.icon,
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                    AppSizes.w8,
                                    Text(
                                      b.category,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${_formatCurrency(b.spentAmount)} / ${_formatCurrency(b.limitAmount)}',
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                AppSizes.h8,
                                // Progress Bar
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: ratio.clamp(0.0, 1.0),
                                    backgroundColor: colors.border,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      progressColor,
                                    ),
                                    minHeight: 6,
                                  ),
                                ),
                                AppSizes.h4,
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      cat.bucket.displayName,
                                      style: TextStyle(
                                        color: cat.bucket.color,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      ratio >= 1.0
                                          ? 'Exceeded by ${_formatCurrency(b.spentAmount - b.limitAmount)}'
                                          : '₹${(b.limitAmount - b.spentAmount).toStringAsFixed(0)} left',
                                      style: TextStyle(
                                        color: ratio >= 1.0
                                            ? colors.error
                                            : colors.textSecondary,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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

  Widget _buildBucketAllocationRow(
    String title,
    double spent,
    double limit,
    Color color,
  ) {
    final colors = context.colors;
    final ratio = limit > 0 ? (spent / limit) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(color: colors.textSecondary, fontSize: 11),
            ),
            Text(
              '${_formatCurrency(spent)} / ${_formatCurrency(limit)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        AppSizes.h4,
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            backgroundColor: colors.border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}
