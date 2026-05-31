import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Privacy Policy', style: AppTextStyles.headlineMedium),
              const SizedBox(height: 16),
              Text(
                'Your privacy is important to us. This app does not share your personal information with third parties. All data is securely stored and only used for the purpose of providing you with financial management features. For more details, contact support.',
                style: AppTextStyles.bodyMedium,
              ),
              // Add more sections as needed
            ],
          ),
        ),
      ),
    );
  }
}
