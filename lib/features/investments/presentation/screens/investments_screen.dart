import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/investment_provider.dart';
import '../../domain/models/investment_model.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/common_widgets.dart';

class InvestmentsScreen extends ConsumerStatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  ConsumerState<InvestmentsScreen> createState() =>
      _InvestmentsScreenState();
}

class _InvestmentsScreenState
    extends ConsumerState<InvestmentsScreen>
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

  @override
  Widget build(BuildContext context) {
    final portfolioAsync = ref.watch(portfolioSummaryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Investments',
            style: AppTextStyles.headlineMedium),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.push('/add-investment'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'SIPs & MFs'),
            Tab(text: 'Stocks'),
          ],
          indicatorColor: AppColors.primary,
          labelStyle: AppTextStyles.labelMedium,
        ),
      ),
      body: Column(
        children: [
          // Portfolio summary banner
          portfolioAsync.when(
            data: (summary) =>
                _PortfolioSummaryBanner(summary: summary),
            loading: () => const ShimmerCard(height: 90),
            error: (_, __) => const SizedBox.shrink(),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _SipTab(),
                _StocksTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-investment'),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _PortfolioSummaryBanner extends StatelessWidget {
  final PortfolioSummary summary;

  const _PortfolioSummaryBanner({required this.summary});

  @override
  Widget build(BuildContext context) {
    final isPositive = summary.absoluteReturn >= 0;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              label: 'Invested',
              value: CurrencyFormatter.formatCompact(
                  summary.totalInvested),
              color: Colors.white,
            ),
          ),
          Expanded(
            child: _Stat(
              label: 'Current',
              value: CurrencyFormatter.formatCompact(
                  summary.currentValue),
              color: Colors.white,
            ),
          ),
          Expanded(
            child: _Stat(
              label: 'Returns',
              value:
                  '${isPositive ? '+' : ''}${summary.returnPercent.toStringAsFixed(1)}%',
              color: isPositive ? AppColors.incomeGreen : AppColors.expenseRed,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Stat(
      {required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: AppTextStyles.caption
                .copyWith(color: Colors.white70)),
        const SizedBox(height: 2),
        Text(value,
            style: AppTextStyles.labelMedium.copyWith(color: color)),
      ],
    );
  }
}

class _SipTab extends ConsumerWidget {
  const _SipTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sipsAsync = ref.watch(sipsStreamProvider);

    return sipsAsync.when(
      data: (sips) {
        if (sips.isEmpty) {
          return const EmptyStateWidget(
              message: 'No SIPs yet. Tap + to add.');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sips.length,
          itemBuilder: (_, i) => _SipTile(sip: sips[i]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Center(child: Text('$e', style: AppTextStyles.bodySmall)),
    );
  }
}

class _SipTile extends StatelessWidget {
  final SipModel sip;

  const _SipTile({required this.sip});

  @override
  Widget build(BuildContext context) {
    final isPositive = sip.currentValue >= sip.totalInvested;
    final returnAmt = sip.currentValue - sip.totalInvested;
    final returnPct = sip.totalInvested > 0
        ? (returnAmt / sip.totalInvested) * 100
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sip.fundName,
                        style: AppTextStyles.bodyMedium),
                    Text(sip.amc,
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.formatCompact(sip.currentValue),
                    style: AppTextStyles.labelMedium,
                  ),
                  Text(
                    '${isPositive ? '+' : ''}${returnPct.toStringAsFixed(1)}%',
                    style: AppTextStyles.caption.copyWith(
                      color: isPositive
                          ? AppColors.incomeGreen
                          : AppColors.expenseRed,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SIP: ${CurrencyFormatter.formatCompact(sip.sipAmount)}/mo',
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary),
              ),
              Text(
                'Invested: ${CurrencyFormatter.formatCompact(sip.totalInvested)}',
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StocksTab extends ConsumerWidget {
  const _StocksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stocksAsync = ref.watch(stocksStreamProvider);

    return stocksAsync.when(
      data: (stocks) {
        if (stocks.isEmpty) {
          return const EmptyStateWidget(
              message: 'No stocks yet. Tap + to add.');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: stocks.length,
          itemBuilder: (_, i) => _StockTile(stock: stocks[i]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Center(child: Text('$e', style: AppTextStyles.bodySmall)),
    );
  }
}

class _StockTile extends StatelessWidget {
  final StockModel stock;

  const _StockTile({required this.stock});

  @override
  Widget build(BuildContext context) {
    final invested = stock.purchasePrice * stock.quantity;
    final current = stock.currentPrice * stock.quantity;
    final pnl = current - invested;
    final isPositive = pnl >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                stock.tickerSymbol.substring(0, 1),
                style: AppTextStyles.labelLarge,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stock.tickerSymbol,
                    style: AppTextStyles.labelMedium),
                Text(
                  '${stock.quantity} shares · ${stock.exchange}',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.formatCompact(current),
                style: AppTextStyles.labelMedium,
              ),
              Text(
                '${isPositive ? '+' : ''}${CurrencyFormatter.formatCompact(pnl)}',
                style: AppTextStyles.caption.copyWith(
                  color: isPositive
                      ? AppColors.incomeGreen
                      : AppColors.expenseRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
