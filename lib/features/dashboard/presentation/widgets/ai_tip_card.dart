import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/ai_tip_popup_provider.dart';
import './ai_tip_popup_dialog.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

class AiTipCard extends ConsumerWidget {
  const AiTipCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personalizedTipAsync = ref.watch(aiTipPopupNotifierProvider);
    final fallbackTip = ref.watch(aiTipProvider);

    final String emoji;
    final String category;
    final String message;

    final personalizedTip = personalizedTipAsync.valueOrNull;
    if (personalizedTip != null) {
      emoji = personalizedTip.emoji;
      category = personalizedTip.category;
      message = personalizedTip.message;
    } else {
      emoji = fallbackTip.emoji;
      category = fallbackTip.category;
      message = fallbackTip.message;
    }

    return GestureDetector(
      onTap: () async {
        final notifier = ref.read(aiTipPopupNotifierProvider.notifier);
        final tip = personalizedTip ?? await notifier.fetchPersonalizedTip();
        if (tip != null && context.mounted) {
          showDialog(
            context: context,
            barrierColor: Colors.black.withOpacity(0.6),
            builder: (context) => AiTipPopupDialog(tip: tip),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: AppTextStyles.bodySmall,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
