import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../constants/app_sizes.dart';
import '../../../constants/app_theme.dart';
import '../../../utils/month_key.dart';
import '../../transactions/domain/transaction.dart';
import '../data/budget_repository.dart';
import '../data/custom_categories_repository.dart';

const _bucketPercentages = {
  BudgetBucket.needs: 0.5,
  BudgetBucket.wants: 0.3,
  BudgetBucket.savings: 0.2,
};

const _categoryIconChoices = [
  '🛒',
  '🍔',
  '🎬',
  '💡',
  '🏠',
  '🚗',
  '💊',
  '📚',
  '🎁',
  '🐾',
  '⚡',
  '🧾',
];

const _categoryColorChoices = [
  '#6366F1',
  '#059669',
  '#7C3AED',
  '#D97706',
  '#DC2626',
  '#0891B2',
  '#DB2777',
  '#4B5563',
];

/// Salary-driven budget planner: enter a monthly income figure, see the
/// classic 50/30/20 pool each bucket should get, and allocate real category
/// limits against each pool -- the pool is a target to allocate *against*,
/// not something the app silently divides for you (nobody's rent and
/// groceries are ever actually equal, so an even split across categories
/// would rarely match reality; the user picks the categories and amounts,
/// the planner just keeps the running total honest against each bucket's
/// target).
class SalaryBudgetPlannerSheet extends ConsumerStatefulWidget {
  const SalaryBudgetPlannerSheet({super.key});

  @override
  ConsumerState<SalaryBudgetPlannerSheet> createState() =>
      _SalaryBudgetPlannerSheetState();
}

