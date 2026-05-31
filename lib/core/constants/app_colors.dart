import 'package:flutter/material.dart';

/// FinFlow Color System — Dark Mode First
class AppColors {
  AppColors._();

  // ── Brand Colors ────────────────────────────────────────────
  static const Color primary = Color(0xFF6C63FF);      // Indigo-violet
  static const Color primaryLight = Color(0xFF9B95FF);
  static const Color primaryDark = Color(0xFF4B43D9);

  static const Color accent = Color(0xFF00C896);        // Emerald green
  static const Color accentLight = Color(0xFF4DDBA8);
  static const Color accentDark = Color(0xFF009970);

  // ── 50/30/20 Bucket Colors ──────────────────────────────────
  static const Color needs = Color(0xFF4A9EFF);         // Blue — Needs
  static const Color wants = Color(0xFFFFB547);         // Amber — Wants
  static const Color savings = Color(0xFF00C896);       // Green — Savings

  // ── Semantic Colors ─────────────────────────────────────────
  static const Color income = Color(0xFF00C896);        // Credit / Income
  static const Color expense = Color(0xFFFF6B6B);       // Debit / Expense
  static const Color warning = Color(0xFFFFB547);
  static const Color error = Color(0xFFFF6B6B);
  static const Color success = Color(0xFF00C896);
  static const Color info = Color(0xFF4A9EFF);

  // ── Dark Theme Surfaces ─────────────────────────────────────
  static const Color darkBackground = Color(0xFF0F0F1A);
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color darkCard = Color(0xFF252538);
  static const Color darkCardAlt = Color(0xFF1E1E35);
  static const Color darkDivider = Color(0xFF2A2A42);
  static const Color darkBorder = Color(0xFF3A3A55);

  // ── Light Theme Surfaces ────────────────────────────────────
  static const Color lightBackground = Color(0xFFF5F5F8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightDivider = Color(0xFFE8E8F0);
  static const Color lightBorder = Color(0xFFD5D5E0);

  // ── Text Colors ─────────────────────────────────────────────
  static const Color textPrimaryDark = Color(0xFFF2F2FF);
  static const Color textSecondaryDark = Color(0xFF9898B8);
  static const Color textTertiaryDark = Color(0xFF5A5A7A);

  static const Color textPrimaryLight = Color(0xFF1A1A2E);
  static const Color textSecondaryLight = Color(0xFF5A5A7A);
  static const Color textTertiaryLight = Color(0xFF9898B8);

  // ── Chart Colors ─────────────────────────────────────────────
  static const List<Color> chartPalette = [
    Color(0xFF6C63FF),
    Color(0xFF00C896),
    Color(0xFFFFB547),
    Color(0xFFFF6B6B),
    Color(0xFF4A9EFF),
    Color(0xFFFF8FAB),
    Color(0xFF7EC8E3),
    Color(0xFFD4A5FF),
    Color(0xFF82E0AA),
    Color(0xFFF7DC6F),
  ];

  // ── Category Colors ──────────────────────────────────────────
  static const Color catFood = Color(0xFFFF8C42);
  static const Color catTransport = Color(0xFF4A9EFF);
  static const Color catShopping = Color(0xFFFF6B9D);
  static const Color catEntertainment = Color(0xFF9B7FFF);
  static const Color catHealth = Color(0xFF00C896);
  static const Color catUtilities = Color(0xFF4DBEE8);
  static const Color catEducation = Color(0xFFFFCB2F);
  static const Color catInvestment = Color(0xFF6C63FF);
  static const Color catEMI = Color(0xFFFF6B6B);
  static const Color catOther = Color(0xFF9898B8);

  // ── Gradient Definitions ─────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF4A9EFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient incomeGradient = LinearGradient(
    colors: [Color(0xFF00C896), Color(0xFF4DDBA8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient expenseGradient = LinearGradient(
    colors: [Color(0xFFFF6B6B), Color(0xFFFF8FAB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF252538), Color(0xFF1E1E35)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient netWorthGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF9B7FFF), Color(0xFF4A9EFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Convenience Aliases ────────────────────────────────────────────────────
  static const Color background = darkBackground;
  static const Color surfaceCard = darkCard;
  static const Color surfaceElevated = darkCardAlt;
  static const Color border = darkBorder;
  static const Color textPrimary = textPrimaryDark;
  static const Color textSecondary = textSecondaryDark;
  static const Color textDisabled = textTertiaryDark;
  static const Color needsColor = needs;
  static const Color wantsColor = wants;
  static const Color savingsColor = savings;
  static const Color incomeGreen = income;
  static const Color expenseRed = expense;
}
