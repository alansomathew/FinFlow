import 'package:drift/drift.dart';

/// One day's net-worth reading, keyed by calendar date so recomputing
/// "today" more than once just overwrites the same row instead of
/// accumulating duplicates. Trend charts read this history directly --
/// there's no live/derived view here since a trend is inherently a record
/// of *what it was*, not something that can be recomputed after the fact.
class NetWorthSnapshots extends Table {
  TextColumn get date => text()(); // 'YYYY-MM-DD'
  RealColumn get assets => real()();
  RealColumn get liabilities => real()();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {date};
}
