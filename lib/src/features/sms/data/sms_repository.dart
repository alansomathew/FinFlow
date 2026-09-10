import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/app_database.dart';
import '../../../services/pro_tier_service.dart';

const int kFreeSmsParseLimit = 100;

/// Local-only queue of raw inbound SMS pending parse review. Unlike the other
/// feature repositories, this has no Firestore mirror yet — SMS review is a
/// device-local, pre-ledger staging step (see the review/sandbox sheets).
class SmsRepository {
  final Ref _ref;
  SmsRepository(this._ref);

  AppDatabase get _db => AppDatabase.instance;

  Future<List<SmsInboxData>> getPendingInbox() async {
    final query = _db.select(_db.smsInbox)
      ..where(
        (t) =>
            t.deletedAt.isNull() &
            t.isParsed.equals(false) &
            t.isSkipped.equals(false),
      )
      ..orderBy([(t) => OrderingTerm.desc(t.date)]);
    return query.get();
  }

  /// Returns true if a new row was inserted, false if [id] already existed --
  /// lets callers report an accurate "N new messages found" count when
  /// re-scanning the inbox. Checks existence explicitly rather than trusting
  /// insertOrIgnore's return value: SQLite's last_insert_rowid() is left
  /// unchanged by an ignored insert, so Drift's insert() returns the
  /// *previous* successful insert's rowid on conflict, not 0 -- there's no
  /// concurrent writer to this single-isolate local DB, so the check-then-
  /// insert has no real race to worry about.
  Future<bool> insertSms({
    required String id,
    required String messageBody,
    required String sender,
    required DateTime date,
  }) async {
    final existing = await (_db.select(
      _db.smsInbox,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing != null) return false;

    await _db
        .into(_db.smsInbox)
        .insert(
          SmsInboxCompanion.insert(
            id: id,
            messageBody: messageBody,
            sender: sender,
            date: date,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return true;
  }

  /// Marks an inbox item parsed/skipped without touching its original
  /// message content — the previous DbService-based implementation
  /// overwrote messageBody/sender/date with placeholder values on every
  /// status update, destroying the original SMS text.
  Future<void> markParsed(String id) async {
    await (_db.update(_db.smsInbox)..where((t) => t.id.equals(id))).write(
      SmsInboxCompanion(
        isParsed: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _db.recordSmsParsed();
  }

  Future<void> markSkipped(String id) async {
    await (_db.update(_db.smsInbox)..where((t) => t.id.equals(id))).write(
      SmsInboxCompanion(
        isSkipped: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Free tier is capped at [kFreeSmsParseLimit] parses/month; Pro is unlimited.
  Future<bool> canParseMoreThisMonth() async {
    final isPro = _ref.read(isProProvider).valueOrNull ?? false;
    if (isPro) return true;
    return (await _db.smsParsesThisMonth()) < kFreeSmsParseLimit;
  }

  Future<int> parsesRemainingThisMonth() async {
    final used = await _db.smsParsesThisMonth();
    return (kFreeSmsParseLimit - used).clamp(0, kFreeSmsParseLimit);
  }
}

final smsRepositoryProvider = Provider<SmsRepository>((ref) {
  return SmsRepository(ref);
});
