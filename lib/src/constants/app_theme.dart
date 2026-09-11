import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// The semantic color set every screen actually paints with, as a
/// ThemeExtension so it flows through `Theme.of(context)` and swaps
/// automatically with light/dark mode. [AppColors] (the original
/// dark-only static palette) stays in place unchanged for screens that
/// haven't been migrated yet -- both can coexist while the app converts
/// screen-by-screen; a not-yet-migrated screen just stays dark-styled
/// until it's updated to read `context.colors` instead.
class AppColorExtension extends ThemeExtension<AppColorExtension> {
  final Color background;
  final Color surface;
  final Color cardBg;
  final Color primary;
  final Color primaryLight;
  final Color secondary;
  final Color needs;
  final Color wants;
  final Color savings;
  final Color income;
  final Color success;
  final Color warning;
  final Color error;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;

  const AppColorExtension({
    required this.background,
    required this.surface,
    required this.cardBg,
    required this.primary,
    required this.primaryLight,
    required this.secondary,
    required this.needs,
    required this.wants,
    required this.savings,
    required this.income,
    required this.success,
    required this.warning,
    required this.error,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
  });

  static const dark = AppColorExtension(
    background: AppColors.background,
    surface: AppColors.surface,
    cardBg: AppColors.cardBg,
    primary: AppColors.primary,
    primaryLight: AppColors.primaryLight,
    secondary: AppColors.secondary,
    needs: AppColors.needs,
    wants: AppColors.wants,
    savings: AppColors.savings,
    income: AppColors.income,
    success: AppColors.success,
    warning: AppColors.warning,
    error: AppColors.error,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textMuted: AppColors.textMuted,
    border: AppColors.border,
  );

  static const light = AppColorExtension(
    background: Color(0xFFF7F8FA),
    surface: Color(0xFFFFFFFF),
    cardBg: Color(0xFFFFFFFF),
    primary: AppColors.primary,
    primaryLight: Color(0xFF4F46E5),
    secondary: AppColors.secondary,
    needs: AppColors.needs,
    wants: AppColors.wants,
    savings: AppColors.savings,
    income: AppColors.income,
    success: AppColors.success,
    warning: AppColors.warning,
    error: AppColors.error,
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF6B7280),
    textMuted: Color(0xFF9CA3AF),
    border: Color(0xFFE5E7EB),
  );

  @override
  AppColorExtension copyWith({
    Color? background,
    Color? surface,
    Color? cardBg,
    Color? primary,
    Color? primaryLight,
    Color? secondary,
    Color? needs,
    Color? wants,
    Color? savings,
    Color? income,
    Color? success,
    Color? warning,
    Color? error,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
  }) {
    return AppColorExtension(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      cardBg: cardBg ?? this.cardBg,
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      secondary: secondary ?? this.secondary,
      needs: needs ?? this.needs,
      wants: wants ?? this.wants,
      savings: savings ?? this.savings,
      income: income ?? this.income,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
    );
  }

  @override
  AppColorExtension lerp(ThemeExtension<AppColorExtension>? other, double t) {
    if (other is! AppColorExtension) return this;
    return AppColorExtension(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      cardBg: Color.lerp(cardBg, other.cardBg, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      needs: Color.lerp(needs, other.needs, t)!,
      wants: Color.lerp(wants, other.wants, t)!,
      savings: Color.lerp(savings, other.savings, t)!,
      income: Color.lerp(income, other.income, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}

/// Shorthand for `Theme.of(context).extension<AppColorExtension>()!` --
/// use `context.colors.xxx` in migrated screens instead of the static
/// `AppColors.xxx`.
extension AppColorsContext on BuildContext {
  AppColorExtension get colors =>
      Theme.of(this).extension<AppColorExtension>()!;
}

class AppTheme {
  const AppTheme._();

  static ThemeData dark() => _build(Brightness.dark, AppColorExtension.dark);

  static ThemeData light() =>
      _build(Brightness.light, AppColorExtension.light);

  static ThemeData _build(Brightness brightness, AppColorExtension colors) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark()
        : ThemeData.light();

    return base.copyWith(
      brightness: brightness,
      scaffoldBackgroundColor: colors.background,
      primaryColor: colors.primary,
      colorScheme: (brightness == Brightness.dark
              ? const ColorScheme.dark()
              : const ColorScheme.light())
          .copyWith(
            primary: colors.primary,
            secondary: colors.secondary,
            surface: colors.surface,
            error: colors.error,
          ),
      textTheme: GoogleFonts.outfitTextTheme(base.textTheme).copyWith(
        bodyLarge: GoogleFonts.outfit(color: colors.textPrimary, fontSize: 16),
        bodyMedium: GoogleFonts.outfit(
          color: colors.textSecondary,
          fontSize: 14,
        ),
        titleLarge: GoogleFonts.outfit(
          color: colors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        elevation: 0,
      ),
      extensions: [colors],
    );
  }
}
