import 'package:flutter/material.dart';

class AppColors {
  // Theme Backgrounds
  static const Color background = Color(0xFF0F0F12);
  static const Color surface = Color(0xFF1E1E24);
  static const Color cardBg = Color(0xFF25252E);
  
  // Brand / Main Accents
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color secondary = Color(0xFFEC4899); // Pink
  
  // 50/30/20 Budget Buckets
  static const Color needs = Color(0xFF1A56DB);     // Blue
  static const Color wants = Color(0xFFD97706);     // Amber
  static const Color savings = Color(0xFF059669);   // Green
  static const Color income = Color(0xFF9333EA);    // Purple
  
  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  
  // Neutrals / Typography
  static const Color textPrimary = Color(0xFFF9FAFB);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color border = Color(0xFF374151);
  
  // Gradients
  static const Gradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF4F46E5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient accentGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
