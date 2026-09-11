import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_kn.dart';
import 'app_localizations_ml.dart';
import 'app_localizations_mr.dart';
import 'app_localizations_ta.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('kn'),
    Locale('ml'),
    Locale('mr'),
    Locale('ta'),
  ];

  /// Bottom nav label for the Dashboard tab
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Bottom nav label for the Transactions tab
  ///
  /// In en, this message translates to:
  /// **'Ledger'**
  String get navLedger;

  /// Bottom nav label for the Budget tab
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get navBudget;

  /// Bottom nav label for the Investments tab
  ///
  /// In en, this message translates to:
  /// **'Invest'**
  String get navInvest;

  /// Bottom nav label for the Analytics tab
  ///
  /// In en, this message translates to:
  /// **'Charts'**
  String get navCharts;

  /// No description provided for @appTitleHome.
  ///
  /// In en, this message translates to:
  /// **'FinFlow'**
  String get appTitleHome;

  /// No description provided for @appTitleTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get appTitleTransactions;

  /// No description provided for @appTitleBudgets.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get appTitleBudgets;

  /// No description provided for @appTitleInvestments.
  ///
  /// In en, this message translates to:
  /// **'Investments'**
  String get appTitleInvestments;

  /// No description provided for @appTitleAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get appTitleAnalytics;

  /// No description provided for @profileGuestBadge.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get profileGuestBadge;

  /// No description provided for @profileCloudSyncBadge.
  ///
  /// In en, this message translates to:
  /// **'Cloud Sync'**
  String get profileCloudSyncBadge;

  /// No description provided for @menuAccountsTitle.
  ///
  /// In en, this message translates to:
  /// **'Accounts & Cards'**
  String get menuAccountsTitle;

  /// No description provided for @menuAccountsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage bank accounts, wallets, and credit cards'**
  String get menuAccountsSubtitle;

  /// No description provided for @menuGoalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Savings Goals'**
  String get menuGoalsTitle;

  /// No description provided for @menuGoalsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track progress toward your savings targets'**
  String get menuGoalsSubtitle;

  /// No description provided for @menuUpgradeTitle.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Cloud Sync'**
  String get menuUpgradeTitle;

  /// No description provided for @menuUpgradeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Link Google account and backup data'**
  String get menuUpgradeSubtitle;

  /// No description provided for @menuSmsAutoTitle.
  ///
  /// In en, this message translates to:
  /// **'SMS Auto-Detection'**
  String get menuSmsAutoTitle;

  /// No description provided for @menuSmsAutoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Detect transactions from real bank/UPI SMS on this device'**
  String get menuSmsAutoSubtitle;

  /// No description provided for @menuSmsSandboxTitle.
  ///
  /// In en, this message translates to:
  /// **'SMS Parsing Sandbox'**
  String get menuSmsSandboxTitle;

  /// No description provided for @menuSmsSandboxSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Simulate bank SMS messages to test parser'**
  String get menuSmsSandboxSubtitle;

  /// No description provided for @menuDebtPlannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Debt Payoff Planner'**
  String get menuDebtPlannerTitle;

  /// No description provided for @menuDebtPlannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Compare Snowball vs Avalanche payoff methods'**
  String get menuDebtPlannerSubtitle;

  /// No description provided for @menuProToggleTitle.
  ///
  /// In en, this message translates to:
  /// **'Pro Tier (Debug Toggle)'**
  String get menuProToggleTitle;

  /// No description provided for @menuProToggleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'No billing yet -- for testing Pro-gated features'**
  String get menuProToggleSubtitle;

  /// No description provided for @menuSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get menuSignOut;

  /// No description provided for @menuTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get menuTheme;

  /// No description provided for @menuThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get menuThemeLight;

  /// No description provided for @menuThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get menuThemeDark;

  /// No description provided for @menuThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get menuThemeSystem;

  /// No description provided for @menuLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get menuLanguage;

  /// No description provided for @menuLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow System'**
  String get menuLanguageSystem;

  /// No description provided for @dashboardNetWorth.
  ///
  /// In en, this message translates to:
  /// **'TOTAL NET WORTH'**
  String get dashboardNetWorth;

  /// No description provided for @dashboardAssets.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get dashboardAssets;

  /// No description provided for @dashboardLiabilities.
  ///
  /// In en, this message translates to:
  /// **'Liabilities'**
  String get dashboardLiabilities;

  /// No description provided for @dashboardRemainingBudget.
  ///
  /// In en, this message translates to:
  /// **'Remaining Budget'**
  String get dashboardRemainingBudget;

  /// No description provided for @dashboardSafeDailySpend.
  ///
  /// In en, this message translates to:
  /// **'Safe Daily Spend'**
  String get dashboardSafeDailySpend;

  /// No description provided for @dashboardSavingsGoals.
  ///
  /// In en, this message translates to:
  /// **'Savings Goals'**
  String get dashboardSavingsGoals;

  /// No description provided for @dashboardViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get dashboardViewAll;

  /// No description provided for @dashboardInvestments.
  ///
  /// In en, this message translates to:
  /// **'Investments'**
  String get dashboardInvestments;

  /// No description provided for @dashboardActiveLoans.
  ///
  /// In en, this message translates to:
  /// **'Active Loans'**
  String get dashboardActiveLoans;

  /// No description provided for @dashboardRecentLedger.
  ///
  /// In en, this message translates to:
  /// **'Recent Ledger'**
  String get dashboardRecentLedger;

  /// No description provided for @dashboardSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get dashboardSeeAll;

  /// No description provided for @dashboardNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions logged yet.'**
  String get dashboardNoTransactions;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'en',
    'hi',
    'kn',
    'ml',
    'mr',
    'ta',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'kn':
      return AppLocalizationsKn();
    case 'ml':
      return AppLocalizationsMl();
    case 'mr':
      return AppLocalizationsMr();
    case 'ta':
      return AppLocalizationsTa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
