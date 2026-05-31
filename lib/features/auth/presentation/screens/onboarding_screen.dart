import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/common_widgets.dart';

class _OnboardingPage {
  final String emoji;
  final String title;
  final String description;
  final Gradient gradient;

  const _OnboardingPage({
    required this.emoji,
    required this.title,
    required this.description,
    required this.gradient,
  });
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPage(
      emoji: '💰',
      title: 'Track Every Rupee',
      description:
          'Log expenses in under 3 taps. FinFlow auto-reads bank SMS to capture transactions — no manual entry needed.',
      gradient: AppColors.primaryGradient,
    ),
    _OnboardingPage(
      emoji: '📊',
      title: 'Smart 50/30/20 Budgeting',
      description:
          'Allocate your income wisely — 50% Needs, 30% Wants, 20% Savings. Visual envelopes keep you on track.',
      gradient: LinearGradient(
        colors: [Color(0xFF00C896), Color(0xFF4A9EFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    _OnboardingPage(
      emoji: '📈',
      title: 'Grow Your Wealth',
      description:
          'Track SIPs, Mutual Funds, and Stocks. See your complete net worth — savings + investments — in one place.',
      gradient: LinearGradient(
        colors: [Color(0xFF9B7FFF), Color(0xFF6C63FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    _OnboardingPage(
      emoji: '🤖',
      title: 'AI-Powered Insights',
      description:
          'Get personalized tips based on your spending patterns. Know your Financial Health Score every month.',
      gradient: LinearGradient(
        colors: [Color(0xFFFFB547), Color(0xFFFF6B6B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ];

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: AppConstants.animNormal,
        curve: Curves.easeInOut,
      );
    } else {
      _goToLogin();
    }
  }

  Future<void> _goToLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefIsFirstLaunch, false);
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (_, i) => _buildPage(_pages[i]),
          ),
          // Skip button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 24,
            child: TextButton(
              onPressed: _goToLogin,
              child: Text(
                'Skip',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ),
          ),
          // Bottom controls
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 40,
            left: 24,
            right: 24,
            child: Column(
              children: [
                // Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (i) => AnimatedContainer(
                      duration: AppConstants.animFast,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == i ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == i
                            ? AppColors.primary
                            : AppColors.darkBorder,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Next / Get Started button
                GradientButton(
                  label: _currentPage == _pages.length - 1
                      ? 'Get Started'
                      : 'Next',
                  onPressed: _nextPage,
                  gradient: _pages[_currentPage].gradient,
                  icon: _currentPage == _pages.length - 1
                      ? Icons.rocket_launch_rounded
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 100),
          // Emoji in gradient circle
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              gradient: page.gradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (page.gradient as LinearGradient)
                      .colors
                      .first
                      .withOpacity(0.35),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: Text(
                page.emoji,
                style: const TextStyle(fontSize: 64),
              ),
            ),
          ),
          const SizedBox(height: 48),
          Text(
            page.title,
            style: AppTextStyles.displayMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            page.description,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondaryDark,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
