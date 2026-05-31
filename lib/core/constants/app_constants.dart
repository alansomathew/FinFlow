class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'FinFlow';
  static const String appTagline = 'Smart Personal Finance Manager';
  static const String appVersion = '1.0.0';

  // Firestore Collections
  static const String colUsers = 'users';
  static const String colTransactions = 'transactions';
  static const String colBudgets = 'budgets';
  static const String colAccounts = 'accounts';
  static const String colLoans = 'loans';
  static const String colSavingsGoals = 'savings_goals';
  static const String colInvestments = 'investments';
  static const String colSips = 'sips';
  static const String colStocks = 'stocks';
  static const String colCategories = 'categories';

  // Hive Box Names (Local Cache)
  static const String boxTransactions = 'transactions_box';
  static const String boxBudgets = 'budgets_box';
  static const String boxAccounts = 'accounts_box';
  static const String boxSettings = 'settings_box';
  static const String boxSmsLog = 'sms_log_box';

  // SharedPreferences Keys
  static const String prefIsFirstLaunch = 'is_first_launch';
  static const String prefThemeMode = 'theme_mode';
  static const String keyDarkMode = 'is_dark_mode';
  static const String prefCurrency = 'currency';
  static const String prefBiometricEnabled = 'biometric_enabled';
  static const String prefAutoLockDuration = 'auto_lock_duration';
  static const String prefBudgetResetDay = 'budget_reset_day';
  static const String prefMonthlyIncome = 'monthly_income';
  static const String prefSmsParsingEnabled = 'sms_parsing_enabled';
  static const String prefIsGuestMode = 'is_guest_mode';
  static const String prefNotificationsEnabled = 'notifications_enabled';

  // Feature Limits — Basic Tier
  static const int basicMaxAccounts = 3;
  static const int basicMaxLoans = 2;
  static const int basicMaxGoals = 3;
  static const int basicMaxRecurring = 5;
  static const int basicTipsPerWeek = 3;

  // Budget Thresholds
  static const double budgetWarningThreshold = 0.8;   // 80% — amber
  static const double budgetDangerThreshold = 1.0;    // 100% — red

  // Auto-Lock Options (minutes; 0 = never)
  static const List<int> autoLockOptions = [0, 1, 2, 5, 10];

  // Default Categories
  static const String cat50NeedsKey = 'needs';
  static const String cat30WantsKey = 'wants';
  static const String cat20SavingsKey = 'savings';

  // SMS Duplicate Detection
  static const int smsDuplicateWindowMinutes = 5;
  static const double smsLowConfidenceThreshold = 70.0;

  // Investment
  static const String amfiBaseUrl =
      'https://www.amfiindia.com/spages/NAVAll.txt';

  // Currency
  static const String defaultCurrency = 'INR';
  static const String currencySymbol = '₹';

  // Animation Durations
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animNormal = Duration(milliseconds: 350);
  static const Duration animSlow = Duration(milliseconds: 600);

  // Card Border Radius
  static const double radiusXs = 6.0;
  static const double radiusSm = 10.0;
  static const double radiusMd = 14.0;
  static const double radiusLg = 20.0;
  static const double radiusXl = 28.0;

  // Spacing
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;

  // Bottom Nav Height
  static const double bottomNavHeight = 64.0;
  static const double fabSize = 56.0;
}
