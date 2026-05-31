import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../constants/app_text_styles.dart';
import '../utils/currency_formatter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onSeeAll;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: AppTextStyles.headlineSmall),
          ),
          if (onSeeAll != null || actionLabel != null)
            TextButton(
              onPressed: onSeeAll ?? onAction,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                onSeeAll != null ? 'See All' : actionLabel!,
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App Card
// ─────────────────────────────────────────────────────────────────────────────
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final VoidCallback? onTap;
  final double? borderRadius;
  final Gradient? gradient;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.onTap,
    this.borderRadius,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = color ?? (isDark ? AppColors.darkCard : AppColors.lightCard);

    return Container(
      decoration: BoxDecoration(
        color: gradient == null ? bgColor : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(
          borderRadius ?? AppConstants.radiusMd,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(
          borderRadius ?? AppConstants.radiusMd,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(
            borderRadius ?? AppConstants.radiusMd,
          ),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppConstants.spacingMd),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Amount Display
// ─────────────────────────────────────────────────────────────────────────────
class AmountText extends StatelessWidget {
  final double amount;
  final bool isExpense;
  final bool? isIncome;
  final TextStyle? style;
  final bool compact;
  final bool showSign;

  const AmountText({
    super.key,
    required this.amount,
    this.isExpense = false,
    this.isIncome,
    this.style,
    this.compact = false,
    this.showSign = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool expense = isIncome != null ? !isIncome! : isExpense;
    final sign = showSign ? (expense ? '- ' : '+ ') : '';
    final text = compact
        ? CurrencyFormatter.formatCompact(amount)
        : CurrencyFormatter.format(amount);
    final color = expense ? AppColors.expense : AppColors.income;

    return Text(
      '$sign$text',
      style: (style ?? AppTextStyles.amountSmall).copyWith(color: color),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Budget Progress Bar
// ─────────────────────────────────────────────────────────────────────────────
class BudgetProgressBar extends StatelessWidget {
  final double spent;
  final double total;
  final double height;
  final Color? color;

  const BudgetProgressBar({
    super.key,
    required this.spent,
    required this.total,
    this.height = 6,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? (spent / total).clamp(0.0, 1.0) : 0.0;
    final Color barColor;
    if (color != null) {
      barColor = color!;
    } else if (progress >= 1.0) {
      barColor = AppColors.error;
    } else if (progress >= 0.8) {
      barColor = AppColors.warning;
    } else {
      barColor = AppColors.primary;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: height,
        backgroundColor: AppColors.darkDivider,
        valueColor: AlwaysStoppedAnimation<Color>(barColor),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category Chip
// ─────────────────────────────────────────────────────────────────────────────
class CategoryChip extends StatelessWidget {
  final String label;
  final Color color;
  final String emoji;
  final bool selected;
  final VoidCallback? onTap;

  const CategoryChip({
    super.key,
    required this.label,
    required this.color,
    required this.emoji,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppConstants.animFast,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.2) : AppColors.darkCard,
          border: Border.all(
            color: selected ? color : AppColors.darkBorder,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: selected ? color : AppColors.textSecondaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────
class EmptyStateWidget extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key,
    this.emoji = '📭',
    this.title = '',
    this.subtitle = '',
    this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTextStyles.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message ?? subtitle,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(160, 48),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading Shimmer Card
// ─────────────────────────────────────────────────────────────────────────────
class ShimmerCard extends StatelessWidget {
  final double height;
  final double? width;

  const ShimmerCard({super.key, this.height = 80, this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width ?? double.infinity,
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gradient Button
// ─────────────────────────────────────────────────────────────────────────────
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final VoidCallback? onTap;
  final bool isLoading;
  final Gradient gradient;
  final double height;
  final IconData? icon;

  const GradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.onTap,
    this.isLoading = false,
    this.gradient = AppColors.primaryGradient,
    this.height = 52,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: (onTap ?? onPressed) != null ? gradient : null,
        color: (onTap ?? onPressed) != null ? null : AppColors.darkBorder,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        child: InkWell(
          onTap: isLoading ? null : (onTap ?? onPressed),
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: AppTextStyles.buttonLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat Badge
// ─────────────────────────────────────────────────────────────────────────────
class StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String? icon;

  const StatBadge({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(color: color),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTextStyles.labelLarge.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Color Dot
// ─────────────────────────────────────────────────────────────────────────────
class ColorDot extends StatelessWidget {
  final Color color;
  final double size;

  const ColorDot({super.key, required this.color, this.size = 10});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info Row (label + value)
// ─────────────────────────────────────────────────────────────────────────────
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppTextStyles.bodyMedium),
          ),
          Text(
            value,
            style: AppTextStyles.labelLarge.copyWith(color: valueColor),
          ),
        ],
      ),
    );
  }
}
