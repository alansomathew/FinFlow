import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../../../constants/app_sizes.dart';
import '../../../constants/app_theme.dart';
import '../../../database/app_database.dart';
import '../../../utils/sms_parser.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/domain/transaction.dart';
import '../data/sms_device_service.dart';
import '../data/sms_repository.dart';
import '../domain/sms_duplicate_detector.dart';

/// Confidence threshold above which a parse is shown in green rather than
/// amber -- purely a visual signal now. Every parsed SMS still requires an
/// explicit per-item Add or Skip; there is deliberately no bulk auto-add,
/// so a transaction is never created without the user looking at that
/// specific message and deciding on it.
const _autoAcceptConfidence = 70;

/// The real, device-driven counterpart to the manual-paste SMS Sandbox:
/// shows whatever the device's actual SMS inbox has staged for review,
/// requests the SMS permission if not yet granted, and requires an
/// individual Add/Skip decision on every item -- no bulk "add all" shortcut,
/// so nothing is ever added without being asked about first. Triggered
/// automatically on app foreground/resume (see home_screen.dart).
class SmsReviewSheet extends ConsumerStatefulWidget {
  const SmsReviewSheet({super.key});

  @override
  ConsumerState<SmsReviewSheet> createState() => _SmsReviewSheetState();
}

class _SmsReviewSheetState extends ConsumerState<SmsReviewSheet> {
  bool _loading = true;
  bool _hasPermission = false;
  bool _permanentlyDenied = false;
  List<SmsInboxData> _queue = [];
  int _remainingThisMonth = kFreeSmsParseLimit;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final device = ref.read(smsDeviceServiceProvider);
    final smsRepo = ref.read(smsRepositoryProvider);

    final hasPermission = await device.hasPermission();
    if (hasPermission) {
      await device.scanInbox();
      device.startForegroundListening();
    }
    final permanentlyDenied =
        !hasPermission && await device.isPermanentlyDenied();
    final queue = await smsRepo.getPendingInbox();
    final remaining = await smsRepo.parsesRemainingThisMonth();

