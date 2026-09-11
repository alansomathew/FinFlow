import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../constants/app_sizes.dart';
import '../../../constants/app_theme.dart';
import '../../accounts/data/accounts_repository.dart';
import '../data/goals_repository.dart';

const _goalIcons = [
  '🎯',
  '🚨',
  '🏠',
  '🚗',
  '✈️',
  '💍',
  '🎓',
  '👶',
  '💻',
  '🏖️',
];

const _colorPalette = [
  '#6366F1',
  '#059669',
  '#7C3AED',
  '#D97706',
  '#DC2626',
  '#0891B2',
  '#DB2777',
  '#4B5563',
];

/// Add/edit form for a single savings goal. Pass [existing] to edit it in
/// place; omit it to add a new one. New goals are subject to the free-tier
/// cap ([kFreeGoalLimit]); editing an existing one never is. Editing never
/// touches currentAmount -- that's only ever changed via the contribute
/// action, to keep "how much progress" and "what's the plan" separate.
class GoalFormSheet extends ConsumerStatefulWidget {
  final GoalModel? existing;
  const GoalFormSheet({super.key, this.existing});

  @override
  ConsumerState<GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends ConsumerState<GoalFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _targetController;

  late String _selectedIcon;
  late String _selectedColor;
  DateTime? _targetDate;
  AccountModel? _selectedAccount;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _targetController = TextEditingController(
      text: existing != null ? existing.targetAmount.toString() : '',
    );
    _selectedIcon = existing?.icon ?? _goalIcons.first;
    _selectedColor = existing?.colorHex ?? _colorPalette.first;
    _targetDate = existing?.targetDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _pickTargetDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        final colors = context.colors;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: colors.primary,
              onPrimary: Colors.white,
              surface: colors.surface,
              onSurface: colors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final repo = ref.read(goalsRepositoryProvider);
    if (!_isEditing) {
      final allowed = await repo.canAddGoal();
      if (!allowed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Free tier allows up to $kFreeGoalLimit savings goals. Upgrade to Pro for unlimited.',
              ),
            ),
          );
        }
        return;
      }
    }

    setState(() => _saving = true);

    final goal = GoalModel(
      id: widget.existing?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      targetAmount: double.parse(_targetController.text),
      currentAmount: widget.existing?.currentAmount ?? 0.0,
      targetDate: _targetDate,
      icon: _selectedIcon,
      colorHex: _selectedColor,
      linkedAccountId: _selectedAccount?.id ?? widget.existing?.linkedAccountId,
    );

    await ref.read(goalListProvider.notifier).add(goal);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountListProvider);
    final colors = context.colors;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusLg),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Form(
              key: _formKey,
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
                    _isEditing ? 'Edit Goal' : 'New Savings Goal',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  AppSizes.h16,

                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Goal Name',
                      labelStyle: TextStyle(color: colors.textSecondary),
                      fillColor: colors.cardBg,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'Enter a goal name'
                        : null,
                  ),
                  AppSizes.h16,

                  TextFormField(
                    controller: _targetController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Target Amount',
                      labelStyle: TextStyle(color: colors.textSecondary),
                      fillColor: colors.cardBg,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(
                        Icons.currency_rupee_rounded,
                        color: colors.primaryLight,
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Enter a target';
                      final parsed = double.tryParse(val);
                      if (parsed == null) return 'Enter a valid number';
                      if (parsed <= 0)
                        return 'Target must be greater than zero';
                      return null;
                    },
                  ),
                  AppSizes.h16,

                  InkWell(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    onTap: _pickTargetDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.md,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: colors.cardBg,
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.event_rounded,
                            color: colors.textSecondary,
                            size: 20,
                          ),
                          AppSizes.w12,
                          Text(
                            _targetDate != null
                                ? 'Target: ${DateFormat('dd MMM yyyy').format(_targetDate!)}'
                                : 'Set Target Date (optional)',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AppSizes.h16,

                  Text(
                    'Icon',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                  AppSizes.h8,
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _goalIcons.map((icon) {
                      final selected = _selectedIcon == icon;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedIcon = icon),
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? colors.primary.withValues(alpha: 0.25)
                                : colors.cardBg,
                            shape: BoxShape.circle,
                            border: selected
                                ? Border.all(color: colors.primary, width: 2)
                                : null,
                          ),
                          child: Text(
                            icon,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  AppSizes.h16,

                  Text(
                    'Color',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                  AppSizes.h8,
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _colorPalette.map((hex) {
                      final selected = _selectedColor == hex;
                      final color = Color(
                        int.parse(hex.substring(1), radix: 16) + 0xFF000000,
                      );
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColor = hex),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: selected
                                ? Border.all(color: Colors.white, width: 2)
                                : null,
                          ),
                          child: selected
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 18,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  AppSizes.h16,

                  accountsAsync.when(
                    data: (accounts) {
                      if (accounts.isEmpty) return const SizedBox.shrink();
                      _selectedAccount ??=
                          widget.existing?.linkedAccountId != null
                          ? accounts
                                .where(
                                  (a) =>
                                      a.id == widget.existing!.linkedAccountId,
                                )
                                .firstOrNull
                          : null;

                      return DropdownButtonFormField<AccountModel?>(
                        initialValue: _selectedAccount,
                        dropdownColor: colors.surface,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Linked Account (optional)',
                          labelStyle: TextStyle(color: colors.textSecondary),
                          fillColor: colors.cardBg,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusMd,
                            ),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<AccountModel?>(
                            value: null,
                            child: Text('None'),
                          ),
                          ...accounts.map((acc) {
                            return DropdownMenuItem<AccountModel?>(
                              value: acc,
                              child: Text(acc.name),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedAccount = val);
                        },
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (e, _) => const SizedBox.shrink(),
                  ),
                  AppSizes.h24,

                  ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      ),
                    ),
                    child: Text(
                      _isEditing ? 'Save Changes' : 'Create Goal',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
