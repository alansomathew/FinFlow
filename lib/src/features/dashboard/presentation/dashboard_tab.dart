import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_sizes.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/domain/transaction.dart';
import '../../budget/data/budget_repository.dart';
import '../../debt/data/debt_repository.dart';
import '../../investments/data/investments_repository.dart';
import 'home_screen.dart';

class DashboardTab extends ConsumerWidget {
  const DashboardTab({super.key});

  // Helper to format currency in INR style
  String _formatINR(double amount) {
    final format = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return format.format(amount);
  }

  // Dynamic AI financial advice generator
  String _generateAiTip(
    List<TransactionModel> txs,
    double monthlyBudget,
    double totalSpent,
  ) {
    if (txs.isEmpty)
      return "Welcome to FinFlow! Start tracking to receive personalized AI financial advice.";

    // Check dining out
    final diningOutTxs = txs.where((t) => t.category == 'Dining Out').toList();
    final diningOutSum = diningOutTxs.fold(0.0, (sum, t) => sum + t.amount);
    if (diningOutSum > 4000) {
      return "AI Coach: You spent ${_formatINR(diningOutSum)} on Dining Out. Swiggy/Zomato is your top merchant. Cook at home 2 days/week to save ~₹1,500!";
    }

    // Check budget limit
    if (monthlyBudget > 0 && totalSpent / monthlyBudget > 0.85) {
      return "AI Coach: You have consumed ${(totalSpent / monthlyBudget * 100).toStringAsFixed(0)}% of your monthly budget. Nearing limit, consider postponing Wants.";
    }

    // Check savings rate
    final savingsTxs = txs
        .where((t) => t.bucket == BudgetBucket.savings)
        .toList();
    final savingsSum = savingsTxs.fold(0.0, (sum, t) => sum + t.amount);
    if (savingsSum > 10000) {
      return "AI Coach: Excellent! Your SIPs and investments of ${_formatINR(savingsSum)} are on track. That grows to ₹1.2L this year!";
    }

    return "AI Coach: Your Emergency Fund covers only 1.5 months of expenses. Setup a Savings Goal to cover 6 months.";
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountListProvider);
    final transactionsAsync = ref.watch(transactionListProvider);
    final budgetsAsync = ref.watch(budgetListProvider);
    final loansAsync = ref.watch(loanListProvider);
    final investmentsAsync = ref.watch(investmentListProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(accountListProvider.notifier).refresh();
        ref.read(transactionListProvider.notifier).refresh();
        ref.read(budgetListProvider.notifier).refresh();
        ref.read(loanListProvider.notifier).refresh();
        ref.read(investmentListProvider.notifier).refresh();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Net Worth Card
              accountsAsync.when(
                data: (accounts) {
                  double assets = 0;
                  double liabilities = 0;
                  for (var acc in accounts) {
                    if (acc.type == 'credit_card') {
                      liabilities += acc.balance.abs();
                    } else {
                      assets += acc.balance;
                    }
                  }
                  final netWorth = assets - liabilities;

                  return Container(
                    padding: const EdgeInsets.all(AppSizes.lg),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL NET WORTH',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        AppSizes.h8,
                        Text(
                          _formatINR(netWorth),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        AppSizes.h12,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Assets',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  _formatINR(assets),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Liabilities',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  _formatINR(liabilities),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
              AppSizes.h16,

              // Daily Limit & Budget Remaining Chip Row
              Row(
                children: [
                  Expanded(
                    child: budgetsAsync.when(
                      data: (budgets) {
                        final totalLimit = budgets.fold(
                          0.0,
                          (sum, b) => sum + b.limitAmount,
                        );
                        final totalSpent = budgets.fold(
                          0.0,
                          (sum, b) => sum + b.spentAmount,
                        );
                        final remaining = totalLimit - totalSpent;

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.md,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusMd,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Remaining Budget',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              AppSizes.h4,
                              Text(
                                _formatINR(remaining),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      loading: () => Container(),
                      error: (_, __) => Container(),
                    ),
                  ),
                  AppSizes.w12,
                  Expanded(
                    child: budgetsAsync.when(
                      data: (budgets) {
                        final totalLimit = budgets.fold(
                          0.0,
                          (sum, b) => sum + b.limitAmount,
                        );
                        final totalSpent = budgets.fold(
                          0.0,
                          (sum, b) => sum + b.spentAmount,
                        );
                        final remaining = totalLimit - totalSpent;
                        final daysLeft = 30 - DateTime.now().day + 1;
                        final dailyLimit = remaining > 0
                            ? remaining / daysLeft
                            : 0.0;

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.md,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusMd,
                            ),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Safe Daily Spend',
                                style: TextStyle(
                                  color: AppColors.primaryLight,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              AppSizes.h4,
                              Text(
                                _formatINR(dailyLimit),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      loading: () => Container(),
                      error: (_, __) => Container(),
                    ),
                  ),
                ],
              ),
              AppSizes.h16,

              // AI Coaching Tips Banner
              transactionsAsync.when(
                data: (txs) {
                  // Fetch budget numbers
                  double limit = 0;
                  double spent = 0;
                  budgetsAsync.whenData((budgets) {
                    limit = budgets.fold(0.0, (sum, b) => sum + b.limitAmount);
                    spent = budgets.fold(0.0, (sum, b) => sum + b.spentAmount);
                  });

                  final tip = _generateAiTip(txs, limit, spent);

                  return Container(
                    padding: const EdgeInsets.all(AppSizes.md),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.psychology_rounded,
                          color: AppColors.primaryLight,
                          size: 28,
                        ),
                        AppSizes.w12,
                        Expanded(
                          child: Text(
                            tip,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => Container(),
                error: (_, __) => Container(),
              ),
              AppSizes.h16,

              // Financial Module Overview Widgets
              Row(
                children: [
                  // Investments Card
                  Expanded(
                    child: investmentsAsync.when(
                      data: (investments) {
                        double totalValue = 0;
                        for (var inv in investments) {
                          totalValue += inv.unitsQuantity * inv.currentPrice;
                        }
                        return Container(
                          padding: const EdgeInsets.all(AppSizes.md),
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusMd,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.show_chart_rounded,
                                    color: AppColors.savings,
                                    size: 18,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Investments',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              AppSizes.h8,
                              Text(
                                _formatINR(totalValue),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      loading: () => Container(),
                      error: (_, __) => Container(),
                    ),
                  ),
                  AppSizes.w12,
                  // Loans Card
                  Expanded(
                    child: loansAsync.when(
                      data: (loans) {
                        double totalDebt = loans.fold(
                          0.0,
                          (sum, l) => sum + l.loanAmount,
                        );
                        return Container(
                          padding: const EdgeInsets.all(AppSizes.md),
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusMd,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.credit_card_rounded,
                                    color: AppColors.error,
                                    size: 18,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Active Loans',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              AppSizes.h8,
                              Text(
                                _formatINR(totalDebt),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      loading: () => Container(),
                      error: (_, __) => Container(),
                    ),
                  ),
                ],
              ),
              AppSizes.h24,

              // Recent Transactions Heading
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Ledger',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ref.read(activeTabProvider.notifier).state =
                          1; // Navigate to Ledger
                    },
                    child: const Text(
                      'See All',
                      style: TextStyle(
                        color: AppColors.primaryLight,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),

              // Recent Transactions list (5)
              transactionsAsync.when(
                data: (txs) {
                  if (txs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'No transactions logged yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }

                  final recent = txs.take(5).toList();
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recent.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: AppColors.border, height: 1),
                    itemBuilder: (context, idx) {
                      final t = recent[idx];
                      final category = TransactionCategory.getByName(
                        t.category,
                      );
                      final isDebit = t.bucket != BudgetBucket.income;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: t.bucket.color.withOpacity(0.15),
                          child: Text(
                            category.icon,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                        title: Text(
                          t.payee.isNotEmpty ? t.payee : t.category,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          DateFormat('dd MMM yyyy').format(t.date),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        trailing: Text(
                          '${isDebit ? "-" : "+"}${_formatINR(t.amount)}',
                          style: TextStyle(
                            color: isDebit
                                ? AppColors.textPrimary
                                : AppColors.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
              AppSizes.h32, // Padding below ledger
            ],
          ),
        ),
      ),
    );
  }
}
