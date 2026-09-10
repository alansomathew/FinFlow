import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_sizes.dart';
import '../../accounts/data/accounts_repository.dart';
import '../data/transaction_repository.dart';
import '../domain/transaction.dart';
import 'transaction_detail_screen.dart';

class TransactionsTab extends ConsumerStatefulWidget {
  const TransactionsTab({super.key});

  @override
  ConsumerState<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends ConsumerState<TransactionsTab> {
  String _searchQuery = '';
  BudgetBucket? _selectedBucket;
  DateTimeRange? _dateRange;

  // Format currency
  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(amount);
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  bool _inSelectedRange(DateTime date) {
    final range = _dateRange;
    if (range == null) return true;
    final day = DateTime(date.year, date.month, date.day);
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(range.end.year, range.end.month, range.end.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionListProvider);

    return Column(
      children: [
        // Search & Filters Panel
        Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            children: [
              // Search Input
              TextField(
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.toLowerCase();
                  });
                },
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search merchant, note, amount...',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.textSecondary,
                  ),
                  fillColor: AppColors.cardBg,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              AppSizes.h12,

              // Horizontal Bucket Filters
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    // All filter
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: _selectedBucket == null,
                        label: const Text('All'),
                        labelStyle: TextStyle(
                          color: _selectedBucket == null
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.cardBg,
                        checkmarkColor: Colors.white,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedBucket = null;
                            });
                          }
                        },
                      ),
                    ),
                    ...BudgetBucket.values.map((bucket) {
                      final isSelected = _selectedBucket == bucket;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: isSelected,
                          label: Text(bucket.displayName),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                          selectedColor: bucket.color,
                          backgroundColor: AppColors.cardBg,
                          checkmarkColor: Colors.white,
                          onSelected: (selected) {
                            setState(() {
                              _selectedBucket = selected ? bucket : null;
                            });
                          },
                        ),
                      );
                    }),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: _dateRange != null,
                        avatar: const Icon(
                          Icons.date_range_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        label: Text(
                          _dateRange == null
                              ? 'Date Range'
                              : '${DateFormat('dd MMM').format(_dateRange!.start)} - ${DateFormat('dd MMM').format(_dateRange!.end)}',
                        ),
                        labelStyle: TextStyle(
                          color: _dateRange != null
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.cardBg,
                        checkmarkColor: Colors.white,
                        onSelected: (_) => _pickDateRange(),
                        onDeleted: _dateRange != null
                            ? () => setState(() => _dateRange = null)
                            : null,
                        deleteIconColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Transactions list
        Expanded(
          child: transactionsAsync.when(
            data: (transactions) {
              // Apply local filters
              final filtered = transactions.where((t) {
                // Filter by bucket
                if (_selectedBucket != null && t.bucket != _selectedBucket) {
                  return false;
                }

                // Filter by date range
                if (!_inSelectedRange(t.date)) {
                  return false;
                }

                // Filter by search query
                if (_searchQuery.isNotEmpty) {
                  final payeeMatch = t.payee.toLowerCase().contains(
                    _searchQuery,
                  );
                  final noteMatch = t.note.toLowerCase().contains(_searchQuery);
                  final catMatch = t.category.toLowerCase().contains(
                    _searchQuery,
                  );
                  final amountMatch = t.amount.toString().contains(
                    _searchQuery,
                  );
                  return payeeMatch || noteMatch || catMatch || amountMatch;
                }

                return true;
              }).toList();

              if (filtered.isEmpty) {
                return const Center(
                  child: Text(
                    'No transactions match your filters.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.read(transactionListProvider.notifier).refresh();
                },
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final t = filtered[index];
                    final category = TransactionCategory.getByName(t.category);
                    final isDebit = t.bucket != BudgetBucket.income;

                    return Dismissible(
                      key: Key(t.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusMd,
                          ),
                        ),
                        child: const Icon(
                          Icons.delete_rounded,
                          color: Colors.white,
                        ),
                      ),
                      onDismissed: (dir) {
                        ref.read(transactionListProvider.notifier).remove(t.id);
                        ref.read(accountListProvider.notifier).refresh();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${t.payee.isNotEmpty ? t.payee : t.category} deleted',
                            ),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      },
                      child: Card(
                        color: AppColors.cardBg,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusMd,
                          ),
                        ),
                        child: ListTile(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  TransactionDetailScreen(transaction: t),
                            ),
                          ),
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
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            '${DateFormat('dd MMM yyyy').format(t.date)} ${t.note.isNotEmpty ? '• ${t.note}' : ''}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            '${isDebit ? "-" : "+"}${_formatCurrency(t.amount)}',
                            style: TextStyle(
                              color: isDebit
                                  ? AppColors.textPrimary
                                  : AppColors.success,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                'Error: $e',
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
