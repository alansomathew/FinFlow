import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/shell/main_shell.dart';
import '../../features/dashboard/presentation/screens/home_screen.dart';
import '../../features/transactions/presentation/screens/transactions_screen.dart';
import '../../features/transactions/presentation/screens/add_transaction_screen.dart';
import '../../features/transactions/presentation/screens/transaction_detail_screen.dart';
import '../../features/budget/presentation/screens/budget_screen.dart';
import '../../features/investments/presentation/screens/investments_screen.dart';
import '../../features/analytics/presentation/screens/analytics_screen.dart';
import '../../features/accounts/presentation/screens/accounts_screen.dart';
import '../../features/accounts/presentation/screens/add_account_screen.dart';
import '../../features/loans/presentation/screens/loans_screen.dart';
import '../../features/loans/presentation/screens/add_loan_screen.dart';
import '../../features/savings/presentation/screens/savings_screen.dart';
import '../../features/savings/presentation/screens/add_goal_screen.dart';
import '../../features/investments/presentation/screens/add_investment_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/privacy_policy_screen.dart';
import '../../features/categories/presentation/screens/manage_categories_screen.dart';

// Route names
class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const home = '/home';
  static const transactions = '/transactions';
  static const addTransaction = '/transactions/add';
  static const transactionDetail = '/transactions/:id';
  static const budget = '/budget';
  static const investments = '/investments';
  static const addInvestment = '/investments/add';
  static const analytics = '/analytics';
  static const accounts = '/accounts';
  static const addAccount = '/accounts/add';
  static const loans = '/loans';
  static const addLoan = '/loans/add';
  static const savings = '/savings';
  static const addGoal = '/savings/add';
  static const settings = '/settings';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final isGuestMode = ref.watch(guestSessionProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final isAuthenticated = authState.valueOrNull != null || isGuestMode;
      final isOnAuth = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.onboarding ||
          state.matchedLocation == AppRoutes.splash;

      if (!isAuthenticated && !isOnAuth) return AppRoutes.login;
      if (isAuthenticated && state.matchedLocation == AppRoutes.login) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      // Shell route for bottom navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (_, __) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.transactions,
                builder: (_, __) => const TransactionsScreen(),
                routes: [
                  GoRoute(
                    path: 'add',
                    builder: (_, state) {
                      final extra = state.extra as Map<String, dynamic>?;
                      return AddTransactionScreen(
                          transactionId: extra?['transactionId'] as String?);
                    },
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => TransactionDetailScreen(
                      transactionId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.budget,
                builder: (_, __) => const BudgetScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.analytics,
                builder: (_, __) => const AnalyticsScreen(),
              ),
            ],
          ),
        ],
      ),
      // Non-shell routes
      GoRoute(
        path: AppRoutes.accounts,
        builder: (_, __) => const AccountsScreen(),
        routes: [
          GoRoute(
            path: 'add',
            builder: (_, __) => const AddAccountScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.investments,
        builder: (_, __) => const InvestmentsScreen(),
        routes: [
          GoRoute(
            path: 'add',
            builder: (_, __) => const AddInvestmentScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.loans,
        builder: (_, __) => const LoansScreen(),
        routes: [
          GoRoute(
            path: 'add',
            builder: (_, __) => const AddLoanScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.savings,
        builder: (_, __) => const SavingsScreen(),
        routes: [
          GoRoute(
            path: 'add',
            builder: (_, __) => const AddGoalScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, __) => const SettingsScreen(),
      ),
      // Alias routes — match push calls from various screens
      GoRoute(
        path: '/add-transaction',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return AddTransactionScreen(
              transactionId: extra?['transactionId'] as String?);
        },
      ),
      GoRoute(
        path: '/add-investment',
        builder: (_, __) => const AddInvestmentScreen(),
      ),
      GoRoute(
        path: '/add-account',
        builder: (_, __) => const AddAccountScreen(),
      ),
       GoRoute(
          path: '/privacy-policy',
          builder: (_, __) => const PrivacyPolicyScreen(),
        ),
        GoRoute(
          path: '/manage-categories',
          builder: (_, __) => const ManageCategoriesScreen(),
        ),
    ],
        // Extra routes for settings
       
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
});
