import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/savings_provider.dart';
import '../../domain/models/savings_goal_model.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/common_widgets.dart';

class AddGoalScreen extends ConsumerStatefulWidget {
  const AddGoalScreen({super.key});

  @override
  ConsumerState<AddGoalScreen> createState() =>
      _AddGoalScreenState();
}

class _AddGoalScreenState extends ConsumerState<AddGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _currentController = TextEditingController();

  GoalCategory _selectedCategory = GoalCategory.custom;
  String _selectedEmoji = '🎯';
  DateTime _targetDate = DateTime.now().add(const Duration(days: 365));
  bool _isLoading = false;
  double _requiredMonthly = 0;

  static const _emojiOptions = [
    '🎯', '🏡', '🚗', '✈️', '🎓', '💍', '🏖️', '📱', '💻', '🏋️'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _currentController.dispose();
    super.dispose();
  }

  void _recalculate() {
    final target = double.tryParse(
            _targetController.text.replaceAll(',', '')) ??
        0;
    final current = double.tryParse(
            _currentController.text.replaceAll(',', '')) ??
        0;
    final remaining = target - current;
    final now = DateTime.now();
    final months = (_targetDate.year - now.year) * 12 +
        (_targetDate.month - now.month);
    if (months > 0 && remaining > 0) {
      setState(() => _requiredMonthly = remaining / months);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('New Savings Goal',
            style: AppTextStyles.headlineMedium),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Category
            Text('Category', style: AppTextStyles.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: GoalCategory.values.map((cat) {
                final isSelected = cat == _selectedCategory;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedCategory = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      cat.name[0].toUpperCase() +
                          cat.name.substring(1),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Emoji picker
            Text('Icon', style: AppTextStyles.labelSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _emojiOptions
                  .map((e) => GestureDetector(
                        onTap: () =>
                            setState(() => _selectedEmoji = e),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _selectedEmoji == e
                                ? AppColors.primary.withOpacity(0.2)
                                : AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(8),
                            border: _selectedEmoji == e
                                ? Border.all(color: AppColors.primary)
                                : null,
                          ),
                          child: Text(e,
                              style: const TextStyle(fontSize: 20)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Goal Name',
                hintText: 'e.g. Emergency Fund',
              ),
              validator: Validators.required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _targetController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Target Amount',
                prefixText: '₹ ',
              ),
              validator: Validators.amount,
              onChanged: (_) => _recalculate(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _currentController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Already Saved (optional)',
                prefixText: '₹ ',
              ),
              onChanged: (_) => _recalculate(),
            ),
            const SizedBox(height: 12),
            // Target date
            ListTile(
              tileColor: AppColors.surfaceCard,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              title: Text('Target Date',
                  style: AppTextStyles.bodyMedium),
              subtitle: Text(
                '${_targetDate.day}/${_targetDate.month}/${_targetDate.year}',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
              trailing: const Icon(Icons.calendar_today_rounded,
                  size: 18),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _targetDate,
                  firstDate: DateTime.now().add(
                      const Duration(days: 30)),
                  lastDate: DateTime.now().add(
                      const Duration(days: 3650)),
                );
                if (d != null) {
                  setState(() => _targetDate = d);
                  _recalculate();
                }
              },
            ),
            // Monthly requirement preview
            if (_requiredMonthly > 0)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.accent.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Monthly savings needed',
                        style: AppTextStyles.labelMedium),
                    Text(
                      CurrencyFormatter.formatCompact(
                          _requiredMonthly),
                      style: AppTextStyles.amountSmall
                          .copyWith(color: AppColors.accent),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 32),
            GradientButton(
              label: _isLoading ? 'Saving...' : 'Create Goal',
              onTap: _isLoading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final goal = SavingsGoalModel(
      id: '',
      userId: '',
      name: _nameController.text.trim(),
      emoji: _selectedEmoji,
      category: _selectedCategory,
      targetAmount: double.parse(
          _targetController.text.replaceAll(',', '')),
      currentAmount: double.tryParse(
              _currentController.text.replaceAll(',', '')) ??
          0,
      targetDate: _targetDate,
      createdAt: DateTime.now(),
      color: AppColors.accent,
    );

    try {
      await ref
          .read(savingsNotifierProvider.notifier)
          .addGoal(goal);
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
