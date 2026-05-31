import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/router/app_router.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    ref.listen(authNotifierProvider, (_, next) {
      if (next is AsyncData && next.value != null) {
        context.go(AppRoutes.home);
      }
      if (next is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-in failed: ${next.error}')),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F0F1A), Color(0xFF1A1028), Color(0xFF0F0F1A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),
                // Logo
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.45),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  AppConstants.appName,
                  style: AppTextStyles.displayLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  AppConstants.appTagline,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(flex: 2),
                // Benefits
                _buildBenefitRow('📊', 'Track spending automatically via SMS'),
                const SizedBox(height: 12),
                _buildBenefitRow('💡', 'AI-powered personalised financial tips'),
                const SizedBox(height: 12),
                _buildBenefitRow('🚀', '50/30/20 budgeting made effortless'),
                const SizedBox(height: 12),
                _buildBenefitRow('📈', 'SIPs, Mutual Funds & Stocks in one app'),
                const Spacer(flex: 2),
                // Google Sign-In
                authState.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _GoogleSignInButton(
                        onPressed: () => ref
                            .read(authNotifierProvider.notifier)
                            .signInWithGoogle(),
                      ),
                const SizedBox(height: 16),
                // Guest Mode
                OutlinedButton.icon(
                  onPressed: authState.isLoading
                      ? null
                      : () => ref
                          .read(authNotifierProvider.notifier)
                          .continueAsGuest(),
                  icon: const Icon(Icons.person_outline_rounded),
                  label: const Text('Continue as Guest'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondaryDark,
                    side: const BorderSide(color: AppColors.darkBorder),
                    minimumSize: const Size(double.infinity, 52),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'By continuing, you agree to our Terms of Service\nand Privacy Policy',
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitRow(String emoji, String text) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: AppTextStyles.bodyMedium),
        ),
      ],
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _GoogleSignInButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google G logo representation
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: const Text('G',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4285F4),
                    fontFamily: 'Poppins',
                  ),
                  textAlign: TextAlign.center),
            ),
            const SizedBox(width: 12),
            const Text(
              'Continue with Google',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
