import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/savings_goal_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/local/local_database.dart';

String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

CollectionReference<Map<String, dynamic>> get _col =>
    FirebaseFirestore.instance
        .collection(AppConstants.colUsers)
        .doc(_uid)
        .collection(AppConstants.colSavingsGoals);

final _localDb = LocalDatabase.instance;

final savingsGoalsStreamProvider =
    StreamProvider<List<SavingsGoalModel>>((ref) async* {
  final isGuest = ref.watch(guestSessionProvider);
  if (isGuest) {
    final rows = await _localDb.getAll('savings_goals');
    yield rows
        .map(SavingsGoalModel.fromLocalMap)
        .where((g) => !g.isCompleted)
        .toList()
      ..sort((a, b) => a.targetDate.compareTo(b.targetDate));
    return;
  }
  yield* _col
      .where('isCompleted', isEqualTo: false)
      .orderBy('targetDate')
      .snapshots()
      .map((s) => s.docs.map((d) => SavingsGoalModel.fromFirestore(d)).toList());
});

final activeGoalsProvider = Provider<AsyncValue<List<SavingsGoalModel>>>((ref) {
  return ref.watch(savingsGoalsStreamProvider).when(
        data: (goals) => AsyncValue.data(
          goals.where((g) => !g.isPaused).toList(),
        ),
        loading: () => const AsyncValue.loading(),
        error: (e, s) => AsyncValue.error(e, s),
      );
});

class SavingsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  SavingsNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> addGoal(SavingsGoalModel goal) async {
    state = const AsyncValue.loading();
    try {
      final id = const Uuid().v4();
      final isGuest = _ref.read(guestSessionProvider);
      final newGoal = SavingsGoalModel(
        id: id,
        userId: isGuest ? 'guest' : _uid,
        name: goal.name,
        category: goal.category,
        targetAmount: goal.targetAmount,
        targetDate: goal.targetDate,
        linkedAccountId: goal.linkedAccountId,
        color: goal.color,
        emoji: goal.emoji,
        contributionMode: goal.contributionMode,
        monthlyContribution: goal.monthlyContribution,
        createdAt: DateTime.now(),
      );
      if (isGuest) {
        await _localDb.upsert('savings_goals', id, newGoal.toLocalMap());
      } else {
        await _col.doc(id).set(newGoal.toFirestore());
      }
      _ref.invalidate(savingsGoalsStreamProvider);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> addContribution(String goalId, double amount) async {
    state = const AsyncValue.loading();
    try {
      final isGuest = _ref.read(guestSessionProvider);
      if (isGuest) {
        final row = await _localDb.getById('savings_goals', goalId);
        if (row == null) return;
        final goal = SavingsGoalModel.fromLocalMap(row);
        final newAmount = goal.currentAmount + amount;
        final updated = goal.copyWith(
          currentAmount: newAmount,
          isCompleted: newAmount >= goal.targetAmount,
        );
        await _localDb.upsert('savings_goals', goalId, updated.toLocalMap());
      } else {
        await _col.doc(goalId).update({
          'currentAmount': FieldValue.increment(amount),
        });
        final doc = await _col.doc(goalId).get();
        final goal = SavingsGoalModel.fromFirestore(doc);
        if (goal.currentAmount >= goal.targetAmount) {
          await _col.doc(goalId).update({'isCompleted': true});
        }
      }
      _ref.invalidate(savingsGoalsStreamProvider);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> togglePause(String goalId, bool pause) async {
    final isGuest = _ref.read(guestSessionProvider);
    if (isGuest) {
      await _localDb.update('savings_goals', goalId, {'isPaused': pause ? 1 : 0});
    } else {
      await _col.doc(goalId).update({'isPaused': pause});
    }
    _ref.invalidate(savingsGoalsStreamProvider);
  }

  Future<void> deleteGoal(String goalId) async {
    final isGuest = _ref.read(guestSessionProvider);
    if (isGuest) {
      await _localDb.delete('savings_goals', goalId);
    } else {
      await _col.doc(goalId).delete();
    }
    _ref.invalidate(savingsGoalsStreamProvider);
  }
}

final savingsNotifierProvider =
    StateNotifierProvider<SavingsNotifier, AsyncValue<void>>(
  (ref) => SavingsNotifier(ref),
);

