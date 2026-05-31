import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/category_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/local/local_database.dart';

String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

final _localDb = LocalDatabase.instance;

CollectionReference<Map<String, dynamic>> get _categoryCol =>
    FirebaseFirestore.instance
        .collection(AppConstants.colUsers)
        .doc(_uid)
        .collection(AppConstants.colCategories);

final customCategoriesStreamProvider =
    StreamProvider<List<CategoryModel>>((ref) async* {
  final isGuest = ref.watch(guestSessionProvider);
  if (isGuest) {
    final rows = await _localDb.getAll('categories');
    yield rows
        .map((row) => CategoryModel(
              id: row['id'] as String,
              name: row['name'] as String,
              emoji: row['emoji'] as String? ?? '📁',
              color: Color(row['colorValue'] as int? ?? 0xFF8E8E93),
              bucket: BudgetBucket.values.firstWhere(
                (b) => b.name == row['bucket'],
                orElse: () => BudgetBucket.wants,
              ),
              group: CategoryGroup.values.firstWhere(
                (g) => g.name == row['group'],
                orElse: () => CategoryGroup.expense,
              ),
              isCustom: true,
              isActive: row['isActive'] as bool? ?? true,
            ))
        .where((c) => c.isActive)
        .toList();
    return;
  }

  yield* _categoryCol
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((snap) => snap.docs.map(CategoryModel.fromFirestore).toList());
});

final allCategoriesProvider = Provider<List<CategoryModel>>((ref) {
  final custom = ref.watch(customCategoriesStreamProvider).valueOrNull ??
      const <CategoryModel>[];
  return [...CategoryModel.defaults, ...custom];
});

final categoriesByGroupProvider =
    Provider.family<List<CategoryModel>, CategoryGroup>((ref, group) {
  return ref
      .watch(allCategoriesProvider)
      .where((c) => c.group == group && c.isActive)
      .toList();
});

final categoryByIdProvider =
    Provider.family<CategoryModel, String>((ref, categoryId) {
  return ref.watch(allCategoriesProvider).firstWhere(
        (c) => c.id == categoryId,
        orElse: () => CategoryModel.byId(categoryId),
      );
});

class CategoryNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  CategoryNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> addCustomCategory({
    required String name,
    required String emoji,
    required CategoryGroup group,
    BudgetBucket? bucket,
  }) async {
    state = const AsyncValue.loading();
    try {
      final id = 'custom_${group.name}_${const Uuid().v4()}';
      final finalBucket = bucket ?? switch (group) {
        CategoryGroup.expense => BudgetBucket.wants,
        CategoryGroup.income => BudgetBucket.needs,
        CategoryGroup.investment => BudgetBucket.savings,
      };

      final category = CategoryModel(
        id: id,
        name: name.trim(),
        emoji: emoji,
        color: const Color(0xFF5C6BC0),
        bucket: finalBucket,
        group: group,
        isCustom: true,
      );

      final isGuest = _ref.read(guestSessionProvider);
      if (isGuest) {
        await _localDb.upsert('categories', id, {
          'id': category.id,
          'name': category.name,
          'emoji': category.emoji,
          'colorValue': category.color.toARGB32(),
          'bucket': category.bucket.name,
          'group': category.group.name,
          'isCustom': true,
          'isActive': true,
        });
      } else {
        await _categoryCol.doc(id).set(category.toFirestore());
      }

      _ref.invalidate(customCategoriesStreamProvider);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }
}

final categoryNotifierProvider =
    StateNotifierProvider<CategoryNotifier, AsyncValue<void>>(
  (ref) => CategoryNotifier(ref),
);
