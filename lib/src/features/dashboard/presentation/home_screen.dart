import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_sizes.dart';
import '../../../constants/app_theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../accounts/presentation/accounts_list_screen.dart';
import '../../auth/data/auth_repository.dart';
import '../../goals/presentation/goals_list_screen.dart';
import '../../transactions/presentation/transaction_form_sheet.dart';
import 'dashboard_tab.dart';
import '../../transactions/presentation/transactions_tab.dart';
import '../../budget/presentation/budget_tab.dart';
import '../../investments/presentation/investments_tab.dart';
import '../../analytics/presentation/analytics_tab.dart';
import '../../sms/data/sms_device_service.dart';
import '../../sms/data/sms_repository.dart';
import '../../sms/presentation/sms_review_sheet.dart';
import '../../sms/presentation/sms_sandbox_sheet.dart';
import '../../debt/presentation/debt_planner_sheet.dart';
import '../../../services/app_settings_service.dart';
import '../../../services/pro_tier_service.dart';

final activeTabProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  bool _reviewSheetShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSmsReview());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSmsReview();
    }
  }

  /// Auto-surfaces the SMS review sheet on app open/resume, but only once
  /// SMS detection has already been enabled (has real pending items to
  /// show) -- a permission this sensitive shouldn't be repeatedly prompted
  /// for on every resume. First-time enabling happens via the profile menu.
  Future<void> _checkSmsReview() async {
    if (!mounted || _reviewSheetShowing) return;
    final user = ref.read(authProvider);
    if (user == null) return;

    final device = ref.read(smsDeviceServiceProvider);
    if (!await device.hasPermission()) return;

    await device.scanInbox();
    device.startForegroundListening();

    final pending = await ref.read(smsRepositoryProvider).getPendingInbox();
    if (!mounted || pending.isEmpty || _reviewSheetShowing) return;

    _reviewSheetShowing = true;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SmsReviewSheet(),
    );
    _reviewSheetShowing = false;
  }

  void _showAddTransaction(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const TransactionFormSheet(),
    );
  }

  void _showProfileMenu(BuildContext context, WidgetRef ref) {
    final user = ref.read(authProvider);
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      // Deliberately transparent, not colors.surface: showModalBottomSheet's
      // backgroundColor is evaluated once at call time, not inside builder,
      // so a context.colors value baked in here would freeze at whatever
      // theme was active when the sheet opened and only pick up a live
      // theme change the *next* time the sheet is opened. The real surface
      // color is painted by the Container below instead, which is inside
      // builder and so re-evaluates colors on every theme change.
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final colors = context.colors;
        final l10n = AppLocalizations.of(context)!;

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Material(
              // Material, not a plain Container/DecoratedBox: the ListTiles
              // below paint their background/ink splashes on the nearest
              // Material ancestor, and an opaque DecoratedBox in between
              // would hide those effects (Flutter warns on exactly this).
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSizes.radiusLg),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSizes.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // User Info Header
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: colors.primary,
                          backgroundImage: user.photoUrl.isNotEmpty
                              ? NetworkImage(user.photoUrl)
                              : null,
                          child: user.photoUrl.isEmpty
                              ? Text(
                                  user.displayName[0],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                  ),
                                )
                              : null,
                        ),
                        AppSizes.w16,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.displayName,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                user.email,
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: user.isGuest
                                ? colors.wants.withValues(alpha: 0.2)
                                : colors.savings.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            user.isGuest
                                ? l10n.profileGuestBadge
                                : l10n.profileCloudSyncBadge,
                            style: TextStyle(
                              color: user.isGuest
                                  ? colors.wants
                                  : colors.savings,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    AppSizes.h24,
                    Divider(color: colors.border, height: 1),
                    AppSizes.h12,

                    // Action Options
                    ListTile(
                      leading: Icon(
                        Icons.account_balance_wallet_rounded,
                        color: colors.primary,
                      ),
                      title: Text(
                        l10n.menuAccountsTitle,
                        style: TextStyle(color: colors.textPrimary),
                      ),
                      subtitle: Text(
                        l10n.menuAccountsSubtitle,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const AccountsListScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.savings_rounded,
                        color: colors.savings,
                      ),
                      title: Text(
                        l10n.menuGoalsTitle,
                        style: TextStyle(color: colors.textPrimary),
                      ),
                      subtitle: Text(
                        l10n.menuGoalsSubtitle,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const GoalsListScreen(),
                          ),
                        );
                      },
                    ),
                    if (user.isGuest)
                      ListTile(
                        leading: Icon(
                          Icons.cloud_upload_rounded,
                          color: colors.primary,
                        ),
                        title: Text(
                          l10n.menuUpgradeTitle,
                          style: TextStyle(color: colors.textPrimary),
                        ),
                        subtitle: Text(
                          l10n.menuUpgradeSubtitle,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          context.go('/login');
                        },
                      ),
                    ListTile(
                      leading: Icon(
                        Icons.mark_email_read_rounded,
                        color: colors.primary,
                      ),
                      title: Text(
                        l10n.menuSmsAutoTitle,
                        style: TextStyle(color: colors.textPrimary),
                      ),
                      subtitle: Text(
                        l10n.menuSmsAutoSubtitle,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => const SmsReviewSheet(),
                        );
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.sms_rounded, color: colors.secondary),
                      title: Text(
                        l10n.menuSmsSandboxTitle,
                        style: TextStyle(color: colors.textPrimary),
                      ),
                      subtitle: Text(
                        l10n.menuSmsSandboxSubtitle,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => const SmsSandboxSheet(),
                        );
                      },
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.calculate_rounded,
                        color: colors.primary,
                      ),
                      title: Text(
                        l10n.menuDebtPlannerTitle,
                        style: TextStyle(color: colors.textPrimary),
                      ),
                      subtitle: Text(
                        l10n.menuDebtPlannerSubtitle,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => const DebtPlannerSheet(),
                        );
                      },
                    ),
                    AppSizes.h12,
                    Divider(color: colors.border, height: 1),
                    AppSizes.h12,

                    // Theme selector
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.md,
                      ),
                      child: Text(
                        l10n.menuTheme,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    AppSizes.h8,
                    Consumer(
                      builder: (context, ref, _) {
                        final mode =
                            ref.watch(themeModeProvider).valueOrNull ??
                            ThemeMode.dark;
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.md,
                          ),
                          child: SegmentedButton<ThemeMode>(
                            segments: [
                              ButtonSegment(
                                value: ThemeMode.light,
                                icon: const Icon(
                                  Icons.light_mode_rounded,
                                  size: 16,
                                ),
                                label: Text(l10n.menuThemeLight),
                              ),
                              ButtonSegment(
                                value: ThemeMode.dark,
                                icon: const Icon(
                                  Icons.dark_mode_rounded,
                                  size: 16,
                                ),
                                label: Text(l10n.menuThemeDark),
                              ),
                              ButtonSegment(
                                value: ThemeMode.system,
                                icon: const Icon(
                                  Icons.brightness_auto_rounded,
                                  size: 16,
                                ),
                                label: Text(l10n.menuThemeSystem),
                              ),
                            ],
                            selected: {mode},
                            onSelectionChanged: (selection) =>
                                setThemeMode(selection.first),
                          ),
                        );
                      },
                    ),
                    AppSizes.h16,

                    // Language selector
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.md,
                      ),
                      child: Text(
                        l10n.menuLanguage,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Consumer(
                      builder: (context, ref, _) {
                        final locale = ref.watch(localeProvider).valueOrNull;
                        return DropdownButton<String?>(
                          value: locale?.languageCode,
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          dropdownColor: colors.surface,
                          style: TextStyle(color: colors.textPrimary),
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text(l10n.menuLanguageSystem),
                            ),
                            const DropdownMenuItem(
                              value: 'en',
                              child: Text('English'),
                            ),
                            const DropdownMenuItem(
                              value: 'hi',
                              child: Text('हिन्दी (Hindi)'),
                            ),
                            const DropdownMenuItem(
                              value: 'ta',
                              child: Text('தமிழ் (Tamil)'),
                            ),
                            const DropdownMenuItem(
                              value: 'kn',
                              child: Text('ಕನ್ನಡ (Kannada)'),
                            ),
                            const DropdownMenuItem(
                              value: 'mr',
                              child: Text('मराठी (Marathi)'),
                            ),
                            const DropdownMenuItem(
                              value: 'ml',
                              child: Text('മലയാളം (Malayalam)'),
                            ),
                          ],
                          onChanged: (code) => setLanguageCode(code),
                        );
                      },
                    ),
                    AppSizes.h12,
                    Divider(color: colors.border, height: 1),

                    Consumer(
                      builder: (context, ref, _) {
                        final isPro =
                            ref.watch(isProProvider).valueOrNull ?? false;
                        return SwitchListTile(
                          secondary: Icon(
                            Icons.workspace_premium_rounded,
                            color: colors.warning,
                          ),
                          title: Text(
                            l10n.menuProToggleTitle,
                            style: TextStyle(color: colors.textPrimary),
                          ),
                          subtitle: Text(
                            l10n.menuProToggleSubtitle,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          value: isPro,
                          activeThumbColor: colors.warning,
                          onChanged: (value) => setProTierForTesting(value),
                        );
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.logout_rounded, color: colors.error),
                      title: Text(
                        l10n.menuSignOut,
                        style: TextStyle(
                          color: colors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        await ref.read(authProvider.notifier).signOut();
                        if (context.mounted) {
                          context.go('/login');
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTab = ref.watch(activeTabProvider);
    final user = ref.watch(authProvider);
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;

    final List<Widget> tabs = [
      const DashboardTab(),
      const TransactionsTab(),
      const BudgetTab(),
      const InvestmentsTab(),
      const AnalyticsTab(),
    ];

    final tabTitles = [
      l10n.appTitleHome,
      l10n.appTitleTransactions,
      l10n.appTitleBudgets,
      l10n.appTitleInvestments,
      l10n.appTitleAnalytics,
    ];

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.auto_graph_rounded, color: colors.primary, size: 24),
            const SizedBox(width: 8),
            Text(
              tabTitles[activeTab],
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSizes.md),
            child: GestureDetector(
              onTap: () => _showProfileMenu(context, ref),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: colors.border,
                backgroundImage:
                    user?.photoUrl != null && user!.photoUrl.isNotEmpty
                    ? NetworkImage(user.photoUrl)
                    : null,
                child: user?.photoUrl == null || user!.photoUrl.isEmpty
                    ? Text(
                        user?.displayName[0] ?? 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: activeTab, children: tabs),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTransaction(context),
        backgroundColor: colors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: colors.surface,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        padding: EdgeInsets.zero,
        height: 64,
        clipBehavior: Clip.antiAlias,
        // Two independent halves (rather than one Row with a fixed-width
        // gap) so the boundary between them always lands at the exact
        // center of the bar, matching where centerDocked positions the
        // FAB/notch -- a fixed gap can't do that when the item counts on
        // each side differ (2 left, 3 right here), since equal-flex items
        // either side of a fixed gap don't actually meet at the midpoint.
        child: Row(
          children: [
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildBottomNavItem(
                    ref,
                    0,
                    Icons.dashboard_rounded,
                    l10n.navHome,
                  ),
                  _buildBottomNavItem(
                    ref,
                    1,
                    Icons.list_alt_rounded,
                    l10n.navLedger,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildBottomNavItem(
                    ref,
                    2,
                    Icons.pie_chart_rounded,
                    l10n.navBudget,
                  ),
                  _buildBottomNavItem(
                    ref,
                    3,
                    Icons.trending_up_rounded,
                    l10n.navInvest,
                  ),
                  _buildBottomNavItem(
                    ref,
                    4,
                    Icons.insert_chart_rounded,
                    l10n.navCharts,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(
    WidgetRef ref,
    int index,
    IconData icon,
    String label,
  ) {
    final activeTab = ref.watch(activeTabProvider);
    final isSelected = activeTab == index;
    final colors = context.colors;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        onTap: () => ref.read(activeTabProvider.notifier).state = index,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? colors.primary : colors.textSecondary,
                size: 22,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? colors.primary : colors.textSecondary,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
