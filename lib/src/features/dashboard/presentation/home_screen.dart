import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_sizes.dart';
import '../../accounts/presentation/accounts_list_screen.dart';
import '../../auth/data/auth_repository.dart';
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
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusLg),
        ),
      ),
      builder: (context) => SafeArea(
        child: Padding(
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
                    backgroundColor: AppColors.primary,
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
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          user.email,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
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
                          ? AppColors.wants.withOpacity(0.2)
                          : AppColors.savings.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      user.isGuest ? 'Guest' : 'Cloud Sync',
                      style: TextStyle(
                        color: user.isGuest
                            ? AppColors.wants
                            : AppColors.savings,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              AppSizes.h24,
              const Divider(color: AppColors.border, height: 1),
              AppSizes.h12,

              // Action Options
              ListTile(
                leading: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'Accounts & Cards',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                subtitle: const Text(
                  'Manage bank accounts, wallets, and credit cards',
                  style: TextStyle(
                    color: AppColors.textSecondary,
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
              if (user.isGuest)
                ListTile(
                  leading: const Icon(
                    Icons.cloud_upload_rounded,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Upgrade to Cloud Sync',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  subtitle: const Text(
                    'Link Google account and backup data',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/login');
                  },
                ),
              ListTile(
                leading: const Icon(
                  Icons.mark_email_read_rounded,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'SMS Auto-Detection',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                subtitle: const Text(
                  'Detect transactions from real bank/UPI SMS on this device',
                  style: TextStyle(
                    color: AppColors.textSecondary,
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
                leading: const Icon(
                  Icons.sms_rounded,
                  color: AppColors.secondary,
                ),
                title: const Text(
                  'SMS Parsing Sandbox',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                subtitle: const Text(
                  'Simulate bank SMS messages to test parser',
                  style: TextStyle(
                    color: AppColors.textSecondary,
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
                leading: const Icon(
                  Icons.calculate_rounded,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'Debt Payoff Planner',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                subtitle: const Text(
                  'Compare Snowball vs Avalanche payoff methods',
                  style: TextStyle(
                    color: AppColors.textSecondary,
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
              Consumer(
                builder: (context, ref, _) {
                  final isPro = ref.watch(isProProvider).valueOrNull ?? false;
                  return SwitchListTile(
                    secondary: const Icon(
                      Icons.workspace_premium_rounded,
                      color: AppColors.warning,
                    ),
                    title: const Text(
                      'Pro Tier (Debug Toggle)',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    subtitle: const Text(
                      'No billing yet -- for testing Pro-gated features',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    value: isPro,
                    activeThumbColor: AppColors.warning,
                    onChanged: (value) => setProTierForTesting(value),
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Sign Out',
                  style: TextStyle(
                    color: AppColors.error,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTab = ref.watch(activeTabProvider);
    final user = ref.watch(authProvider);

    final List<Widget> tabs = [
      const DashboardTab(),
      const TransactionsTab(),
      const BudgetTab(),
      const InvestmentsTab(),
      const AnalyticsTab(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Row(
          children: [
            const Icon(
              Icons.auto_graph_rounded,
              color: AppColors.primary,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              activeTab == 0
                  ? 'FinFlow'
                  : [
                      'Transactions',
                      'Budgets',
                      'Investments',
                      'Analytics',
                    ][activeTab - 1],
              style: const TextStyle(
                color: AppColors.textPrimary,
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
                backgroundColor: AppColors.border,
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
        backgroundColor: AppColors.primary,
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
        color: AppColors.surface,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        padding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBottomNavItem(ref, 0, Icons.dashboard_rounded, 'Home'),
              _buildBottomNavItem(ref, 1, Icons.list_alt_rounded, 'Ledger'),
              const SizedBox(width: 32), // Space for FAB
              _buildBottomNavItem(ref, 2, Icons.pie_chart_rounded, 'Budget'),
              _buildBottomNavItem(ref, 3, Icons.trending_up_rounded, 'Invest'),
              _buildBottomNavItem(ref, 4, Icons.insert_chart_rounded, 'Charts'),
            ],
          ),
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

    return Expanded(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => ref.read(activeTabProvider.notifier).state = index,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
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
