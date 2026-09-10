import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/app_database.dart';
import '../../../utils/month_key.dart';
import '../domain/net_worth_calculator.dart';

class NetWorthHistoryPoint {
  final DateTime date;
  final double netWorth;

  const NetWorthHistoryPoint({required this.date, required this.netWorth});
}

/// Local-only history of daily net-worth readings, backing the Pro net
/// worth trend chart. Deliberately not synced to Firestore like the rest
/// of the app's data -- it's a derived trend rather than user-entered
/// data, so on a fresh device it simply starts building history from that
/// point forward rather than needing to carry a cloud copy.
class NetWorthRepository {
  AppDatabase get _db => AppDatabase.instance;

  /// Upserts today's snapshot -- calling this more than once in a day just
  /// overwrites today's row with the latest figures rather than creating
  /// duplicates.
  Future<void> recordTodaySnapshot(NetWorthTotals snapshot) async {
    final today = _dayKey(DateTime.now());
    await _db.into(_db.netWorthSnapshots).insertOnConflictUpdate(
      NetWorthSnapshotsCompanion.insert(
        date: today,
        assets: snapshot.assets,
        liabilities: snapshot.liabilities,
      ),
    );
  }

  Future<List<NetWorthHistoryPoint>> getHistory({int days = 90}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final rows = await (_db.select(_db.netWorthSnapshots)
          ..where((t) => t.date.isBiggerOrEqualValue(_dayKey(cutoff)))
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();
    return rows
        .map(
          (r) => NetWorthHistoryPoint(
            date: DateTime.parse(r.date),
            netWorth: r.assets - r.liabilities,
          ),
        )
        .toList();
  }

  String _dayKey(DateTime date) =>
      '${monthKeyOf(date)}-${date.day.toString().padLeft(2, '0')}';
}

final netWorthRepositoryProvider = Provider<NetWorthRepository>((ref) {
  return NetWorthRepository();
});
