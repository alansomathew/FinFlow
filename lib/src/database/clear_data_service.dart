import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'app_database.dart';

/// Result of a "Clear All Data" attempt.
enum ClearDataResult { success, failed }

/// Every per-user Firestore subcollection any repository writes to. Kept as
/// one list here rather than scattering it across each repository, since
/// wiping everything is the one place that genuinely needs to know about
/// all of them at once.
const _syncedCollections = [
  'accounts',
  'transactions',
  'budgets',
  'loans',
  'investments',
  'goals',
  'monthlyIncome',
  'sms_inbox',
  'customCategories',
];

class ClearDataService {
  /// Deletes every synced collection under `users/{uid}` (skipped entirely
  /// for guests, who have no cloud copy) and then wipes the local database
  /// regardless. Cloud deletion happens first and, unlike the guest
  /// migration path, a failure there is NOT swallowed into "clear local
  /// anyway" -- every repository reads Firestore-first for a signed-in
  /// user, so a local wipe that leaves stale cloud data behind would just
  /// have that data silently reappear on the next read, making "Clear All
  /// Data" look like it silently failed rather than genuinely failing.
  static Future<ClearDataResult> clearAll({required String? uid}) async {
    if (uid != null) {
      try {
        final fs = FirebaseFirestore.instance;
        for (final collection in _syncedCollections) {
          final snapshot = await fs
              .collection('users')
              .doc(uid)
              .collection(collection)
              .get();
          if (snapshot.docs.isEmpty) continue;
          // Firestore batches cap at 500 writes; chunk defensively even
          // though a personal-finance dataset is realistically far smaller.
          for (var i = 0; i < snapshot.docs.length; i += 400) {
            final batch = fs.batch();
            for (final doc in snapshot.docs.skip(i).take(400)) {
              batch.delete(doc.reference);
            }
            await batch.commit();
          }
        }
      } catch (e) {
        debugPrint('Clear All Data: cloud wipe failed, local left intact: $e');
        return ClearDataResult.failed;
      }
    }

    await AppDatabase.instance.clearAllData();
    return ClearDataResult.success;
  }
}
