import 'package:cloud_firestore/cloud_firestore.dart';
import '../local/local_database.dart';
import '../constants/app_constants.dart';

/// Reads every record from SQLite (guest mode) and batch-writes it to
/// Firestore under the authenticated user's UID, then clears local storage.
class GuestDataSync {
  GuestDataSync._();
  static final GuestDataSync instance = GuestDataSync._();

  final _db = LocalDatabase.instance;
  final _firestore = FirebaseFirestore.instance;

  static const _tableToCollection = {
    'transactions': AppConstants.colTransactions,
    'accounts': AppConstants.colAccounts,
    'budgets': AppConstants.colBudgets,
    'savings_goals': AppConstants.colSavingsGoals,
    'investments': AppConstants.colInvestments,
    'loans': AppConstants.colLoans,
  };

  /// Call this right after a successful Google sign-in.
  /// Returns the number of records migrated.
  Future<int> syncToFirestore(String uid) async {
    int count = 0;
    final WriteBatch batch = _firestore.batch();

    for (final entry in _tableToCollection.entries) {
      final rows = await _db.getAll(entry.key);
      if (rows.isEmpty) continue;

      final colRef = _firestore
          .collection(AppConstants.colUsers)
          .doc(uid)
          .collection(entry.value);

      for (final row in rows) {
        final id = row['id'] as String? ?? _firestore.collection('_').doc().id;
        // Stamp the real uid so queries work correctly
        final data = Map<String, dynamic>.from(row)..['userId'] = uid;
        // Convert stored ISO string dates back to Firestore Timestamps
        _convertDatesToTimestamps(data);
        batch.set(colRef.doc(id), data, SetOptions(merge: true));
        count++;
      }
    }

    if (count > 0) {
      await batch.commit();
      await _db.clearAll();
    }

    return count;
  }

  /// Recursively convert ISO-8601 date strings to Firestore [Timestamp]s.
  void _convertDatesToTimestamps(Map<String, dynamic> data) {
    for (final key in data.keys.toList()) {
      final val = data[key];
      if (val is String) {
        final dt = DateTime.tryParse(val);
        if (dt != null) {
          data[key] = Timestamp.fromDate(dt);
        }
      } else if (val is Map<String, dynamic>) {
        _convertDatesToTimestamps(val);
      } else if (val is List) {
        for (final item in val) {
          if (item is Map<String, dynamic>) _convertDatesToTimestamps(item);
        }
      }
    }
  }
}
