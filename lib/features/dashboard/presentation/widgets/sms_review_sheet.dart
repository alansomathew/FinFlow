import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/local/sms_service.dart';
import '../../../../core/utils/sms_parser.dart';
import '../../../accounts/presentation/providers/account_provider.dart';
import '../../../accounts/domain/models/account_model.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../../../transactions/presentation/providers/category_provider.dart';
import '../../../transactions/domain/models/category_model.dart';
import '../../../transactions/domain/models/transaction_model.dart';
import 'package:intl/intl.dart';

class SmsReviewSheet extends ConsumerStatefulWidget {
  final List<SmsParsedTransaction> pendingTransactions;

  const SmsReviewSheet({
    super.key,
    required this.pendingTransactions,
  });

  @override
  ConsumerState<SmsReviewSheet> createState() => _SmsReviewSheetState();
}

class _SmsReviewSheetState extends ConsumerState<SmsReviewSheet> {
  late List<SmsParsedTransaction> _list;
  final SmsService _smsService = SmsService();

  // Selected parameters per transaction ID
  final Map<String, String> _selectedAccounts = {};
  final Map<String, String> _selectedCategories = {};
  final Map<String, TextEditingController> _payeeControllers = {};

  @override
  void initState() {
    super.initState();
    _list = List.from(widget.pendingTransactions);
    _initializeFields();
  }

  void _initializeFields() {
    for (final tx in _list) {
      _payeeControllers[tx.smsId] = TextEditingController(text: tx.payee);
      _selectedCategories[tx.smsId] = _suggestCategoryId(tx.body, tx.type);
    }
  }

