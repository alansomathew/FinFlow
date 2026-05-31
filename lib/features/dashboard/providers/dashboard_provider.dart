import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../transactions/presentation/providers/transaction_provider.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/constants/app_constants.dart';

String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

// ── AI Tip ────────────────────────────────────────────────────────────────
class AiTip {
  final String message;
  final String emoji;
  final String category;

  const AiTip(
      {required this.message,
      required this.emoji,
      required this.category});
}

// Simple rule-based tip generator (real AI would call an API)
final aiTipProvider = Provider<AiTip>((ref) {
  final summaryAsync = ref.watch(monthlySummaryProvider);

  return summaryAsync.when(
    data: (summary) {
      final savingsRate = summary.savingsRate;
      if (savingsRate < 10) {
        return const AiTip(
          message:
              "Your savings rate is below 10%. Try to cut wants spending to hit the 20% savings goal.",
          emoji: "⚠️",
          category: "Savings Alert",
        );
      } else if (savingsRate > 25) {
        return const AiTip(
          message:
              "Great savings rate this month! Consider investing the surplus in a SIP to grow your wealth.",
          emoji: "🚀",
          category: "Investment Opportunity",
        );
      } else {
        return const AiTip(
          message:
              "You're on track with the 50/30/20 rule. Keep monitoring your wants spending.",
          emoji: "✅",
          category: "On Track",
        );
      }
    },
    loading: () => const AiTip(
        message: "Analyzing your finances...",
        emoji: "🔍",
        category: "Insights"),
    error: (_, __) => const AiTip(
        message: "Track every expense to unlock personalized insights.",
        emoji: "💡",
        category: "Tip"),
  );
});

// ── Upcoming Bills (loans with EMI dates in next 7 days) ──────────────────
class UpcomingBill {
  final String name;
  final double amount;
  final DateTime dueDate;
  final String emoji;

  const UpcomingBill({
    required this.name,
    required this.amount,
    required this.dueDate,
    required this.emoji,
  });

  int get daysRemaining {
    final now = DateTime.now();
    return dueDate.difference(DateTime(now.year, now.month, now.day)).inDays;
  }
}

final upcomingBillsProvider = Provider<List<UpcomingBill>>((ref) {
  // Return empty list — real implementation queries recurring transactions
  // and loan EMI dates; populated via Firestore queries in production
  return const [];
});

// ── Net Worth History (last 6 months sparkline data) ─────────────────────
final netWorthHistoryProvider = FutureProvider<List<double>>((ref) async {
  if (_uid.isEmpty) return List.filled(6, 0.0);

  try {
    final months = DateFormatter.lastNMonths(6);
    final List<double> history = [];

    for (final month in months) {
      final monthKey = DateFormatter.firestoreMonthKey(month);
      final snap = await FirebaseFirestore.instance
          .collection(AppConstants.colUsers)
          .doc(_uid)
          .collection('netWorthHistory')
          .doc(monthKey)
          .get();

      history.add(
          snap.exists ? (snap.data()?['netWorth'] as num?)?.toDouble() ?? 0 : 0);
    }
    return history;
  } catch (_) {
    return List.filled(6, 0.0);
  }
});

// ── Daily Budget Remaining ────────────────────────────────────────────────
final dailyBudgetRemainingProvider = Provider<AsyncValue<double>>((ref) {
  final summaryAsync = ref.watch(monthlySummaryProvider);

  return summaryAsync.when(
    data: (summary) {
      final now = DateTime.now();
      final daysInMonth =
          DateFormatter.endOfMonth(now).difference(DateFormatter.startOfMonth(now)).inDays + 1;
      final daysPassed = now.day;
      final daysLeft = daysInMonth - daysPassed;

      final totalBudget = summary.totalIncome;
      final spent = summary.totalExpense;
      final remaining = totalBudget - spent;
      final dailyBudget = daysLeft > 0 ? remaining / daysLeft : 0.0;
      return AsyncValue.data(dailyBudget);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
  );
});