class _SalaryBudgetPlannerSheetState
    extends ConsumerState<SalaryBudgetPlannerSheet> {
  final _salaryController = TextEditingController();
  double _salary = 0;
  bool _saving = false;
  bool _loadingSaved = true;
  late final String _monthYear;

  @override
  void initState() {
    super.initState();
    _monthYear = monthKeyOf(DateTime.now());
    _loadSavedIncome();
  }

  Future<void> _loadSavedIncome() async {
    final saved = await ref
        .read(budgetRepositoryProvider)
        .getMonthlyIncome(_monthYear);
    if (!mounted) return;
    setState(() {
      if (saved != null) {
        _salary = saved;
        _salaryController.text = saved.toStringAsFixed(0);
      }
      _loadingSaved = false;
    });
  }

  Future<void> _saveSalary() async {
    if (_salary <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid salary first')),
      );
      return;
    }
    setState(() => _saving = true);
    await ref
        .read(budgetRepositoryProvider)
        .setMonthlyIncome(_monthYear, _salary);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    final successColor = context.colors.success;
    final monthYear = _monthYear;
    setState(() => _saving = false);
    navigator.pop();
    messenger?.showSnackBar(
      SnackBar(
        content: Text('Saved as your budget for $monthYear'),
        backgroundColor: successColor,
      ),
    );
  }

  @override
  void dispose() {
    _salaryController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(amount);
  }

  void _showAddCategoryDialog(
    BudgetBucket bucket,
    List<BudgetModel> existingInBucket,
    double remaining,
  ) {
    final existingNames = existingInBucket.map((b) => b.category).toSet();
    final customCategories =
        ref.read(customCategoryListProvider).valueOrNull ?? [];
    final available = <TransactionCategory>[
      ...TransactionCategory.presets.where(
        (c) => c.bucket == bucket && !existingNames.contains(c.name),
      ),
      ...customCategories
          .where(
            (c) => c.bucket == bucket && !existingNames.contains(c.name),
          )
          .map((c) => c.toTransactionCategory()),
    ];

    TransactionCategory? selected = available.isNotEmpty
        ? available.first
        : null;
    final limitController = TextEditingController(
      text: remaining > 0 ? remaining.toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final colors = context.colors;
            return AlertDialog(
              backgroundColor: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              title: Text(
                'Add to ${bucket.displayName}',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (available.isNotEmpty)
                    DropdownButtonFormField<TransactionCategory>(
                      initialValue: selected,
                      dropdownColor: colors.surface,
                      style: TextStyle(color: colors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Category',
                        labelStyle: TextStyle(color: colors.textSecondary),
                      ),
                      items: available.map((c) {
                        return DropdownMenuItem(
                          value: c,
                          child: Text('${c.icon}  ${c.name}'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setStateDialog(() => selected = val);
                      },
                    )
                  else
                    Text(
                      'Every preset ${bucket.displayName} category already '
                      'has a budget this month -- create a custom one below.',
                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                    ),
                  AppSizes.h8,
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _showCreateCustomCategoryDialog(bucket, (
                        created,
                      ) {
                        setStateDialog(() {
                          if (!available.any((c) => c.name == created.name)) {
                            available.add(created);
                          }
                          selected = created;
                        });
                      }),
                      icon: Icon(
                        Icons.add_circle_outline_rounded,
                        size: 16,
                        color: colors.primaryLight,
                      ),
                      label: Text(
                        'Create Custom Category',
                        style: TextStyle(
                          color: colors.primaryLight,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  AppSizes.h12,
                  TextField(
                    controller: limitController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(color: colors.textPrimary),
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
                    final current = selected;
                    if (current == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Pick or create a category first'),
                        ),
                      );
                      return;
                    }
                    final limit = double.tryParse(limitController.text) ?? 0.0;
                    if (limit <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter a valid limit')),
                      );
                      return;
                    }
                    await ref
                        .read(budgetListProvider.notifier)
                        .setLimit(current.name, limit, _monthYear);
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                  ),
                  child: const Text(
                    'Add',
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

  Future<void> _showCreateCustomCategoryDialog(
    BudgetBucket bucket,
    void Function(TransactionCategory created) onCreated,
  ) async {
    final nameController = TextEditingController();
    String selectedIcon = _categoryIconChoices.first;
    String selectedColorHex = _categoryColorChoices.first;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            final colors = dialogContext.colors;
            return AlertDialog(
              backgroundColor: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              title: Text(
                'New ${bucket.displayName} Category',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: colors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Category Name',
                        labelStyle: TextStyle(color: colors.textSecondary),
                        fillColor: colors.cardBg,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusSm,
                          ),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    AppSizes.h12,
                    Text(
                      'Icon',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    AppSizes.h8,
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categoryIconChoices.map((icon) {
                        final iconSelected = selectedIcon == icon;
                        return GestureDetector(
                          onTap: () =>
                              setStateDialog(() => selectedIcon = icon),
                          child: Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: iconSelected
                                  ? colors.primary.withValues(alpha: 0.25)
                                  : colors.cardBg,
                              shape: BoxShape.circle,
                              border: iconSelected
                                  ? Border.all(color: colors.primary, width: 2)
                                  : null,
                            ),
                            child: Text(
                              icon,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    AppSizes.h12,
                    Text(
                      'Color',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    AppSizes.h8,
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _categoryColorChoices.map((hex) {
                        final colorSelected = selectedColorHex == hex;
                        final swatch = Color(
                          int.parse(hex.substring(1), radix: 16) + 0xFF000000,
                        );
                        return GestureDetector(
                          onTap: () =>
                              setStateDialog(() => selectedColorHex = hex),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: swatch,
                              shape: BoxShape.circle,
                              border: colorSelected
                                  ? Border.all(color: Colors.white, width: 2)
                                  : null,
                            ),
                            child: colorSelected
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Enter a category name'),
                        ),
                      );
                      return;
                    }
                    final custom = CustomCategoryModel(
                      id: const Uuid().v4(),
                      name: name,
                      icon: selectedIcon,
                      colorHex: selectedColorHex,
                      bucket: bucket,
                    );
                    await ref
                        .read(customCategoryListProvider.notifier)
                        .add(custom);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                    onCreated(custom.toTransactionCategory());
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

  Future<void> _removeCategory(BudgetModel budget) async {
    await ref
        .read(budgetListProvider.notifier)
        .remove(budget.category, budget.monthYear);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final budgetsAsync = ref.watch(budgetListProvider);
    // Watched here (not just read where used) so the custom-category
    // registry TransactionCategory.getByName relies on is populated as
    // soon as this sheet opens, and so newly created categories show up
    // immediately without needing to reopen the sheet.
    ref.watch(customCategoryListProvider);

    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppSizes.radiusLg),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                AppSizes.h12,
                Text(
                  'Salary-Based 50/30/20 Planner',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                AppSizes.h4,
                Text(
                  'Enter your monthly take-home pay to see how much each bucket should get, then assign real category limits against each target.',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
                AppSizes.h16,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _salaryController,
                        enabled: !_loadingSaved,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: TextStyle(color: colors.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Monthly Salary / Income',
                          labelStyle: TextStyle(color: colors.textSecondary),
                          fillColor: colors.cardBg,
                          filled: true,
                          prefixIcon: Icon(
                            Icons.currency_rupee_rounded,
                            color: colors.primaryLight,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusMd,
                            ),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (val) =>
                            setState(() => _salary = double.tryParse(val) ?? 0),
                      ),
                    ),
                    AppSizes.w8,
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: (_saving || _loadingSaved)
                            ? null
                            : _saveSalary,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusMd,
                            ),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save',
                                style: TextStyle(color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                ),
                AppSizes.h4,
                Text(
                  'Saved as this month\'s income target so it\'s here next time you open this planner.',
                  style: TextStyle(color: colors.textMuted, fontSize: 11),
                ),
                AppSizes.h16,
                Expanded(
                  child: _salary <= 0
                      ? Center(
                          child: Text(
                            'Enter your salary above to see your 50/30/20 split.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colors.textSecondary),
                          ),
                        )
                      : budgetsAsync.when(
                          data: (budgets) {
                            return ListView(
                              children: [
                                _buildBucketSection(
                                  BudgetBucket.needs,
                                  budgets,
                                  colors,
                                ),
                                AppSizes.h16,
                                _buildBucketSection(
                                  BudgetBucket.wants,
                                  budgets,
                                  colors,
                                ),
                                AppSizes.h16,
                                _buildBucketSection(
                                  BudgetBucket.savings,
                                  budgets,
                                  colors,
                                ),
                              ],
                            );
                          },
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (e, _) => Center(child: Text('Error: $e')),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBucketSection(
    BudgetBucket bucket,
    List<BudgetModel> allBudgets,
    AppColorExtension colors,
  ) {
    final pool = _salary * (_bucketPercentages[bucket] ?? 0);
    final inBucket = allBudgets
        .where(
          (b) => TransactionCategory.getByName(b.category).bucket == bucket,
        )
        .toList();
    final allocated = inBucket.fold(0.0, (sum, b) => sum + b.limitAmount);
    final remaining = pool - allocated;
    final ratio = pool > 0 ? (allocated / pool).clamp(0.0, 1.5) : 0.0;
    final progressColor = ratio > 1.0
        ? colors.error
        : ratio >= 0.9
        ? colors.warning
        : colors.success;
    final pct = ((_bucketPercentages[bucket] ?? 0) * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${bucket.displayName} ($pct%)',
                style: TextStyle(
                  color: bucket.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                '${_formatCurrency(allocated)} / ${_formatCurrency(pool)}',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          AppSizes.h8,
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 6,
            ),
          ),
          AppSizes.h4,
          Text(
            remaining >= 0
                ? '${_formatCurrency(remaining)} left to allocate'
                : 'Over by ${_formatCurrency(-remaining)}',
            style: TextStyle(
              color: remaining >= 0 ? colors.textSecondary : colors.error,
              fontSize: 11,
            ),
          ),
          if (inBucket.isNotEmpty) ...[
            AppSizes.h12,
            ...inBucket.map((b) {
              final cat = TransactionCategory.getByName(b.category);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: cat.displayColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    AppSizes.w8,
                    Text(cat.icon, style: const TextStyle(fontSize: 14)),
                    AppSizes.w8,
                    Expanded(
                      child: Text(
                        b.category,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      _formatCurrency(b.limitAmount),
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _removeCategory(b),
                      icon: Icon(
                        Icons.close_rounded,
                        color: colors.textMuted,
                        size: 16,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              );
            }),
          ],
          AppSizes.h8,
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  _showAddCategoryDialog(bucket, inBucket, remaining),
              icon: Icon(
                Icons.add_circle_outline_rounded,
                size: 16,
                color: colors.primaryLight,
              ),
              label: Text(
                'Add Category',
                style: TextStyle(color: colors.primaryLight, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
