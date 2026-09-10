import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_sizes.dart';
import '../../../database/db_service.dart';
import '../../../database/demo_data_seeder.dart';
import '../../../database/migration_service.dart';
import '../data/auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;

  Future<void> _enterGuestMode() async {
    setState(() => _isLoading = true);
    // Seed rich demo data for Guest Mode so the reviewer sees a filled dashboard
    await DemoDataSeeder.seedData();
    await ref.read(authProvider.notifier).signInAsGuest();
    if (mounted) {
      context.go('/home');
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    
    // Check if there is local Guest data to migrate
    final localTx = await DbService.instance.queryAllTransactions();
    final hasLocalData = localTx.isNotEmpty;

    if (hasLocalData) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      
      // Prompt migration
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMd)),
          title: const Row(
            children: [
              Icon(Icons.cloud_upload_rounded, color: AppColors.primary),
              SizedBox(width: 10),
              Text(
                'Migrate Guest Data?',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'We found transactions saved locally in Guest Mode. Would you like to upload and link them to your Google Account in the cloud?',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _performGoogleLogin(migrateData: false); // Start Fresh
              },
              child: const Text('Start Fresh', style: TextStyle(color: AppColors.error)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _performGoogleLogin(migrateData: true); // Migrate data
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusSm)),
              ),
              child: const Text('Yes, Migrate Data', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      _performGoogleLogin(migrateData: false);
    }
  }

  Future<void> _performGoogleLogin({required bool migrateData}) async {
    setState(() => _isLoading = true);
    
    // Simulate Google Sign-In and fetch user info
    // In production, this would call GoogleSignIn() and FirebaseAuth.instance.signInWithCredential()
    await Future.delayed(const Duration(seconds: 1));
    
    const mockUid = 'google_user_991823';
    const mockEmail = 'john.doe@gmail.com';
    const mockName = 'John Doe';
    const mockPhoto = 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&q=80';

    if (migrateData) {
      // Run the migration service to upload SQLite records to Firestore
      await MigrationService.migrateGuestDataToFirebase(mockUid);
    } else {
      // Clear Guest SQLite data if choosing to start fresh
      await DbService.instance.clearAllData();
    }

    // Update Auth State
    await ref.read(authProvider.notifier).signInWithGoogle(
      uid: mockUid,
      email: mockEmail,
      displayName: mockName,
      photoUrl: mockPhoto,
    );

    if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Header/Logo
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: AppColors.accentGradient,
                        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                    AppSizes.h16,
                    const Text(
                      'FinFlow',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    AppSizes.h8,
                    const Text(
                      'Take control of your financial flow',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Google Login Button
                    ElevatedButton.icon(
                      onPressed: _loginWithGoogle,
                      icon: const Icon(Icons.g_mobiledata_rounded, size: 30, color: Colors.white),
                      label: const Text(
                        'Continue with Google',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4285F4),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                        ),
                      ),
                    ),
                    AppSizes.h16,
                    
                    // Guest Mode Button
                    OutlinedButton(
                      onPressed: _enterGuestMode,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                        ),
                      ),
                      child: const Text(
                        'Try as Guest (Offline Mode)',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              
              const Spacer(),
              const Center(
                child: Text(
                  'By continuing, you agree to our Terms & Privacy Policy',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ),
              AppSizes.h16,
            ],
          ),
        ),
      ),
    );
  }
}
