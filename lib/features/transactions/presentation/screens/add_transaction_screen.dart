import '../../../../core/ai/gemini_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../../domain/models/transaction_model.dart';
import '../../domain/models/category_model.dart';
import '../../../../features/accounts/presentation/providers/account_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/common_widgets.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final String? transactionId; // if editing

  const AddTransactionScreen({super.key, this.transactionId});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
    // Suggest category with AI (Gemini)
    Future<void> suggestCategoryWithAI() async {
      final title = _titleController.text.trim();
      final note = _notesController.text.trim();
      final amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
      if (title.isEmpty || amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter description and amount first.'),),
        );
        return;
      }
      setState(() {
        aiLoading = true;
        aiCategorySuggestion = null;
      });
      final result = await GeminiAI.suggestCategory(title: title, note: note, amount: amount);
      setState(() {
        aiLoading = false;
        aiCategorySuggestion = result;
        // Optionally auto-select the group
        if (result == 'Needs') _type = TransactionType.debit;
        if (result == 'Wants') _type = TransactionType.debit;
        if (result == 'Savings') _type = TransactionType.credit;
      });
    }
  String? aiCategorySuggestion;
  bool aiLoading = false;

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  TransactionType _type = TransactionType.debit;
  String _selectedCategoryId = 'food';
  String? _selectedAccountId;
  DateTime _selectedDate = DateTime.now();

  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final categoryGroup =
        _type == TransactionType.credit ? CategoryGroup.income : CategoryGroup.expense;
    final categories = ref.watch(categoriesByGroupProvider(categoryGroup));

    if (categories.isNotEmpty &&
        !categories.any((c) => c.id == _selectedCategoryId)) {
      _selectedCategoryId = categories.first.id;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.transactionId != null
              ? 'Edit Transaction'
              : 'Add Transaction',
          style: AppTextStyles.headlineMedium,
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Type toggle
            _TypeToggle(
              current: _type,
              onChanged: (t) => setState(() => _type = t),
            ),
            const SizedBox(height: 24),
            // Amount field - large prominent
            TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: AppTextStyles.amountLarge,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: '0.00',
                prefixText: '₹ ',
                border: InputBorder.none,
              ),
              validator: Validators.amount,
            ),
            const Divider(),
            const SizedBox(height: 16),
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.edit_rounded),
              ),
              validator: Validators.required,
            ),
            const SizedBox(height: 16),
            // Category picker
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Category', style: AppTextStyles.labelMedium),
                TextButton.icon(
                  onPressed: () => _showAddCategoryDialog(categoryGroup),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Category'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _CategoryPicker(
              categories: categories,
              selectedId: _selectedCategoryId,
              onSelected: (id) =>
                  setState(() => _selectedCategoryId = id),
            ),
            const SizedBox(height: 16),
            // Account picker
            accountsAsync.when(
              data: (accounts) {
                if (_selectedAccountId == null && accounts.isNotEmpty) {
                  _selectedAccountId = accounts.first.id;
                }
                return DropdownButtonFormField<String>(
                  initialValue: _selectedAccountId,
                  decoration: const InputDecoration(
                    labelText: 'Account',
                    prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                  ),
                  items: accounts
                      .map((acc) => DropdownMenuItem(
                            value: acc.id,
                            child: Row(
                              children: [
                                Text(acc.emoji),
                                const SizedBox(width: 8),
                                Text(acc.name),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedAccountId = v),
                );
              },
              loading: () => const ShimmerCard(height: 56),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            // Date picker
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_rounded),
              title: Text(DateFormatter.displayDate(_selectedDate),
                  style: AppTextStyles.bodyMedium),
              onTap: _pickDate,
              tileColor: AppColors.surfaceCard,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            const SizedBox(height: 16),
            // Notes
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: Text(aiLoading
                        ? 'AI Suggesting...'
                        : 'AI Suggest Category'),
                    onPressed: aiLoading ? null : suggestCategoryWithAI,
                  ),
                ),
                if (aiCategorySuggestion != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Chip(
                      label: Text('AI: $aiCategorySuggestion'),
                      avatar: const Icon(Icons.bolt, size: 18),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            GradientButton(
              label: _isLoading
                  ? 'Saving...'
                  : (widget.transactionId != null ? 'Update' : 'Save'),
              onTap: _isLoading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _showAddCategoryDialog(CategoryGroup group) async {
    final nameController = TextEditingController();
    final emojiController = TextEditingController(text: '📁');
    BudgetBucket selectedBucket = switch (group) {
      CategoryGroup.expense => BudgetBucket.wants,
      CategoryGroup.income => BudgetBucket.needs,
      CategoryGroup.investment => BudgetBucket.savings,
    };

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.darkSurface,
          title: Text('New Category', style: AppTextStyles.headlineMedium),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                ),
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emojiController,
                decoration: const InputDecoration(
                  labelText: 'Emoji',
                  hintText: 'e.g. 🎉',
                ),
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text('Rule Bucket', style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: BudgetBucket.values.map((b) {
                  final label = b == BudgetBucket.needs
                      ? 'Needs'
                      : b == BudgetBucket.wants
                          ? 'Wants'
                          : 'Savings';
                  final color = b == BudgetBucket.needs
                      ? AppColors.needsColor
                      : b == BudgetBucket.wants
                          ? AppColors.wantsColor
                          : AppColors.savingsColor;
                  final isSelected = selectedBucket == b;

                  return ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (_) {
                      setDialogState(() {
                        selectedBucket = b;
                      });
                    },
                    selectedColor: color.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? color : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: isSelected ? color : AppColors.border.withOpacity(0.5),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                await ref.read(categoryNotifierProvider.notifier).addCustomCategory(
                      name: name,
                      emoji: emojiController.text.trim().isEmpty
                          ? '📁'
                          : emojiController.text.trim(),
                      group: group,
                      bucket: selectedBucket,
                    );
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an account')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final amount = double.parse(
        _amountController.text.replaceAll(',', ''));

    final fields = <String, dynamic>{
      'amount': amount,
      'type': _type,
      'categoryId': _selectedCategoryId,
      'accountId': _selectedAccountId!,
      'date': _selectedDate,
      'payee': _titleController.text.trim().isEmpty
          ? null
          : _titleController.text.trim(),
      'note': _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      'source': TransactionSource.manual,
    };

    try {
      if (widget.transactionId != null) {
        await ref
            .read(transactionNotifierProvider.notifier)
            .updateTransaction(widget.transactionId!, fields);
      } else {
        await ref
            .read(transactionNotifierProvider.notifier)
            .addTransaction(fields);
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _TypeToggle extends StatelessWidget {
  final TransactionType current;
  final ValueChanged<TransactionType> onChanged;

  const _TypeToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _ToggleTab(
            label: 'Expense',
            isSelected: current == TransactionType.debit,
            color: AppColors.expenseRed,
            onTap: () => onChanged(TransactionType.debit),
          ),
          _ToggleTab(
            label: 'Income',
            isSelected: current == TransactionType.credit,
            color: AppColors.incomeGreen,
            onTap: () => onChanged(TransactionType.credit),
          ),
        ],
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _ToggleTab({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color:
                isSelected ? color.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelLarge.copyWith(
              color: isSelected ? color : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  final List<CategoryModel> categories;
  final String selectedId;
  final ValueChanged<String> onSelected;

  const _CategoryPicker(
      {required this.categories,
      required this.selectedId,
      required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (_, i) {
          final cat = categories[i];
          final isSelected = cat.id == selectedId;
          return GestureDetector(
            onTap: () => onSelected(cat.id),
            child: Container(
              width: 64,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? cat.color.withOpacity(0.2)
                    : AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? Border.all(color: cat.color, width: 2)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(cat.emoji,
                      style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 4),
                  Text(
                    cat.name,
                    style: AppTextStyles.caption.copyWith(
                      color: isSelected
                          ? cat.color
                          : AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
