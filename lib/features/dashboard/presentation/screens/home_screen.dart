import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/local/sms_service.dart';
import '../../../../core/local/notification_service.dart';
import '../widgets/net_worth_card.dart';
import '../widgets/budget_overview_card.dart';
import '../widgets/recent_transactions_widget.dart';
import '../widgets/savings_goals_widget.dart';
import '../widgets/investment_summary_card.dart';
import '../widgets/ai_tip_card.dart';
import '../widgets/sms_review_sheet.dart';
import '../../providers/ai_tip_popup_provider.dart';
import '../widgets/ai_tip_popup_dialog.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final SmsService _smsService = SmsService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingSms();
      _checkDailyAiTip();
    });
  }

  Future<void> _checkDailyAiTip() async {
    try {
      final notifier = ref.read(aiTipPopupNotifierProvider.notifier);
      final shouldShow = await notifier.shouldShowPopupToday();
      if (shouldShow && mounted) {
        final tip = await notifier.fetchPersonalizedTip();
        if (tip != null && mounted) {
          await showDialog(
            context: context,
            barrierColor: Colors.black.withOpacity(0.6),
            builder: (context) => AiTipPopupDialog(tip: tip),
          );
          await notifier.markPopupAsShownToday();
        }
      }
    } catch (e) {
      print('Daily AI tip check failed: $e');
    }
  }

  Future<void> _checkPendingSms() async {
    try {
      // 1. Request SMS permission and local notifications permission
      await Permission.sms.request();
      await NotificationService.instance.requestPermissions();
    } catch (e) {
      print('Permission request failed: $e');
    }

    try {
      // 2. Fetch pending transactions
      final pending = await _smsService.fetchPendingTransactions();
      if (pending.isNotEmpty && mounted) {
        // 3. Show local notification alert
        await NotificationService.instance.showNotification(
          id: 1001,
          title: "Pending Transactions Detected",
          body: "You have ${pending.length} transaction alert(s) ready to review & add.",
        );

        // 4. Show glassmorphic review modal sheet
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          barrierColor: Colors.black.withOpacity(0.55),
          builder: (context) => SmsReviewSheet(pendingTransactions: pending),
        );
      }
    } catch (e) {
      print('SMS parsing check failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _HomeAppBar(user: user.value),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),
                const NetWorthCard(),
                const SizedBox(height: 16),
                const BudgetOverviewCard(),
                const SizedBox(height: 16),
                const RecentTransactionsWidget(),
                const SizedBox(height: 16),
                const SavingsGoalsWidget(),
                const SizedBox(height: 16),
                const InvestmentSummaryCard(),
                const SizedBox(height: 16),
                const AiTipCard(),
                const SizedBox(height: 100), // bottom padding for FAB
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeAppBar extends ConsumerWidget {
  final dynamic user;
  const _HomeAppBar({this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final greeting = _getGreeting();
    final userName = user?.name?.split(' ').first ?? 'there';

    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: AppColors.background,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$greeting, $userName 👋',
            style: AppTextStyles.headlineMedium,
          ),
          Text(
            DateFormatter.displayDate(DateTime.now()),
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          color: AppColors.textPrimary,
          onPressed: () {},
        ),
        GestureDetector(
          onTap: () => context.push('/settings'),
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 18,
              backgroundImage: user?.photoUrl != null
                  ? NetworkImage(user!.photoUrl!)
                  : null,
              backgroundColor: AppColors.primary,
              child: user?.photoUrl == null
                  ? Text(
                      (user?.name?.isNotEmpty == true)
                          ? user!.name![0].toUpperCase()
                          : 'U',
                      style: AppTextStyles.labelLarge
                          .copyWith(color: Colors.white),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}