    if (!mounted) return;
    setState(() {
      _hasPermission = hasPermission;
      _permanentlyDenied = permanentlyDenied;
      _queue = queue;
      _remainingThisMonth = remaining;
      _loading = false;
    });
  }

  Future<void> _requestPermission() async {
    final status = await ref.read(smsDeviceServiceProvider).requestPermission();
    if (status.isPermanentlyDenied) {
      if (!mounted) return;
      setState(() => _permanentlyDenied = true);
      return;
    }
    await _refresh();
  }

  Future<bool> _addSingle(
    SmsInboxData sms,
    ParsedSms parsed, {
    required TransactionCategory category,
  }) async {
    final smsRepo = ref.read(smsRepositoryProvider);
    if (!await smsRepo.canParseMoreThisMonth()) return false;

    final accounts = await ref.read(accountsRepositoryProvider).getAccounts();
    final account = SmsDuplicateDetector.resolveAccount(
      accounts,
      parsed.accountLast4,
    );
    if (account == null) return false;

    final tx = TransactionModel(
      id: const Uuid().v4(),
      amount: parsed.amount,
      category: category.name,
      bucket: parsed.type == 'credit' ? BudgetBucket.income : category.bucket,
      accountId: account.id,
      date: sms.date,
      payee: parsed.payee,
      note: 'Auto-parsed from SMS alert',
      refId: parsed.refId,
    );
    await ref.read(transactionListProvider.notifier).add(tx);
    await smsRepo.markParsed(sms.id);
    return true;
  }

  /// Asks the user to confirm (or change) which category this parsed SMS
  /// should be filed under before it's added, defaulting to a guess derived
  /// from the merchant/payee name -- that guess is often wrong for income
  /// (a salary credit's "payee" is an employer name, which never matches a
  /// category preset), so this is the point where the user actually gets a
  /// say instead of a mis-guessed category silently landing on the ledger.
  Future<TransactionCategory?> _pickCategory(
    TransactionCategory defaultCategory,
    ParsedSms parsed,
  ) async {
    final isIncome = parsed.type == 'credit';
    final options = TransactionCategory.presets
        .where(
          (c) => isIncome
              ? c.bucket == BudgetBucket.income
              : c.bucket != BudgetBucket.income,
        )
        .toList();
    TransactionCategory selected = options.contains(defaultCategory)
        ? defaultCategory
        : options.first;

    return showDialog<TransactionCategory>(
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
                'Confirm Category',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '₹${parsed.amount.toStringAsFixed(2)} · ${parsed.payee}',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                  AppSizes.h12,
                  DropdownButtonFormField<TransactionCategory>(
                    initialValue: selected,
                    dropdownColor: colors.surface,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Category',
                      labelStyle: TextStyle(color: colors.textSecondary),
                    ),
                    items: options.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Text('${c.icon}  ${c.name}'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setStateDialog(() => selected = val);
                    },
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
                  onPressed: () => Navigator.pop(context, selected),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                  ),
                  child: const Text(
                    'Confirm & Add',
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

  Future<void> _addItem(SmsInboxData sms) async {
    final parsed = SmsParser.parse(sms.messageBody);
    if (parsed == null) {
      await ref.read(smsRepositoryProvider).markSkipped(sms.id);
      await _refresh();
      return;
    }

    final defaultCategory = TransactionCategory.getByName(parsed.payee);
    final category = await _pickCategory(defaultCategory, parsed);
    if (!mounted || category == null) return;

    final added = await _addSingle(sms, parsed, category: category);
    await ref.read(accountListProvider.notifier).refresh();
    if (!mounted) return;

    if (!added) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Free tier allows up to $kFreeSmsParseLimit SMS parses per month. Upgrade to Pro for unlimited.',
          ),
          backgroundColor: context.colors.warning,
        ),
      );
    }
    await _refresh();
  }

  Future<void> _skipItem(SmsInboxData sms) async {
    await ref.read(smsRepositoryProvider).markSkipped(sms.id);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusLg),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Review Bank SMS',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '$_remainingThisMonth/$kFreeSmsParseLimit left this month',
                    style: TextStyle(color: colors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
              AppSizes.h16,
              if (_loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (!_hasPermission)
                Expanded(child: _buildPermissionRequest())
              else
                Expanded(child: _buildQueue()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionRequest() {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sms_rounded, color: colors.primaryLight, size: 48),
          AppSizes.h16,
          Text(
            'Detect transactions automatically',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          AppSizes.h8,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
            child: Text(
              _permanentlyDenied
                  ? 'SMS permission was denied. You can still add transactions manually, or enable it from system settings.'
                  : 'FinFlow can read bank and UPI SMS alerts on this device to suggest transactions -- nothing is sent anywhere; parsing happens entirely on your device. You can always add transactions manually instead.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          AppSizes.h24,
          ElevatedButton(
            onPressed: _permanentlyDenied
                ? openAppSettings
                : _requestPermission,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
            ),
            child: Text(
              _permanentlyDenied ? 'Open Settings' : 'Enable SMS Detection',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          AppSizes.h8,
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "I'll add transactions manually",
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueue() {
    final colors = context.colors;
    if (_queue.isEmpty) {
      return Center(
        child: Text(
          "You're all caught up.\nNo pending SMS to review.",
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textSecondary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _queue.length,
            itemBuilder: (context, index) {
              final sms = _queue[index];
              final parsed = SmsParser.parse(sms.messageBody);
              return Card(
                color: colors.cardBg,
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            sms.sender,
                            style: TextStyle(
                              color: colors.primaryLight,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            DateFormat('dd MMM hh:mm a').format(sms.date),
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      AppSizes.h8,
                      Text(
                        sms.messageBody,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                      if (parsed != null) ...[
                        AppSizes.h8,
                        Text(
                          '₹${parsed.amount.toStringAsFixed(2)} · ${parsed.payee} · Confidence: ${parsed.confidenceScore}%',
                          style: TextStyle(
                            color:
                                parsed.confidenceScore >= _autoAcceptConfidence
                                ? colors.success
                                : colors.warning,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ] else ...[
                        AppSizes.h8,
                        Text(
                          "Couldn't parse this message automatically.",
                          style: TextStyle(color: colors.error, fontSize: 11),
                        ),
                      ],
                      AppSizes.h12,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => _skipItem(sms),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: colors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radiusSm,
                                ),
                              ),
                            ),
                            child: Text(
                              'Skip',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          AppSizes.w8,
                          ElevatedButton(
                            onPressed: parsed != null
                                ? () => _addItem(sms)
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radiusSm,
                                ),
                              ),
                            ),
                            child: const Text(
                              'Add',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
