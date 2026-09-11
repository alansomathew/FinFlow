import 'package:drift/drift.dart';

/// A user-defined spending/income category beyond the built-in presets in
/// [TransactionCategory.presets] -- e.g. "Pet Care" or "Side Hustle".
/// Carries its own icon and color rather than inheriting a fixed
/// bucket-level color, since the whole point is letting the user tell
/// categories apart visually once there are more of them than the presets.
class CustomCategories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get icon => text()();
  TextColumn get colorHex => text()();
  TextColumn get bucket => text()(); // BudgetBucket.name

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
