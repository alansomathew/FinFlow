import 'package:drift/drift.dart';

/// The user's declared monthly income for a given calendar month, entered
/// via the Salary-Based 50/30/20 Planner. Kept per-month (not a single
/// global value) since income can genuinely change month to month, and so
/// the planner can carry last month's figure forward the same way budget
/// limits already do.
class MonthlyIncome extends Table {
  TextColumn get monthYear => text()(); // 'YYYY-MM'
  RealColumn get salaryAmount => real()();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {monthYear};
}
