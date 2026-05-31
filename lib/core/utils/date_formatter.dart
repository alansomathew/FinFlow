import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static final DateFormat _displayDate = DateFormat('dd MMM yyyy');
  static final DateFormat _displayDateTime = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat _displayTime = DateFormat('hh:mm a');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy');
  static final DateFormat _shortMonthYear = DateFormat('MMM yy');
  static final DateFormat _dayMonth = DateFormat('dd MMM');
  static final DateFormat _dayName = DateFormat('EEEE');
  static final DateFormat _shortDay = DateFormat('EEE');
  static final DateFormat _iso = DateFormat('yyyy-MM-dd');
  static final DateFormat _firestoreKey = DateFormat('yyyy-MM');

  /// e.g., 14 Jan 2025
  static String displayDate(DateTime date) => _displayDate.format(date);

  /// e.g., 14 Jan 2025, 03:45 PM
  static String displayDateTime(DateTime date) =>
      _displayDateTime.format(date);

  /// e.g., 03:45 PM
  static String displayTime(DateTime date) => _displayTime.format(date);

  /// e.g., January 2025
  static String monthYear(DateTime date) => _monthYear.format(date);

  /// e.g., Jan 25
  static String shortMonthYear(DateTime date) => _shortMonthYear.format(date);

  /// e.g., 14 Jan
  static String dayMonth(DateTime date) => _dayMonth.format(date);

  /// e.g., Monday
  static String dayName(DateTime date) => _dayName.format(date);

  /// e.g., Mon
  static String shortDay(DateTime date) => _shortDay.format(date);

  /// e.g., 2025-01-14
  static String isoDate(DateTime date) => _iso.format(date);

  /// e.g., 2025-01 (for Firestore monthly doc keys)
  static String firestoreMonthKey(DateTime date) =>
      _firestoreKey.format(date);

  /// Relative date label — Today / Yesterday / DD MMM
  static String relativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final input = DateTime(date.year, date.month, date.day);
    final diff = today.difference(input).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return _dayName.format(date);
    return _displayDate.format(date);
  }

  /// Days remaining until a target date
  static int daysUntil(DateTime target) {
    final now = DateTime.now();
    return target.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  /// Human-readable remaining time
  static String timeUntil(DateTime target) {
    final days = daysUntil(target);
    if (days < 0) return 'Overdue';
    if (days == 0) return 'Today';
    if (days == 1) return '1 day left';
    if (days < 30) return '$days days left';
    final months = (days / 30).round();
    if (months < 12) return '$months months left';
    final years = (months / 12).round();
    return '$years years left';
  }

  /// Start of current month
  static DateTime startOfMonth([DateTime? ref]) {
    final d = ref ?? DateTime.now();
    return DateTime(d.year, d.month, 1);
  }

  /// End of current month
  static DateTime endOfMonth([DateTime? ref]) {
    final d = ref ?? DateTime.now();
    return DateTime(d.year, d.month + 1, 0, 23, 59, 59);
  }

  /// Last N months list (for analytics selectors)
  static List<DateTime> lastNMonths(int n) {
    final now = DateTime.now();
    return List.generate(n, (i) {
      return DateTime(now.year, now.month - i, 1);
    });
  }

  /// Check if two dates fall on the same calendar day
  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
