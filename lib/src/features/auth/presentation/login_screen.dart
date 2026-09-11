import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_sizes.dart';
import '../../../constants/app_theme.dart';
import '../../../database/app_database.dart';
import '../../../database/demo_data_seeder.dart';
import '../../../database/migration_service.dart';
import '../data/auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.autoGoogle = false});

  /// When true (the guest "Upgrade to Cloud Sync" entry point), the Google
  /// sign-in prompt fires immediately instead of making the user land on
  /// this screen and tap "Continue with Google" a second time.
  final bool autoGoogle;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

enum _AuthMode { signIn, register }

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;
  bool _showEmailForm = false;
  _AuthMode _authMode = _AuthMode.signIn;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.autoGoogle) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loginWithGoogle());
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final profile = await ref.read(authProvider.notifier).signInWithGoogle();
      await _afterAuthenticated(profile.uid);
    } on GoogleSignInCancelled {
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Google Sign-In failed. Please try again.';
      });
    }
  }

  Future<void> _submitEmailForm() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Enter both email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final notifier = ref.read(authProvider.notifier);
      final profile = _authMode == _AuthMode.register
          ? await notifier.registerWithEmailPassword(
              email: email,
              password: password,
              displayName: _nameController.text.trim(),
            )
          : await notifier.signInWithEmailPassword(
              email: email,
              password: password,
            );
      await _afterAuthenticated(profile.uid);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = _messageForAuthError(e);
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  String _messageForAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists with that email.';
      case 'weak-password':
        return 'Choose a stronger password (at least 6 characters).';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(
        () => _errorMessage =
            'Enter your email above first, then tap "Forgot password?".',
      );
      return;
    }
    try {
      await ref.read(authProvider.notifier).sendPasswordResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset email sent to $email.')),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = _messageForAuthError(e));
    }
  }

  /// Runs once a real sign-in (Google or email/password) has succeeded and
  /// `uid` is known. Only now can we check for local guest data and, if
  /// found, offer to migrate it to this real account.
  Future<void> _afterAuthenticated(String uid) async {
    final localTx = await AppDatabase.instance
        .select(AppDatabase.instance.transactions)
        .get();

    if (localTx.isEmpty) {
      setState(() => _isLoading = false);
      if (mounted) context.go('/home');
      return;
    }

    setState(() => _isLoading = false);
    if (!mounted) return;

    final migrate = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        title: Row(
          children: [
            Icon(Icons.cloud_upload_rounded, color: context.colors.primary),
            const SizedBox(width: 10),
            Text(
              'Migrate Guest Data?',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'We found transactions saved locally in Guest Mode. Would you like to upload and link them to your account in the cloud?',
          style: TextStyle(color: context.colors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Start Fresh',
              style: TextStyle(color: context.colors.error),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
            ),
            child: const Text(
              'Yes, Migrate Data',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (migrate == true) {
      setState(() => _isLoading = true);
      final result = await MigrationService.migrateGuestDataToFirebase(uid);
      setState(() => _isLoading = false);
      if (result == MigrationResult.failed) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: context.colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            title: Text(
              'Cloud Backup Failed',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              "We couldn't back up your data to the cloud right now. Your local data is safe and untouched — you can retry from Settings later.",
              style: TextStyle(
                color: context.colors.textSecondary,
                height: 1.4,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'OK',
                  style: TextStyle(color: context.colors.primary),
                ),
              ),
            ],
          ),
        );
      }
    } else {
      // Start Fresh: this is now a real cloud account, so the local guest
      // copy is redundant — clear it rather than leaving it to be silently
      // ignored by every repository's Firestore-first read path.
      await AppDatabase.instance.clearAllData();
    }

    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.vertical,
            ),
            child: IntrinsicHeight(
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
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusLg,
                            ),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        AppSizes.h16,
                        Text(
                          'FinFlow',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        AppSizes.h8,
                        Text(
                          'Take control of your financial flow',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSizes.h32,

                  if (_isLoading)
                    Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colors.primary,
                        ),
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(AppSizes.sm),
                            decoration: BoxDecoration(
                              color: colors.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusSm,
                              ),
                              border: Border.all(color: colors.error),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: colors.error,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          AppSizes.h12,
                        ],

                        if (_showEmailForm) ...[
                          if (_authMode == _AuthMode.register) ...[
                            TextField(
                              controller: _nameController,
                              style: const TextStyle(color: Colors.white),
                              decoration: _fieldDecoration('Full name', colors),
                            ),
                            AppSizes.h12,
                          ],
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.white),
                            decoration: _fieldDecoration('Email', colors),
                          ),
                          AppSizes.h12,
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: _fieldDecoration('Password', colors),
                          ),
                          AppSizes.h8,
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _sendPasswordReset,
                              child: Text(
                                'Forgot password?',
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _submitEmailForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radiusMd,
                                ),
                              ),
                            ),
                            child: Text(
                              _authMode == _AuthMode.register
                                  ? 'Create Account'
                                  : 'Sign In',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          AppSizes.h8,
                          TextButton(
                            onPressed: () => setState(() {
                              _authMode = _authMode == _AuthMode.register
                                  ? _AuthMode.signIn
                                  : _AuthMode.register;
                              _errorMessage = null;
                            }),
                            child: Text(
                              _authMode == _AuthMode.register
                                  ? 'Already have an account? Sign In'
                                  : "Don't have an account? Create one",
                              style: TextStyle(
                                color: colors.primaryLight,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          AppSizes.h8,
                        ] else ...[
                          // Google Login Button
                          ElevatedButton.icon(
                            onPressed: _loginWithGoogle,
                            icon: const Icon(
                              Icons.g_mobiledata_rounded,
                              size: 30,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Continue with Google',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4285F4),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radiusMd,
                                ),
                              ),
                            ),
                          ),
                          AppSizes.h12,
                          OutlinedButton(
                            onPressed: () => setState(() {
                              _showEmailForm = true;
                              _errorMessage = null;
                            }),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: colors.border),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radiusMd,
                                ),
                              ),
                            ),
                            child: Text(
                              'Continue with Email',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],

                        if (!widget.autoGoogle) ...[
                          AppSizes.h16,
                          // Guest Mode Button -- hidden when arriving here to
                          // upgrade an existing guest session, since offering
                          // to re-enter guest mode at that point makes no
                          // sense.
                          OutlinedButton(
                            onPressed: _enterGuestMode,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: colors.border),
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radiusMd,
                                ),
                              ),
                            ),
                            child: Text(
                              'Try as Guest (Offline Mode)',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                  const Spacer(),
                  Center(
                    child: Text(
                      'By continuing, you agree to our Terms & Privacy Policy',
                      style: TextStyle(color: colors.textMuted, fontSize: 11),
                    ),
                  ),
                  AppSizes.h16,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, AppColorExtension colors) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: colors.textSecondary),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        borderSide: BorderSide(color: colors.primary),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
    );
  }
}
