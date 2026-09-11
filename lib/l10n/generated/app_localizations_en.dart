// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navHome => 'Home';

  @override
  String get navLedger => 'Ledger';

  @override
  String get navBudget => 'Budget';

  @override
  String get navInvest => 'Invest';

  @override
  String get navCharts => 'Charts';

  @override
  String get appTitleHome => 'FinFlow';

  @override
  String get appTitleTransactions => 'Transactions';

  @override
  String get appTitleBudgets => 'Budgets';

  @override
  String get appTitleInvestments => 'Investments';

  @override
  String get appTitleAnalytics => 'Analytics';

  @override
  String get profileGuestBadge => 'Guest';

  @override
  String get profileCloudSyncBadge => 'Cloud Sync';

  @override
  String get menuAccountsTitle => 'Accounts & Cards';

  @override
  String get menuAccountsSubtitle =>
      'Manage bank accounts, wallets, and credit cards';

  @override
  String get menuGoalsTitle => 'Savings Goals';

  @override
  String get menuGoalsSubtitle => 'Track progress toward your savings targets';

  @override
  String get menuUpgradeTitle => 'Upgrade to Cloud Sync';

  @override
  String get menuUpgradeSubtitle => 'Link Google account and backup data';

  @override
  String get menuSmsAutoTitle => 'SMS Auto-Detection';

  @override
  String get menuSmsAutoSubtitle =>
      'Detect transactions from real bank/UPI SMS on this device';

  @override
  String get menuSmsSandboxTitle => 'SMS Parsing Sandbox';

  @override
  String get menuSmsSandboxSubtitle =>
      'Simulate bank SMS messages to test parser';

  @override
  String get menuDebtPlannerTitle => 'Debt Payoff Planner';

  @override
  String get menuDebtPlannerSubtitle =>
      'Compare Snowball vs Avalanche payoff methods';

  @override
  String get menuProToggleTitle => 'Pro Tier (Debug Toggle)';

  @override
  String get menuProToggleSubtitle =>
      'No billing yet -- for testing Pro-gated features';

  @override
  String get menuSignOut => 'Sign Out';

  @override
  String get menuTheme => 'Theme';

  @override
  String get menuThemeLight => 'Light';

  @override
  String get menuThemeDark => 'Dark';

  @override
  String get menuThemeSystem => 'System';

  @override
  String get menuLanguage => 'Language';

  @override
  String get menuLanguageSystem => 'Follow System';

  @override
  String get dashboardNetWorth => 'TOTAL NET WORTH';

  @override
  String get dashboardAssets => 'Assets';

  @override
  String get dashboardLiabilities => 'Liabilities';

  @override
  String get dashboardRemainingBudget => 'Remaining Budget';

  @override
  String get dashboardSafeDailySpend => 'Safe Daily Spend';

  @override
  String get dashboardSavingsGoals => 'Savings Goals';

  @override
  String get dashboardViewAll => 'View all';

  @override
  String get dashboardInvestments => 'Investments';

  @override
  String get dashboardActiveLoans => 'Active Loans';

  @override
  String get dashboardRecentLedger => 'Recent Ledger';

  @override
  String get dashboardSeeAll => 'See All';

  @override
  String get dashboardNoTransactions => 'No transactions logged yet.';
}
