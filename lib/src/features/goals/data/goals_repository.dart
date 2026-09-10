import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/app_database.dart';
import '../../../services/pro_tier_service.dart';
import '../../auth/data/auth_repository.dart';

const int kFreeGoalLimit = 3;

/// The percentage milestones a goal's progress bar celebrates. Checked by
/// comparing the ratio before and after a contribution so a milestone only
/// fires once, exactly when a contribution crosses it.
const List<double> goalMilestones = [0.25, 0.5, 0.75, 1.0];

class GoalModel {
  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;
  final String icon;
  final String colorHex;
  final String? linkedAccountId;

  GoalModel({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0.0,
    this.targetDate,
    this.icon = '🎯',
    this.colorHex = '#6366F1',
    this.linkedAccountId,
  });

  double get progress =>
      targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'target_date': targetDate?.toIso8601String(),
      'icon': icon,
      'color_hex': colorHex,
      'linked_account_id': linkedAccountId,
    };
  }

  factory GoalModel.fromMap(Map<String, dynamic> map) {
    return GoalModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      targetAmount: (map['target_amount'] as num?)?.toDouble() ?? 0.0,
      currentAmount: (map['current_amount'] as num?)?.toDouble() ?? 0.0,
      targetDate: map['target_date'] != null
          ? DateTime.tryParse(map['target_date'])
          : null,
      icon: map['icon'] ?? '🎯',
      colorHex: map['color_hex'] ?? '#6366F1',
      linkedAccountId: map['linked_account_id'],
    );
  }

  factory GoalModel.fromRow(Goal row) {
    return GoalModel(
      id: row.id,
      name: row.name,
      targetAmount: row.targetAmount,
      currentAmount: row.currentAmount,
      targetDate: row.targetDate,
      icon: row.icon,
      colorHex: row.colorHex,
      linkedAccountId: row.linkedAccountId,
    );
  }

  GoalsCompanion toCompanion() {
    return GoalsCompanion(
      id: Value(id),
      name: Value(name),
      targetAmount: Value(targetAmount),
      currentAmount: Value(currentAmount),
      targetDate: Value(targetDate),
      icon: Value(icon),
      colorHex: Value(colorHex),
      linkedAccountId: Value(linkedAccountId),
      updatedAt: Value(DateTime.now()),
    );
  }

  GoalModel copyWith({double? currentAmount}) {
    return GoalModel(
      id: id,
      name: name,
      targetAmount: targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate,
      icon: icon,
      colorHex: colorHex,
      linkedAccountId: linkedAccountId,
    );
  }
}

class GoalsRepository {
  final Ref _ref;
  GoalsRepository(this._ref);

  AppDatabase get _db => AppDatabase.instance;

  Future<List<GoalModel>> getGoals() async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      return _getLocalGoals();
    } else {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('goals')
            .get();
        return querySnapshot.docs
            .map((doc) => GoalModel.fromMap(doc.data()))
            .toList();
      } catch (e) {
        return _getLocalGoals();
      }
    }
  }

  Future<List<GoalModel>> _getLocalGoals() async {
    final rows = await (_db.select(
      _db.goals,
    )..where((t) => t.deletedAt.isNull())).get();
    return rows.map(GoalModel.fromRow).toList();
  }

  Future<int> countGoals() async => (await getGoals()).length;

  /// Free tier is capped at [kFreeGoalLimit] goals; Pro is unlimited.
  Future<bool> canAddGoal() async {
    final isPro = _ref.read(isProProvider).valueOrNull ?? false;
    if (isPro) return true;
    return (await countGoals()) < kFreeGoalLimit;
  }

  Future<void> saveGoal(GoalModel goal) async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      await _upsertLocal(goal);
    } else {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('goals')
            .doc(goal.id)
            .set(goal.toMap());
        await _upsertLocal(goal);
      } catch (e) {
        await _upsertLocal(goal);
      }
    }
  }

  Future<void> _upsertLocal(GoalModel goal) async {
    await _db.into(_db.goals).insertOnConflictUpdate(goal.toCompanion());
  }

  /// Adds [amount] to the goal's saved progress and returns the updated
  /// goal, so the caller can compare progress before/after to detect a
  /// crossed milestone.
  Future<GoalModel> contribute(GoalModel goal, double amount) async {
    final updated = goal.copyWith(currentAmount: goal.currentAmount + amount);
    await saveGoal(updated);
    return updated;
  }

  Future<void> deleteGoal(String id) async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      await _deleteLocal(id);
    } else {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('goals')
            .doc(id)
            .delete();
        await _deleteLocal(id);
      } catch (e) {
        await _deleteLocal(id);
      }
    }
  }

  Future<void> _deleteLocal(String id) async {
    await (_db.delete(_db.goals)..where((t) => t.id.equals(id))).go();
  }
}

final goalsRepositoryProvider = Provider<GoalsRepository>((ref) {
  return GoalsRepository(ref);
});

class GoalListNotifier extends StateNotifier<AsyncValue<List<GoalModel>>> {
  final GoalsRepository _repo;
  GoalListNotifier(this._repo) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final list = await _repo.getGoals();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> add(GoalModel goal) async {
    await _repo.saveGoal(goal);
    await refresh();
  }

  /// Contributes [amount] to [goal] and returns the crossed milestone
  /// ratio (e.g. 0.5), or null if no milestone was crossed by this
  /// contribution -- lets the UI decide whether to play a celebration.
  Future<double?> contribute(GoalModel goal, double amount) async {
    final before = goal.progress;
    final updated = await _repo.contribute(goal, amount);
    final after = updated.progress;
    await refresh();

    double? crossed;
    for (final milestone in goalMilestones) {
      if (before < milestone && after >= milestone) {
        crossed = milestone;
      }
    }
    return crossed;
  }

  Future<void> remove(String id) async {
    await _repo.deleteGoal(id);
    await refresh();
  }
}

final goalListProvider =
    StateNotifierProvider<GoalListNotifier, AsyncValue<List<GoalModel>>>((
      ref,
    ) {
      final repo = ref.watch(goalsRepositoryProvider);
      return GoalListNotifier(repo);
    });
