import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/account_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../domain/models/account_model.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final netWorthAsync = ref.watch(netWorthProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Accounts', style: AppTextStyles.headlineMedium),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.push('/add-account'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Net Worth summary
          netWorthAsync.when(
            data: (nw) => _NetWorthBanner(netWorth: nw),
            loading: () => const ShimmerCard(height: 72),
            error: (_, __) => const SizedBox.shrink(),
          ),
          Expanded(
            child: accountsAsync.when(
              data: (accounts) {
                if (accounts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🏦',
                            style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text('No accounts yet',
                            style: AppTextStyles.headlineMedium),
                        const SizedBox(height: 8),
                        Text(
                          'Add your bank accounts, cards, and wallets',
                          style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        GradientButton(
                          label: 'Add Account',
                          onTap: () => context.push('/add-account'),
                        ),
                      ],
                    ),
                  );
                }

                final creditCards = accounts
                    .where((a) => a.isCreditCard)
                    .toList();
                final others = accounts
                    .where((a) => !a.isCreditCard)
                    .toList();

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (others.isNotEmpty) ...[
                      Text('Bank Accounts & Wallets',
                          style: AppTextStyles.labelLarge.copyWith(
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      ...others.map((acc) =>
                          _AccountTile(account: acc)),
                    ],
                    if (creditCards.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text('Credit Cards',
                          style: AppTextStyles.labelLarge.copyWith(
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      ...creditCards.map((acc) =>
                          _AccountTile(account: acc)),
                    ],
                  ],
                );
              },
              loading: () => ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 3,
                itemBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: ShimmerCard(height: 72),
                ),
              ),
              error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: AppTextStyles.bodyMedium)),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-account'),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _NetWorthBanner extends StatelessWidget {
  final double netWorth;

  const _NetWorthBanner({required this.netWorth});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Net Worth',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: Colors.white70)),
              Text(
                CurrencyFormatter.format(netWorth),
                style: AppTextStyles.amountMedium
                    .copyWith(color: Colors.white),
              ),
            ],
          ),
          const Icon(Icons.account_balance_rounded,
              color: Colors.white70, size: 32),
        ],
      ),
    );
  }
}

class _AccountTile extends ConsumerWidget {
  final AccountModel account;

  const _AccountTile({required this.account});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        tileColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: account.color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              account.emoji,
              style: const TextStyle(fontSize: 22),
            ),
          ),
        ),
        title: Text(account.name, style: AppTextStyles.bodyMedium),
        subtitle: account.maskedNumber != null
            ? Text('•••• ${account.maskedNumber}',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary))
            : Text(account.typeLabel,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AmountText(
              amount: account.balance.abs(),
              isIncome: !account.isCreditCard,
            ),
            if (account.isCreditCard && account.creditLimit != null)
              Text(
                '${(account.utilizationRatio * 100).toStringAsFixed(0)}% used',
                style: AppTextStyles.caption.copyWith(
                  color: account.utilizationRatio > 0.8
                      ? AppColors.expenseRed
                      : AppColors.textSecondary,
                ),
              ),
          ],
        ),
        onTap: () {},
      ),
    );
  }
}
