import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/app_database.dart';
import '../../auth/data/auth_repository.dart';
import '../../transactions/domain/transaction.dart';

class CustomCategoryModel {
  final String id;
  final String name;
  final String icon;
  final String colorHex;
  final BudgetBucket bucket;

  CustomCategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorHex,
    required this.bucket,
  });

  TransactionCategory toTransactionCategory() => TransactionCategory(
    name: name,
    icon: icon,
    bucket: bucket,
    colorHex: colorHex,
  );

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color_hex': colorHex,
      'bucket': bucket.name,
    };
  }

  factory CustomCategoryModel.fromMap(Map<String, dynamic> map) {
    return CustomCategoryModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      icon: map['icon'] ?? '📝',
      colorHex: map['color_hex'] ?? '#6366F1',
      bucket: BudgetBucket.values.firstWhere(
        (b) => b.name == map['bucket'],
        orElse: () => BudgetBucket.wants,
      ),
    );
  }

  factory CustomCategoryModel.fromRow(CustomCategory row) {
    return CustomCategoryModel(
      id: row.id,
      name: row.name,
      icon: row.icon,
      colorHex: row.colorHex,
      bucket: BudgetBucket.values.firstWhere(
        (b) => b.name == row.bucket,
        orElse: () => BudgetBucket.wants,
      ),
    );
  }

  CustomCategoriesCompanion toCompanion() {
    return CustomCategoriesCompanion(
      id: Value(id),
      name: Value(name),
      icon: Value(icon),
      colorHex: Value(colorHex),
      bucket: Value(bucket.name),
      updatedAt: Value(DateTime.now()),
    );
  }

  // Value equality by name, matching TransactionCategory -- a custom
  // category and its TransactionCategory projection need to compare equal
  // wherever both end up in the same dropdown-style items list.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CustomCategoryModel && other.name == name);

  @override
  int get hashCode => name.hashCode;
}

class CustomCategoriesRepository {
  final Ref _ref;
  CustomCategoriesRepository(this._ref);

  AppDatabase get _db => AppDatabase.instance;

  Future<List<CustomCategoryModel>> getCustomCategories() async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      return _getLocalCustomCategories();
    } else {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('customCategories')
            .get();
        return querySnapshot.docs
            .map((doc) => CustomCategoryModel.fromMap(doc.data()))
            .toList();
      } catch (e) {
        return _getLocalCustomCategories();
      }
    }
  }

  Future<List<CustomCategoryModel>> _getLocalCustomCategories() async {
    final rows = await (_db.select(
      _db.customCategories,
    )..where((t) => t.deletedAt.isNull())).get();
    return rows.map(CustomCategoryModel.fromRow).toList();
  }

  Future<void> saveCustomCategory(CustomCategoryModel category) async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      await _upsertLocal(category);
    } else {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('customCategories')
            .doc(category.id)
            .set(category.toMap());
        await _upsertLocal(category);
      } catch (e) {
        await _upsertLocal(category);
      }
    }
  }

  Future<void> _upsertLocal(CustomCategoryModel category) async {
    await _db
        .into(_db.customCategories)
        .insertOnConflictUpdate(category.toCompanion());
  }
}

final customCategoriesRepositoryProvider = Provider<CustomCategoriesRepository>((
  ref,
) {
  return CustomCategoriesRepository(ref);
});

class CustomCategoryListNotifier
    extends StateNotifier<AsyncValue<List<CustomCategoryModel>>> {
  final CustomCategoriesRepository _repo;
  CustomCategoryListNotifier(this._repo) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final list = await _repo.getCustomCategories();
      TransactionCategory.updateCustomRegistry(
        list.map((c) => c.toTransactionCategory()).toList(),
      );
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> add(CustomCategoryModel category) async {
    await _repo.saveCustomCategory(category);
    await refresh();
  }
}

final customCategoryListProvider =
    StateNotifierProvider<
      CustomCategoryListNotifier,
      AsyncValue<List<CustomCategoryModel>>
    >((ref) {
      final repo = ref.watch(customCategoriesRepositoryProvider);
      return CustomCategoryListNotifier(repo);
    });
