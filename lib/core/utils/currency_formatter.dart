import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _inrFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: AppConstants.currencySymbol,
    decimalDigits: 2,
  );

  // Removed unused _inrCompactFormat

  /// Format amount with ₹ symbol and Indian number system
  /// e.g., 1234567.89 → ₹12,34,567.89
  static String format(double amount) => _inrFormat.format(amount);

  /// Format without decimals
  /// e.g., 1234567 → ₹12,34,567
  static String formatNoDecimal(double amount) {
    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: AppConstants.currencySymbol,
      decimalDigits: 0,
    );
    return fmt.format(amount);
  }

  /// Compact format — e.g., 1234567 → ₹12.3L or ₹1.2Cr
  static String formatCompact(double amount) {
    if (amount.abs() >= 10000000) {
      return '${AppConstants.currencySymbol}${(amount / 10000000).toStringAsFixed(2)}Cr';
    } else if (amount.abs() >= 100000) {
      return '${AppConstants.currencySymbol}${(amount / 100000).toStringAsFixed(2)}L';
    } else if (amount.abs() >= 1000) {
      return '${AppConstants.currencySymbol}${(amount / 1000).toStringAsFixed(1)}K';
    }
    return format(amount);
  }

  /// Format percentage change with sign
  /// e.g., 12.5 → +12.5%   -3.2 → -3.2%
  static String formatPercent(double percent, {int decimals = 2}) {
    final sign = percent >= 0 ? '+' : '';
    return '$sign${percent.toStringAsFixed(decimals)}%';
  }

  /// Parse a currency string back to double
  static double? parse(String value) {
    final cleaned = value
        .replaceAll(AppConstants.currencySymbol, '')
        .replaceAll(',', '')
        .trim();
    return double.tryParse(cleaned);
  }

  /// Format number as Indian system without symbol
  /// e.g., 1234567 → 12,34,567
  static String formatNumber(double amount) {
    final fmt = NumberFormat('#,##,##0.##', 'en_IN');
    return fmt.format(amount);
  }
}
