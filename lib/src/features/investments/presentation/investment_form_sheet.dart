import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../constants/app_sizes.dart';
import '../../../constants/app_theme.dart';
import '../data/investments_repository.dart';

const _investmentTypes = ['Stock', 'Mutual Fund', 'SIP'];

/// Add/edit form for a single investment holding. Pass [existing] to edit
/// it in place; omit it to add a new one. currentPrice is a plain editable
/// field here -- real live price feeds are deferred (they need Cloud
/// Functions plus a chosen market-data provider), so until then this form
/// *is* how a holding's price gets updated, honestly, instead of the
/// random jitter it replaces.
class InvestmentFormSheet extends ConsumerStatefulWidget {
  final InvestmentModel? existing;
  const InvestmentFormSheet({super.key, this.existing});

  @override
  ConsumerState<InvestmentFormSheet> createState() =>
      _InvestmentFormSheetState();
}

class _InvestmentFormSheetState extends ConsumerState<InvestmentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _unitsController;
  late final TextEditingController _purchasePriceController;
  late final TextEditingController _currentPriceController;

  late String _selectedType;
  late DateTime _datePurchased;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _unitsController = TextEditingController(
      text: existing != null ? existing.unitsQuantity.toString() : '',
    );
    _purchasePriceController = TextEditingController(
      text: existing != null ? existing.purchasePrice.toString() : '',
    );
    _currentPriceController = TextEditingController(
      text: existing != null ? existing.currentPrice.toString() : '',
    );
    _selectedType = existing?.type ?? _investmentTypes.first;
    _datePurchased = existing != null
        ? (DateTime.tryParse(existing.datePurchased) ?? DateTime.now())
        : DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitsController.dispose();
    _purchasePriceController.dispose();
    _currentPriceController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _datePurchased,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
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
      setState(() => _datePurchased = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final investment = InvestmentModel(
      id: widget.existing?.id ?? const Uuid().v4(),
      type: _selectedType,
      name: _nameController.text.trim(),
      unitsQuantity: double.parse(_unitsController.text),
      purchasePrice: double.parse(_purchasePriceController.text),
      currentPrice: double.parse(_currentPriceController.text),
      datePurchased: DateFormat('yyyy-MM-dd').format(_datePurchased),
    );

    await ref.read(investmentListProvider.notifier).add(investment);
    if (mounted) Navigator.pop(context);
  }

  InputDecoration _decoration(String label) {
    final colors = context.colors;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: colors.textSecondary),
      fillColor: colors.cardBg,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    _isEditing ? 'Edit Investment' : 'Add Investment',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  AppSizes.h16,

                  Text(
                    'Type',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                  AppSizes.h8,
                  Wrap(
                    spacing: 8,
                    children: _investmentTypes.map((t) {
                      final selected = _selectedType == t;
                      return ChoiceChip(
                        selected: selected,
                        onSelected: (_) => setState(() => _selectedType = t),
                        label: Text(t),
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : colors.textSecondary,
                        ),
                        selectedColor: colors.primary,
                        backgroundColor: colors.cardBg,
                      );
                    }).toList(),
                  ),
                  AppSizes.h16,

                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _decoration('Name'),
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'Enter a name'
                        : null,
                  ),
                  AppSizes.h16,

                  TextFormField(
                    controller: _unitsController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(color: Colors.white),
                    decoration: _decoration('Units / Quantity'),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Enter units';
                      if (double.tryParse(val) == null) return 'Invalid number';
                      return null;
                    },
                  ),
                  AppSizes.h16,

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _purchasePriceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: const TextStyle(color: Colors.white),
                          decoration: _decoration('Avg Purchase Price'),
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Required';
                            if (double.tryParse(val) == null) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                      AppSizes.w12,
                      Expanded(
                        child: TextFormField(
                          controller: _currentPriceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: const TextStyle(color: Colors.white),
                          decoration: _decoration('Current Price'),
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Required';
                            if (double.tryParse(val) == null) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  AppSizes.h4,
                  Text(
                    'Live price feeds are on the roadmap; update this manually for now.',
                    style: TextStyle(color: colors.textMuted, fontSize: 11),
                  ),
                  AppSizes.h16,

                  InkWell(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    onTap: _pickDate,
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
                            'Purchased: ${DateFormat('dd MMM yyyy').format(_datePurchased)}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
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
                      _isEditing ? 'Save Changes' : 'Add Investment',
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