  @override
  void dispose() {
    for (final controller in _payeeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _suggestCategoryId(String body, TransactionType type) {
    final lower = body.toLowerCase();
    if (type == TransactionType.credit) {
      if (lower.contains('salary') || lower.contains('payroll')) return 'salary';
      if (lower.contains('dividend') || lower.contains('interest')) return 'dividend';
      return 'other';
    } else {
      if (lower.contains('swiggy') || lower.contains('zomato') || lower.contains('restaurant') || lower.contains('food') || lower.contains('pizza')) {
        return 'dining';
      }
      if (lower.contains('grocery') || lower.contains('mart') || lower.contains('supermarket')) {
        return 'groceries';
      }
      if (lower.contains('uber') || lower.contains('ola') || lower.contains('metro') || lower.contains('auto') || lower.contains('fuel') || lower.contains('petrol')) {
        return 'transport';
      }
      if (lower.contains('amazon') || lower.contains('flipkart') || lower.contains('myntra') || lower.contains('croma') || lower.contains('shopping') || lower.contains('spent on card')) {
        return 'shopping';
      }
      if (lower.contains('netflix') || lower.contains('spotify') || lower.contains('youtube') || lower.contains('prime')) {
        return 'subscriptions';
      }
      if (lower.contains('insurance') || lower.contains('lic')) {
        return 'insurance';
      }
      if (lower.contains('emi') || lower.contains('loan') || lower.contains('mortgage')) {
        return 'emi';
      }
      if (lower.contains('hospital') || lower.contains('pharmacy') || lower.contains('medical') || lower.contains('doctor')) {
        return 'health';
      }
      return 'other';
    }
  }

  // Pre-select account matching masked digits
  String? _findMatchingAccountId(List<AccountModel> accounts, String? maskedNumber) {
    if (maskedNumber == null || maskedNumber.isEmpty) return null;
    for (final acc in accounts) {
      if (acc.maskedNumber != null && acc.maskedNumber!.endsWith(maskedNumber)) {
        return acc.id;
      }
    }
    return null;
  }

  Future<void> _importTransaction(SmsParsedTransaction tx, String accountId) async {
    final categoryId = _selectedCategories[tx.smsId] ?? 'other';
    final payee = _payeeControllers[tx.smsId]?.text.trim() ?? tx.payee ?? 'Merchant';

    final fields = {
      'amount': tx.amount,
      'type': tx.type,
      'categoryId': categoryId,
      'accountId': accountId,
      'payee': payee.isNotEmpty ? payee : (tx.type == TransactionType.debit ? 'Expense' : 'Income'),
      'note': 'Auto-imported from SMS: "${tx.body}"',
      'date': tx.date,
      'source': TransactionSource.sms,
      'isRecurring': false,
    };

    // Add to DB
    await ref.read(transactionNotifierProvider.notifier).addTransaction(fields);
    
    // Mark as processed
    await _smsService.markAsProcessed(tx.smsId);

    // Remove from UI
    setState(() {
      _list.removeWhere((item) => item.smsId == tx.smsId);
    });

    if (_list.isEmpty) {
      Navigator.of(context).pop();
      _showSuccessSnackBar('All transactions imported successfully!');
    }
  }

  Future<void> _dismissTransaction(SmsParsedTransaction tx) async {
    await _smsService.markAsProcessed(tx.smsId);
    setState(() {
      _list.removeWhere((item) => item.smsId == tx.smsId);
    });

    if (_list.isEmpty) {
      Navigator.of(context).pop();
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.success),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: AppColors.surfaceElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final categories = ref.watch(allCategoriesProvider);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background.withOpacity(0.92),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: AppColors.border.withOpacity(0.4), width: 1.5),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: accountsAsync.when(
          data: (accounts) {
            if (accounts.isEmpty) {
              return _buildEmptyState("Create an account first to import SMS transactions.");
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top drag handle
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
                
                // Header
                Row(
                  children: [
                    const Icon(Icons.sms_failed_outlined, color: AppColors.primary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("New Transactions Detected", style: AppTextStyles.headlineMedium),
                          const SizedBox(height: 2),
                          Text(
                            "Review pending items parsed from SMS alerts.",
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final ids = _list.map((e) => e.smsId).toList();
                        await _smsService.markMultipleAsProcessed(ids);
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        "Ignore All",
                        style: TextStyle(color: AppColors.error.withOpacity(0.9), fontWeight: FontWeight.w600),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 18),

                // Transactions List
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.55,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _list.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final tx = _list[index];
                        
                        // Handle auto-selected account mapping
                        final matchedId = _findMatchingAccountId(accounts, tx.maskedNumber);
                        final defaultId = matchedId ?? accounts.first.id;
                        if (!_selectedAccounts.containsKey(tx.smsId)) {
                          _selectedAccounts[tx.smsId] = defaultId;
                        }
                        final selectedAccountId = _selectedAccounts[tx.smsId]!;

                        final selectedCategoryId = _selectedCategories[tx.smsId] ?? 'other';
                        final payeeController = _payeeControllers[tx.smsId]!;

                        final isDebit = tx.type == TransactionType.debit;
                        
                        return Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border.withOpacity(0.3)),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Amount & Date header
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "${isDebit ? '-' : '+'} Rs. ${tx.amount.toStringAsFixed(2)}",
                                    style: AppTextStyles.headlineMedium.copyWith(
                                      color: isDebit ? AppColors.expenseRed : AppColors.incomeGreen,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('MMM dd, hh:mm a').format(tx.date),
                                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // SMS Raw Body text
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.background.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.all(10),
                                child: Text(
                                  tx.body,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary.withOpacity(0.8),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Payee input
                              TextField(
                                controller: payeeController,
                                style: AppTextStyles.bodyMedium,
                                decoration: InputDecoration(
                                  labelText: "Payee / Description",
                                  labelStyle: TextStyle(color: AppColors.textSecondary),
                                  floatingLabelBehavior: FloatingLabelBehavior.always,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: AppColors.border.withOpacity(0.5)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: AppColors.primary),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Dropdowns Row (Account & Category)
                              Row(
                                children: [
                                  // Account Selector
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("Account", style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: AppColors.border.withOpacity(0.5)),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: selectedAccountId,
                                              dropdownColor: AppColors.surfaceElevated,
                                              isExpanded: true,
                                              icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                                              style: AppTextStyles.bodyMedium,
                                              items: accounts.map((acc) {
                                                final hasMatch = acc.maskedNumber != null && 
                                                    tx.maskedNumber != null && 
                                                    acc.maskedNumber!.endsWith(tx.maskedNumber!);
                                                return DropdownMenuItem<String>(
                                                  value: acc.id,
                                                  child: Text(
                                                    "${acc.name} ${hasMatch ? '✨' : ''}",
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (val) {
                                                if (val != null) {
                                                  setState(() {
                                                    _selectedAccounts[tx.smsId] = val;
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Category Selector
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("Category", style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: AppColors.border.withOpacity(0.5)),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: selectedCategoryId,
                                              dropdownColor: AppColors.surfaceElevated,
                                              isExpanded: true,
                                              icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                                              style: AppTextStyles.bodyMedium,
                                              items: categories.map((cat) {
                                                return DropdownMenuItem<String>(
                                                  value: cat.id,
                                                  child: Row(
                                                    children: [
                                                      Text(cat.emoji),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          cat.name,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (val) {
                                                if (val != null) {
                                                  setState(() {
                                                    _selectedCategories[tx.smsId] = val;
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Action buttons
                              Row(
                                children: [
                                  // Skip/Ignore button
                                  Expanded(
                                    flex: 2,
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.textSecondary,
                                        side: BorderSide(color: AppColors.border.withOpacity(0.5)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => _dismissTransaction(tx),
                                      child: const Text("Ignore"),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Import button
                                  Expanded(
                                    flex: 3,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        elevation: 2,
                                        shadowColor: AppColors.primary.withOpacity(0.4),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => _importTransaction(tx, selectedAccountId),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add_link_outlined, size: 18),
                                          SizedBox(width: 6),
                                          Text("Import", style: TextStyle(fontWeight: FontWeight.w700)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, s) => _buildEmptyState("Error loading accounts. Please try again."),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
        const SizedBox(height: 16),
        Text(msg, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Close"),
        ),
      ],
    );
  }
}
