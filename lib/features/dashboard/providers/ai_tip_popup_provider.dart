import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../budget/presentation/providers/budget_provider.dart';
import '../../transactions/presentation/providers/transaction_provider.dart';
import '../../../../core/ai/gemini_api.dart';

class AiTipPopupData {
  final String title;
  final String message;
  final String actionItem;
  final String category;
  final String emoji;
  final String dateStr;

  AiTipPopupData({
    required this.title,
    required this.message,
    required this.actionItem,
    required this.category,
    required this.emoji,
    required this.dateStr,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'actionItem': actionItem,
      'category': category,
      'emoji': emoji,
      'dateStr': dateStr,
    };
  }

  factory AiTipPopupData.fromMap(Map<String, dynamic> map) {
    return AiTipPopupData(
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      actionItem: map['actionItem'] ?? '',
      category: map['category'] ?? '',
      emoji: map['emoji'] ?? '💡',
      dateStr: map['dateStr'] ?? '',
    );
  }
}

class AiTipPopupNotifier extends StateNotifier<AsyncValue<AiTipPopupData?>> {
  final Ref ref;
  AiTipPopupNotifier(this.ref) : super(const AsyncValue.data(null));

  static const _tipCacheKey = 'ai_personalized_tip_cache';
  static const _popupShownDateKey = 'ai_popup_last_shown_date';

  Future<void> initTip() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(_tipCacheKey);
    if (cachedJson != null) {
      try {
        final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
        final tip = AiTipPopupData.fromMap(decoded);
        state = AsyncValue.data(tip);
      } catch (_) {}
    }
  }

  Future<AiTipPopupData?> fetchPersonalizedTip({bool force = false}) async {
    if (!force && state.value != null) {
      final nowStr = _getTodayStr();
      if (state.value!.dateStr == nowStr) {
        return state.value;
      }
    }

    state = const AsyncValue.loading();
    try {
      final summary = ref.read(monthlySummaryProvider).valueOrNull;
      final bucketSummary = ref.read(bucketSummaryProvider).valueOrNull;
      final budget = ref.read(budgetWithSpendingProvider).valueOrNull;

      final double income = budget?.monthlyIncome ?? summary?.totalIncome ?? 0.0;
      final double needs = bucketSummary?.needsSpent ?? 0.0;
      final double wants = bucketSummary?.wantsSpent ?? 0.0;
      final double savings = bucketSummary?.savingsSpent ?? 0.0;
      final Map<String, double> categorySpend = summary?.byCategory ?? {};

      final result = await GeminiAI.getPersonalizedFinancialTip(
        income: income,
        needsSpent: needs,
        wantsSpent: wants,
        savingsSpent: savings,
        categorySpend: categorySpend,
      );

      if (result != null) {
        final nowStr = _getTodayStr();
        final tip = AiTipPopupData(
          title: result['title'] ?? 'Smart Budget Nudge',
          message: result['message'] ?? 'Keep tracking your daily expenses to see personalized insights.',
          actionItem: result['actionItem'] ?? 'Check your categories limit under budget tab.',
          category: result['category'] ?? 'Financial Tips',
          emoji: result['emoji'] ?? '💡',
          dateStr: nowStr,
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tipCacheKey, jsonEncode(tip.toMap()));
        state = AsyncValue.data(tip);
        return tip;
      } else {
        // Fallback to static rule-based tip if Gemini fails or is offline
        final nowStr = _getTodayStr();
        final double totalSpent = needs + wants + savings;
        final double surplus = income - totalSpent;
        final double savingsRate = income > 0 ? (surplus / income * 100) : 0.0;
        
        final tip = AiTipPopupData(
          title: savingsRate < 15 ? "Boost Your Savings!" : "Excellent Budgeting!",
          message: savingsRate < 15
              ? "Your current savings rate is around ${savingsRate.toStringAsFixed(1)}%. We recommend aiming for at least 20% of your income."
              : "Great job! You've saved ${savingsRate.toStringAsFixed(1)}% of your income this month, maintaining solid financial discipline.",
          actionItem: savingsRate < 15 
              ? "Try cutting back on non-essential dining/shopping wants this week." 
              : "Consider moving ₹5,000 of your surplus into an index fund or SIP.",
          category: "Budget Insight",
          emoji: savingsRate < 15 ? "⚠️" : "🏆",
          dateStr: nowStr,
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tipCacheKey, jsonEncode(tip.toMap()));
        state = AsyncValue.data(tip);
        return tip;
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> shouldShowPopupToday() async {
    final prefs = await SharedPreferences.getInstance();
    final lastShown = prefs.getString(_popupShownDateKey);
    final today = _getTodayStr();
    return lastShown != today;
  }

  Future<void> markPopupAsShownToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _getTodayStr();
    await prefs.setString(_popupShownDateKey, today);
  }

  String _getTodayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

final aiTipPopupNotifierProvider =
    StateNotifierProvider<AiTipPopupNotifier, AsyncValue<AiTipPopupData?>>((ref) {
  final notifier = AiTipPopupNotifier(ref);
  notifier.initTip();
  return notifier;
});
