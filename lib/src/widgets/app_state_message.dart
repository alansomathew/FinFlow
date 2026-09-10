import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';

/// One shared look for "nothing to show here" across the app -- an icon, a
/// message, and an optional retry action. Introduced in Analytics (which
/// reads from every other module, so it hit the most silent-failure spots
/// first) to replace the inconsistent mix of empty `Container()`s and bare
/// `Text('Error: $e')` scattered around loading/error/empty states.
class AppStateMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool isError;
  final VoidCallback? onRetry;

  const AppStateMessage({
    super.key,
    required this.icon,
    required this.message,
    this.isError = false,
    this.onRetry,
  });

  factory AppStateMessage.error(String detail, {VoidCallback? onRetry}) {
    return AppStateMessage(
      icon: Icons.error_outline_rounded,
      message: 'Something went wrong: $detail',
      isError: true,
      onRetry: onRetry,
    );
  }

  factory AppStateMessage.empty(String message, {IconData? icon}) {
    return AppStateMessage(icon: icon ?? Icons.inbox_rounded, message: message);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isError ? AppColors.error : AppColors.textSecondary,
              size: 36,
            ),
            AppSizes.h12,
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            if (onRetry != null) ...[
              AppSizes.h12,
              TextButton(
                onPressed: onRetry,
                child: const Text(
                  'Retry',
                  style: TextStyle(color: AppColors.primaryLight),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
