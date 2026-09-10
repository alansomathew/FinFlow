import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../../../constants/app_colors.dart';
import '../../../constants/app_sizes.dart';
import '../data/investments_repository.dart';

class InvestmentsTab extends ConsumerStatefulWidget {
  const InvestmentsTab({super.key});

  @override
  ConsumerState<InvestmentsTab> createState() => _InvestmentsTabState();
}

class _InvestmentsTabState extends ConsumerState<InvestmentsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(amount);
  }

  // Live NAV / Price Update Simulator
  Future<void> _simulateLivePricesUpdate(List<InvestmentModel> list) async {
    final notifier = ref.read(investmentListProvider.notifier);

    // Simulate updating prices by a random margin (-3% to +4%)
    for (var inv in list) {
      final changePercent =
          -0.03 +
          _random.nextDouble() * 0.07; // random value between -0.03 and +0.04
      final newPrice = inv.currentPrice * (1 + changePercent);

      final updated = InvestmentModel(
        id: inv.id,
        type: inv.type,
        name: inv.name,
        unitsQuantity: inv.unitsQuantity,
        purchasePrice: inv.purchasePrice,
        currentPrice: newPrice,
        datePurchased: inv.datePurchased,
      );

      // Update in repository
      await ref.read(investmentsRepositoryProvider).addInvestment(updated);
    }

    // Refresh Provider
    await notifier.refresh();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Live market feeds updated! Portfolio revalued.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final investmentsAsync = ref.watch(investmentListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: investmentsAsync.when(
        data: (investments) {
          double totalInvested = 0;
          double currentVal = 0;

          for (var inv in investments) {
            totalInvested += inv.unitsQuantity * inv.purchasePrice;
            currentVal += inv.unitsQuantity * inv.currentPrice;
          }

          final returns = currentVal - totalInvested;
          final returnsPercent = totalInvested > 0
              ? (returns / totalInvested * 100)
              : 0.0;
          final isPositive = returns >= 0;

          return Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Portfolio Header Summary Card
                Container(
                  padding: const EdgeInsets.all(AppSizes.md),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Portfolio Value',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              AppSizes.h4,
                              Text(
                                _formatCurrency(currentVal),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: () =>
                                _simulateLivePricesUpdate(investments),
                            icon: const Icon(
                              Icons.flash_on_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            label: const Text(
                              'Update Feed',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      AppSizes.h12,
                      const Divider(color: AppColors.border, height: 1),
                      AppSizes.h12,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Invested Amount',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                _formatCurrency(totalInvested),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Total returns',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                              Row(
                                children: [
                                  Icon(
                                    isPositive
                                        ? Icons.arrow_drop_up_rounded
                                        : Icons.arrow_drop_down_rounded,
                                    color: isPositive
                                        ? AppColors.success
                                        : AppColors.error,
                                    size: 16,
                                  ),
                                  Text(
                                    '${isPositive ? "+" : ""}${_formatCurrency(returns)} (${returnsPercent.toStringAsFixed(2)}%)',
                                    style: TextStyle(
                                      color: isPositive
                                          ? AppColors.success
                                          : AppColors.error,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                AppSizes.h16,

                // Tab selectors (Stocks vs Mutual Funds/SIPs)
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.primary,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSecondary,
                  tabs: const [
                    Tab(text: 'Stocks Holdings'),
                    Tab(text: 'Mutual Funds & SIPs'),
                  ],
                ),
                AppSizes.h12,

                // Tab Content List
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Stocks Panel
                      _buildInvestmentList(
                        investments
                            .where((inv) => inv.type == 'Stock')
                            .toList(),
                      ),
                      // Mutual Fund Panel
                      _buildInvestmentList(
                        investments
                            .where((inv) => inv.type != 'Stock')
                            .toList(),
                      ),
                    ],
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

  Widget _buildInvestmentList(List<InvestmentModel> list) {
    if (list.isEmpty) {
      return const Center(
        child: Text(
          'No assets logged in this category.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final inv = list[index];
        final cost = inv.unitsQuantity * inv.purchasePrice;
        final marketValue = inv.unitsQuantity * inv.currentPrice;
        final pnl = marketValue - cost;
        final pnlPercent = cost > 0 ? (pnl / cost * 100) : 0.0;
        final isPositive = pnl >= 0;

        return Card(
          color: AppColors.cardBg,
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      inv.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      _formatCurrency(marketValue),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                AppSizes.h8,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Qty: ${inv.unitsQuantity.toStringAsFixed(inv.type == 'Stock' ? 0 : 2)} • Avg Price: ${_formatCurrency(inv.purchasePrice)}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          isPositive
                              ? Icons.arrow_drop_up_rounded
                              : Icons.arrow_drop_down_rounded,
                          color: isPositive
                              ? AppColors.success
                              : AppColors.error,
                          size: 14,
                        ),
                        Text(
                          '${isPositive ? "+" : ""}${pnlPercent.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: isPositive
                                ? AppColors.success
                                : AppColors.error,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
