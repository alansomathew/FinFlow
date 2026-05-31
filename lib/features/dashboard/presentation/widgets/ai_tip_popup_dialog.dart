import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import '../../providers/ai_tip_popup_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

class AiTipPopupDialog extends ConsumerStatefulWidget {
  final AiTipPopupData tip;

  const AiTipPopupDialog({super.key, required this.tip});

  @override
  ConsumerState<AiTipPopupDialog> createState() => _AiTipPopupDialogState();
}

class _AiTipPopupDialogState extends ConsumerState<AiTipPopupDialog> {
  bool _loading = false;
  late AiTipPopupData _currentTip;

  @override
  void initState() {
    super.initState();
    _currentTip = widget.tip;
  }

  Color _getCategoryColor(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('need')) {
      return AppColors.needsColor;
    } else if (cat.contains('want') || cat.contains('alert') || cat.contains('warn')) {
      return AppColors.wantsColor;
    } else if (cat.contains('saving') || cat.contains('invest') || cat.contains('success')) {
      return AppColors.savingsColor;
    } else {
      return AppColors.primary;
    }
  }

  Future<void> _refreshTip() async {
    setState(() => _loading = true);
    final notifier = ref.read(aiTipPopupNotifierProvider.notifier);
    final newTip = await notifier.fetchPersonalizedTip(force: true);
    if (newTip != null && mounted) {
      setState(() {
        _currentTip = newTip;
        _loading = false;
      });
    } else if (mounted) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to generate a new tip. Please check your internet connection.'),
          backgroundColor: AppColors.expenseRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _getCategoryColor(_currentTip.category);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: FadeInUp(
          duration: const Duration(milliseconds: 400),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated.withOpacity(0.85),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: themeColor.withOpacity(0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: themeColor.withOpacity(0.12),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header Block with Dynamic Category
                  Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: themeColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: themeColor.withOpacity(0.3), width: 1),
                              ),
                              child: Text(
                                _currentTip.category.toUpperCase(),
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: themeColor,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        // Emoji and Title Line
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentTip.emoji,
                              style: const TextStyle(fontSize: 36),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _currentTip.title,
                                    style: AppTextStyles.headlineMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Main Message Body
                        Text(
                          _currentTip.message,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Action Item Highlight Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                themeColor.withOpacity(0.08),
                                themeColor.withOpacity(0.03),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: themeColor.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.auto_awesome, color: themeColor, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'TODAY\'S ACTION ITEM',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: themeColor,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _currentTip.actionItem,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Buttons
                        Row(
                          children: [
                            // Refresh Button
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: BorderSide(color: AppColors.border.withOpacity(0.5)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: _loading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(AppColors.primary),
                                        ),
                                      )
                                    : const Icon(Icons.refresh_rounded, size: 18, color: AppColors.textPrimary),
                                label: Text(
                                  _loading ? 'Analyzing...' : 'New Tip',
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: _loading ? null : _refreshTip,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Primary Dismiss Button
                            Expanded(
                              flex: 2,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      themeColor,
                                      themeColor.withOpacity(0.8),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: themeColor.withOpacity(0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: Text(
                                    'Got It',
                                    style: AppTextStyles.labelMedium.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
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
