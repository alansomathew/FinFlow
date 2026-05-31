import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../../../accounts/presentation/providers/account_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../domain/models/transaction_model.dart';
import '../../domain/models/category_model.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState
    extends ConsumerState<TransactionsScreen> {
  final _searchController = TextEditingController();
  TransactionType? _filterType;
  String _searchQuery = '';
  String? _selectedAccountId;
  String? _selectedCategoryId;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = TransactionFilter(
      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      type: _filterType,
      accountId: _selectedAccountId,
      categoryId: _selectedCategoryId,
      startDate: _startDate,
      endDate: _endDate,
    );
    final transactionsAsync =
        ref.watch(transactionsStreamProvider(filter));
    final accountsAsync = ref.watch(accountsStreamProvider);
    final summaryAsync = ref.watch(monthlySummaryProvider);
    final allCategories = ref.watch(allCategoriesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Transactions', style: AppTextStyles.headlineMedium),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_rounded),
            onPressed: () => context.push('/accounts'),
            tooltip: 'Accounts',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: _showFilterSheet,
            tooltip: 'Filter',
          ),
        ],
      ),
      body: Column(
        children: [
          // Accounts selector
          accountsAsync.when(
            data: (accounts) {
              if (accounts.isEmpty) return const SizedBox.shrink();
              return Container(
                height: 48,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: accounts.length + 1,
                  itemBuilder: (ctx, idx) {
                    if (idx == 0) {
                      final isSelected = _selectedAccountId == null;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('All Accounts'),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _selectedAccountId = null),
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    }
                    final acc = accounts[idx - 1];
                    final isSelected = _selectedAccountId == acc.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Text(acc.emoji),
                        label: Text(acc.name),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _selectedAccountId = acc.id),
                        selectedColor: acc.color,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const SizedBox(height: 48),
            error: (_, __) => const SizedBox.shrink(),
          ),
          // Monthly summary bar or selected account remaining balance
          if (_selectedAccountId != null)
            accountsAsync.when(
              data: (accounts) {
                final selectedAcc = accounts.firstWhere((a) => a.id == _selectedAccountId, orElse: () => accounts.first);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        selectedAcc.color,
                        selectedAcc.color.withOpacity(0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: selectedAcc.color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(selectedAcc.emoji, style: const TextStyle(fontSize: 24)),
                              const SizedBox(width: 8),
                              Text(
                                selectedAcc.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selectedAcc.bankName ?? selectedAcc.typeLabel,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Remaining Balance',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(selectedAcc.balance),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
              loading: () => const ShimmerCard(height: 70),
              error: (_, __) => const SizedBox.shrink(),
            )
          else
            summaryAsync.when(
              data: (summary) => _MonthlySummaryBar(summary: summary),
              loading: () => const ShimmerCard(height: 70),
              error: (_, __) => const SizedBox.shrink(),
            ),
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search transactions...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          // Filter chips
          if (_filterType != null || _selectedCategoryId != null || _startDate != null || _endDate != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (_filterType != null) ...[
                      ChoiceChip(
                        avatar: const Icon(Icons.close, size: 14, color: Colors.white),
                        label: Text(_filterType == TransactionType.credit ? 'Income' : 'Expense'),
                        selected: true,
                        onSelected: (_) => setState(() => _filterType = null),
                        selectedColor: AppColors.primary,
                        labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (_selectedCategoryId != null) ...[
                      (() {
                        final cat = allCategories.firstWhere((c) => c.id == _selectedCategoryId, orElse: () => CategoryModel.byId(_selectedCategoryId!));
                        return ChoiceChip(
                          avatar: const Icon(Icons.close, size: 14, color: Colors.white),
                          label: Text('${cat.emoji} ${cat.name}'),
                          selected: true,
                          onSelected: (_) => setState(() => _selectedCategoryId = null),
                          selectedColor: cat.color,
                          labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        );
                      })(),
                      const SizedBox(width: 8),
                    ],
                    if (_startDate != null || _endDate != null) ...[
                      ChoiceChip(
                        avatar: const Icon(Icons.close, size: 14, color: Colors.white),
                        label: Text(
                          _startDate != null && _endDate != null
                              ? '${DateFormat('MM/dd').format(_startDate!)} - ${DateFormat('MM/dd').format(_endDate!)}'
                              : _startDate != null
                                  ? 'After ${DateFormat('MM/dd').format(_startDate!)}'
                                  : 'Before ${DateFormat('MM/dd').format(_endDate!)}',
                        ),
                        selected: true,
                        onSelected: (_) => setState(() {
                          _startDate = null;
                          _endDate = null;
                        }),
                        selectedColor: Colors.amber,
                        labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
          // Transactions list
          Expanded(
            child: transactionsAsync.when(
              data: (transactions) {
                if (transactions.isEmpty) {
                  return const EmptyStateWidget(
                    message:
                        'No transactions found.\nTap + to add your first one.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: transactions.length,
                  itemBuilder: (ctx, i) {
                    final t = transactions[i];
                    final prevT =
                        i > 0 ? transactions[i - 1] : null;
                    final showDateHeader = prevT == null ||
                        !DateFormatter.isSameDay(
                            t.date, prevT.date);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showDateHeader)
                          Padding(
                            padding: const EdgeInsets.only(
                                top: 12, bottom: 4),
                            child: Text(
                              DateFormatter.relativeDate(t.date),
                              style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textSecondary),
                            ),
                          ),
                        _SwipeableTransactionTile(transaction: t),
                      ],
                    );
                  },
                );
              },
              loading: () => ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 6,
                itemBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: ShimmerCard(height: 64),
                ),
              ),
              error: (e, _) => Center(
                child: Text('Error: $e',
                    style: AppTextStyles.bodyMedium),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    final allCategories = ref.read(allCategoriesProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        currentType: _filterType,
        currentCategoryId: _selectedCategoryId,
        currentStartDate: _startDate,
        currentEndDate: _endDate,
        categories: allCategories,
        onApply: (type, categoryId, start, end) {
          setState(() {
            _filterType = type;
            _selectedCategoryId = categoryId;
            _startDate = start;
            _endDate = end;
          });
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _MonthlySummaryBar extends StatelessWidget {
  final MonthlySummary summary;

  const _MonthlySummaryBar({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              label: 'Income',
              value: CurrencyFormatter.formatCompact(summary.totalIncome),
              color: AppColors.incomeGreen,
            ),
          ),
          Container(width: 1, height: 32, color: AppColors.border),
          Expanded(
            child: _StatItem(
              label: 'Expense',
              value: CurrencyFormatter.formatCompact(summary.totalExpense),
              color: AppColors.expenseRed,
            ),
          ),
          Container(width: 1, height: 32, color: AppColors.border),
          Expanded(
            child: _StatItem(
              label: 'Saved',
              value: CurrencyFormatter.formatCompact(summary.netSavings),
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: AppTextStyles.amountSmall.copyWith(color: color)),
        Text(label,
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

class _SwipeableTransactionTile extends ConsumerWidget {
  final TransactionModel transaction;

  const _SwipeableTransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(categoryByIdProvider(transaction.categoryId));
    final isCredit = transaction.type == TransactionType.credit;

    return Dismissible(
      key: Key(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AppColors.expenseRed,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete Transaction'),
            content:
                const Text('Are you sure you want to delete this?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        ref
            .read(transactionNotifierProvider.notifier)
            .deleteTransaction(transaction.id);
      },
      child: GestureDetector(
        onTap: () =>
            context.push('/transactions/${transaction.id}'),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: category.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    category.emoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(transaction.payee ?? '—',
                        style: AppTextStyles.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(
                      category.name,
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AmountText(
                      amount: transaction.amount, isIncome: isCredit),
                  if (transaction.source == TransactionSource.sms)
                    const Icon(Icons.sms,
                        size: 12, color: AppColors.textDisabled),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final TransactionType? currentType;
  final String? currentCategoryId;
  final DateTime? currentStartDate;
  final DateTime? currentEndDate;
  final List<CategoryModel> categories;
  final Function(TransactionType? type, String? categoryId, DateTime? start, DateTime? end) onApply;

  const _FilterSheet({
    super.key,
    this.currentType,
    this.currentCategoryId,
    this.currentStartDate,
    this.currentEndDate,
    required this.categories,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  TransactionType? _selectedType;
  String? _selectedCategoryId;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.currentType;
    _selectedCategoryId = widget.currentCategoryId;
    _startDate = widget.currentStartDate;
    _endDate = widget.currentEndDate;
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background.withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: AppColors.border.withOpacity(0.3)),
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.textDisabled.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Filter Transactions', style: AppTextStyles.headlineMedium),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedType = null;
                      _selectedCategoryId = null;
                      _startDate = null;
                      _endDate = null;
                    });
                  },
                  child: const Text('Reset All', style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text('Transaction Type', style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Row(
              children: [
                _TypeChip(
                  label: 'All',
                  isSelected: _selectedType == null,
                  onTap: () => setState(() => _selectedType = null),
                ),
                const SizedBox(width: 8),
                _TypeChip(
                  label: 'Income',
                  isSelected: _selectedType == TransactionType.credit,
                  onTap: () => setState(() => _selectedType = TransactionType.credit),
                ),
                const SizedBox(width: 8),
                _TypeChip(
                  label: 'Expense',
                  isSelected: _selectedType == TransactionType.debit,
                  onTap: () => setState(() => _selectedType = TransactionType.debit),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Text('Category', style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border.withOpacity(0.5)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _selectedCategoryId,
                  dropdownColor: AppColors.surfaceElevated,
                  isExpanded: true,
                  hint: const Text('All Categories', style: TextStyle(color: AppColors.textSecondary)),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Categories'),
                    ),
                    ...widget.categories.map((cat) => DropdownMenuItem<String?>(
                          value: cat.id,
                          child: Row(
                            children: [
                              Text(cat.emoji),
                              const SizedBox(width: 8),
                              Text(cat.name),
                            ],
                          ),
                        )),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedCategoryId = val;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text('Date Range', style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.date_range_rounded, size: 16),
                    label: Text(
                      _startDate == null ? 'Start Date' : DateFormat('MMM dd, yyyy').format(_startDate!),
                      style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(color: AppColors.border.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => _startDate = picked);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.date_range_rounded, size: 16),
                    label: Text(
                      _endDate == null ? 'End Date' : DateFormat('MMM dd, yyyy').format(_endDate!),
                      style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(color: AppColors.border.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59));
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            GradientButton(
              label: 'Apply Filter',
              onTap: () => widget.onApply(_selectedType, _selectedCategoryId, _startDate, _endDate),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
