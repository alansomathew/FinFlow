/// Formats a date as 'YYYY-MM' -- the key budgets and the SMS-parse counter
/// use to identify which calendar month a row belongs to. Shared in one
/// place so every caller agrees on the exact same format.
String monthKeyOf(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}';
