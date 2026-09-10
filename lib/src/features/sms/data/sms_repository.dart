import 'package:drift/drift.dart';
import '../../../database/app_database.dart';

/// Local-only queue of raw inbound SMS pending parse review. Unlike the other
/// feature repositories, this has no Firestore mirror yet — SMS review is a
/// device-local, pre-ledger staging step (see the sandbox UI).
class SmsRepository {
  AppDatabase get _db => AppDatabase.instance;

  Future<List<SmsInboxData>> getPendingInbox() async {
    final query = _db.select(_db.smsInbox)
      ..where((t) => t.deletedAt.isNull() & t.isParsed.equals(false) & t.isSkipped.equals(false))
      ..orderBy([(t) => OrderingTerm.desc(t.date)]);
    return query.get();
  }

  Future<void> insertSms({
    required String id,
    required String messageBody,
    required String sender,
    required DateTime date,
  }) async {
    await _db.into(_db.smsInbox).insert(
          SmsInboxCompanion.insert(
            id: id,
            messageBody: messageBody,
            sender: sender,
            date: date,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  /// Marks an inbox item parsed/skipped without touching its original
  /// message content — the previous DbService-based implementation
  /// overwrote messageBody/sender/date with placeholder values on every
  /// status update, destroying the original SMS text.
  Future<void> markParsed(String id) async {
    await (_db.update(_db.smsInbox)..where((t) => t.id.equals(id))).write(
      SmsInboxCompanion(isParsed: const Value(true), updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> markSkipped(String id) async {
    await (_db.update(_db.smsInbox)..where((t) => t.id.equals(id))).write(
      SmsInboxCompanion(isSkipped: const Value(true), updatedAt: Value(DateTime.now())),
    );
  }
}

final smsRepository = SmsRepository();
