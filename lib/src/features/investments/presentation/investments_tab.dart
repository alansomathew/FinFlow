import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_sizes.dart';
import '../../../constants/app_theme.dart';
import '../../../services/pro_tier_service.dart';
import '../data/investments_repository.dart';
import 'investment_form_sheet.dart';

class InvestmentsTab extends ConsumerStatefulWidget {
  const InvestmentsTab({super.key});

  @override
  ConsumerState<InvestmentsTab> createState() => _InvestmentsTabState();
}

class _InvestmentsTabState extends ConsumerState<InvestmentsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const InvestmentFormSheet(),
    );
  }

  void _showEditSheet(InvestmentModel investment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InvestmentFormSheet(existing: investment),
    );
  }

  Future<void> _confirmDelete(InvestmentModel investment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = context.colors;
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          title: Text(
            'Delete Investment?',
            style: TextStyle(color: colors.textPrimary),
          ),
          content: Text(
            'This removes "${investment.name}" from your portfolio.',
            style: TextStyle(color: colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Delete', style: TextStyle(color: colors.error)),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await ref.read(investmentListProvider.notifier).remove(investment.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isPro = ref.watch(isProProvider).valueOrNull ?? false;

    if (!isPro) {
      return const _InvestmentsUpsell();
    }

    final investmentsAsync = ref.watch(investmentListProvider);

    return Scaffold(
      backgroundColor: colors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: colors.primary,
        onPressed: _showAddSheet,
        child: const Icon(Icons.add, color: Colors.white),
      ),
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
                    color: colors.cardBg,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Portfolio Value',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      AppSizes.h4,
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _formatCurrency(currentVal),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      AppSizes.h12,
                      Divider(color: colors.border, height: 1),
                      AppSizes.h12,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Invested Amount',
                                style: TextStyle(
                                  color: colors.textSecondary,
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
                              Text(
                                'Total returns',
                                style: TextStyle(
                                  color: colors.textSecondary,
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
                                        ? colors.success
                                        : colors.error,
                                    size: 16,
                                  ),
                                  Text(
                                    '${isPositive ? "+" : ""}${_formatCurrency(returns)} (${returnsPercent.toStringAsFixed(2)}%)',
                                    style: TextStyle(
                                      color: isPositive
                                          ? colors.success
                                          : colors.error,
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
                  indicatorColor: colors.primary,
                  labelColor: Colors.white,
                  unselectedLabelColor: colors.textSecondary,
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
    final colors = context.colors;
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No assets logged in this category.',
              style: TextStyle(color: colors.textSecondary),
            ),
            AppSizes.h12,
            ElevatedButton.icon(
              onPressed: _showAddSheet,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'Add Investment',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(backgroundColor: colors.primary),
            ),
          ],
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
          color: colors.cardBg,
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            onTap: () => _showEditSheet(inv),
            onLongPress: () => _confirmDelete(inv),
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
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            isPositive
                                ? Icons.arrow_drop_up_rounded
                                : Icons.arrow_drop_down_rounded,
                            color: isPositive ? colors.success : colors.error,
                            size: 14,
                          ),
                          Text(
                            '${isPositive ? "+" : ""}${pnlPercent.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: isPositive ? colors.success : colors.error,
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
          ),
        );
      },
    );
  }
}

class _InvestmentsUpsell extends StatelessWidget {
  const _InvestmentsUpsell();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.workspace_premium_rounded,
                color: colors.warning,
                size: 48,
              ),
              AppSizes.h16,
              Text(
                'Investments is a Pro Feature',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              AppSizes.h8,
              Text(
                'Track stocks, mutual funds, and SIPs with portfolio-level P&L. Upgrade to Pro to unlock this module.',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
