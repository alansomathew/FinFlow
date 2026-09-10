import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../database/app_database.dart';
import '../../../services/pro_tier_service.dart';
import '../domain/transaction.dart';
import 'transaction_repository.dart';

const int kFreeRecurringLimit = 5;

class RecurringRepository {
  final Ref _ref;
  RecurringRepository(this._ref);

  AppDatabase get _db => AppDatabase.instance;

  Future<List<RecurringRule>> getActiveRules() {
    return (_db.select(
      _db.recurringRules,
    )..where((t) => t.isActive.equals(true))).get();
  }

  Future<int> countActiveRules() async => (await getActiveRules()).length;

  /// Free tier is capped at [kFreeRecurringLimit] active rules; Pro is unlimited.
  Future<bool> canAddRule() async {
    final isPro = _ref.read(isProProvider).valueOrNull ?? false;
    if (isPro) return true;
    return (await countActiveRules()) < kFreeRecurringLimit;
  }

  Future<void> addRule({
    required double amount,
    required String category,
    required BudgetBucket bucket,
    required String accountId,
    required String payee,
    required String note,
    required String frequency,
    required DateTime nextDueDate,
  }) async {
    await _db
        .into(_db.recurringRules)
        .insert(
          RecurringRulesCompanion.insert(
            id: const Uuid().v4(),
            amount: amount,
            category: category,
            bucket: bucket.name,
            accountId: accountId,
            payee: payee,
            note: Value(note.isEmpty ? null : note),
            frequency: frequency,
            nextDueDate: nextDueDate,
          ),
        );
  }

  Future<void> deactivate(String id) async {
    await (_db.update(_db.recurringRules)..where((t) => t.id.equals(id))).write(
      const RecurringRulesCompanion(isActive: Value(false)),
    );
  }

  DateTime _advance(DateTime date, String frequency) {
    switch (frequency) {
      case 'daily':
        return date.add(const Duration(days: 1));
      case 'weekly':
        return date.add(const Duration(days: 7));
      case 'monthly':
      default:
        return DateTime(date.year, date.month + 1, date.day);
    }
  }

  /// Materializes every due occurrence of every active rule into a real
  /// transaction, catching up if multiple periods elapsed while the app was
  /// closed (e.g. a monthly rule due twice because the app wasn't opened for
  /// two months). Runs client-side on app-open; Phase 4's Cloud Function
  /// makes this reliable even when the app never reopens.
  Future<int> materializeDueRules() async {
    final txRepo = _ref.read(transactionRepositoryProvider);
    final rules = await getActiveRules();
    final now = DateTime.now();
    var materialized = 0;

    for (final rule in rules) {
      var nextDue = rule.nextDueDate;
      while (!nextDue.isAfter(now)) {
        final bucket = BudgetBucket.values.firstWhere(
          (b) => b.name == rule.bucket,
          orElse: () => BudgetBucket.wants,
        );
        await txRepo.addTransaction(
          TransactionModel(
            id: const Uuid().v4(),
            amount: rule.amount,
            category: rule.category,
            bucket: bucket,
            accountId: rule.accountId,
            date: nextDue,
            payee: rule.payee,
            note: rule.note ?? '',
            isRecurring: true,
          ),
        );
        materialized++;
        nextDue = _advance(nextDue, rule.frequency);
      }
      if (nextDue != rule.nextDueDate) {
        await (_db.update(
          _db.recurringRules,
        )..where((t) => t.id.equals(rule.id))).write(
          RecurringRulesCompanion(
            nextDueDate: Value(nextDue),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    }
    return materialized;
  }
}

final recurringRepositoryProvider = Provider<RecurringRepository>((ref) {
  return RecurringRepository(ref);
});
