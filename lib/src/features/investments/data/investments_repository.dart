import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/app_database.dart';
import '../../auth/data/auth_repository.dart';

class InvestmentModel {
  final String id;
  final String type; // 'SIP', 'Mutual Fund', 'Stock'
  final String name;
  final double unitsQuantity;
  final double purchasePrice;
  final double currentPrice;
  final String datePurchased;

  InvestmentModel({
    required this.id,
    required this.type,
    required this.name,
    required this.unitsQuantity,
    required this.purchasePrice,
    required this.currentPrice,
    required this.datePurchased,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'units_quantity': unitsQuantity,
      'purchase_price': purchasePrice,
      'current_price': currentPrice,
      'date_purchased': datePurchased,
    };
  }

  factory InvestmentModel.fromMap(Map<String, dynamic> map) {
    return InvestmentModel(
      id: map['id'] ?? '',
      type: map['type'] ?? 'Stock',
      name: map['name'] ?? '',
      unitsQuantity: (map['units_quantity'] as num?)?.toDouble() ?? 0.0,
      purchasePrice: (map['purchase_price'] as num?)?.toDouble() ?? 0.0,
      currentPrice: (map['current_price'] as num?)?.toDouble() ?? 0.0,
      datePurchased: map['date_purchased'] ?? '',
    );
  }

  factory InvestmentModel.fromRow(Investment row) {
    return InvestmentModel(
      id: row.id,
      type: row.type,
      name: row.name,
      unitsQuantity: row.unitsQuantity,
      purchasePrice: row.purchasePrice,
      currentPrice: row.currentPrice,
      datePurchased: row.datePurchased,
    );
  }

  InvestmentsCompanion toCompanion() {
    return InvestmentsCompanion(
      id: Value(id),
      type: Value(type),
      name: Value(name),
      unitsQuantity: Value(unitsQuantity),
      purchasePrice: Value(purchasePrice),
      currentPrice: Value(currentPrice),
      datePurchased: Value(datePurchased),
      updatedAt: Value(DateTime.now()),
    );
  }
}

class InvestmentsRepository {
  final Ref _ref;
  InvestmentsRepository(this._ref);

  AppDatabase get _db => AppDatabase.instance;

  Future<List<InvestmentModel>> getInvestments() async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      return _getLocalInvestments();
    } else {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('investments')
            .get();
        return querySnapshot.docs.map((doc) => InvestmentModel.fromMap(doc.data())).toList();
      } catch (e) {
        return _getLocalInvestments();
      }
    }
  }

  Future<List<InvestmentModel>> _getLocalInvestments() async {
    final rows = await (_db.select(_db.investments)..where((t) => t.deletedAt.isNull())).get();
    return rows.map(InvestmentModel.fromRow).toList();
  }

  Future<void> addInvestment(InvestmentModel investment) async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      await _upsertLocal(investment);
    } else {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('investments')
            .doc(investment.id)
            .set(investment.toMap());
        await _upsertLocal(investment);
      } catch (e) {
        await _upsertLocal(investment);
      }
    }
  }

  Future<void> _upsertLocal(InvestmentModel investment) async {
    await _db.into(_db.investments).insertOnConflictUpdate(investment.toCompanion());
  }

  Future<void> deleteInvestment(String id) async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      await _deleteLocal(id);
    } else {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('investments')
            .doc(id)
            .delete();
        await _deleteLocal(id);
      } catch (e) {
        await _deleteLocal(id);
      }
    }
  }

  Future<void> _deleteLocal(String id) async {
    await (_db.delete(_db.investments)..where((t) => t.id.equals(id))).go();
  }
}

final investmentsRepositoryProvider = Provider<InvestmentsRepository>((ref) {
  return InvestmentsRepository(ref);
});

class InvestmentListNotifier extends StateNotifier<AsyncValue<List<InvestmentModel>>> {
  final InvestmentsRepository _repo;
  InvestmentListNotifier(this._repo) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final list = await _repo.getInvestments();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> add(InvestmentModel investment) async {
    await _repo.addInvestment(investment);
    await refresh();
  }

  Future<void> remove(String id) async {
    await _repo.deleteInvestment(id);
    await refresh();
  }
}

final investmentListProvider = StateNotifierProvider<InvestmentListNotifier, AsyncValue<List<InvestmentModel>>>((ref) {
  final repo = ref.watch(investmentsRepositoryProvider);
  return InvestmentListNotifier(repo);
});
