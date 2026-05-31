import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/settings_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/common_widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsNotifierProvider);
    final isDark = ref.watch(themeModeProvider);
    final userAsync = ref.watch(currentUserProvider);
    final isGuest = ref.watch(guestSessionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Settings', style: AppTextStyles.headlineMedium),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
                    // Quick actions for accounts and categories
                    _SectionLabel(label: 'Manage'),
                    _SettingsTile(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Create Account',
                      subtitle: 'Add a new bank, card, or cash account',
                      onTap: () => GoRouter.of(context).push('/add-account'),
                    ),
                    _SettingsTile(
                      icon: Icons.category_rounded,
                      title: 'Manage Categories',
                      subtitle: 'Add or edit income, expense, investment categories',
                      onTap: () => GoRouter.of(context).push('/manage-categories'),
                    ),
                    const SizedBox(height: 20),
          // Profile section
          userAsync.when(
            data: (user) => user != null
                ? _ProfileCard(
                    name: user.name,
                    email: user.email,
                    photoUrl: user.photoUrl,
                  )
                : const SizedBox.shrink(),
            loading: () => const ShimmerCard(height: 80),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),

          // Guest upgrade banner + name edit
          if (isGuest) ...[
            _SettingsTile(
              icon: Icons.badge_outlined,
              title: 'Display Name',
              subtitle: userAsync.value?.name ?? 'Guest',
              onTap: () => _showEditNameDialog(
                  context, ref, userAsync.value?.name ?? 'Guest'),
            ),
            const SizedBox(height: 8),
            _GuestUpgradeBanner(
            onSignIn: () => ref
                .read(authNotifierProvider.notifier)
                .signInWithGoogle(),
          ), const SizedBox(height: 20)],

          // Appearance
          _SectionLabel(label: 'Appearance'),
          _SettingsTile(
            icon: Icons.dark_mode_rounded,
            title: 'Dark Mode',
            trailing: Switch(
              value: isDark,
              onChanged: (_) =>
                  ref.read(themeModeProvider.notifier).toggle(),
              activeColor: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),

          // Security
          _SectionLabel(label: 'Security'),
          if (isGuest)
            _LockedFeatureTile(
              icon: Icons.fingerprint_rounded,
              title: 'Biometric Lock',
              onSignIn: () => ref
                  .read(authNotifierProvider.notifier)
                  .signInWithGoogle(),
            )
          else
            _SettingsTile(
              icon: Icons.fingerprint_rounded,
              title: 'Biometric Lock',
              subtitle: 'Use fingerprint/face to unlock',
              trailing: Switch(
                value: settings.biometricEnabled,
                onChanged: (val) => ref
                    .read(settingsNotifierProvider.notifier)
                    .toggleBiometric(val),
                activeColor: AppColors.primary,
              ),
            ),
          if (!isGuest)
            _SettingsTile(
              icon: Icons.lock_clock_rounded,
              title: 'Auto Lock',
              subtitle: '${settings.autoLockMinutes} minutes',
              onTap: () => _showAutoLockDialog(context, ref, settings),
            ),
          const SizedBox(height: 16),

          // Budget
          _SectionLabel(label: 'Budget'),
          _SettingsTile(
            icon: Icons.message_rounded,
            title: 'SMS Auto-Import',
            subtitle: 'Parse bank SMS for transactions',
            trailing: Switch(
              value: settings.smsParsingEnabled,
              onChanged: (val) => ref
                  .read(settingsNotifierProvider.notifier)
                  .toggleSmsParsing(val),
              activeColor: AppColors.primary,
            ),
          ),
          _SettingsTile(
            icon: Icons.calendar_month_rounded,
            title: 'Budget Reset Day',
            subtitle: 'Day ${settings.budgetResetDay} of each month',
            onTap: () =>
                _showResetDayDialog(context, ref, settings),
          ),
          const SizedBox(height: 16),

          // About
          _SectionLabel(label: 'About'),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'App Version',
            subtitle: '1.0.0 (Build 1)',
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () => GoRouter.of(context).push('/privacy-policy'),
          ),
          const SizedBox(height: 16),

          // Sign Out / Sign In
          if (isGuest)
            Container(
              padding: const EdgeInsets.all(4),
              child: ListTile(
                tileColor: AppColors.primary.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: AppColors.primary.withOpacity(0.4))),
                leading:
                    const Icon(Icons.login_rounded, color: AppColors.primary),
                title: Text('Sign In with Google',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.primary)),
                subtitle: Text('Sync your data across devices',
                    style: AppTextStyles.caption),
                onTap: () => ref
                    .read(authNotifierProvider.notifier)
                    .signInWithGoogle(),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(4),
              child: ListTile(
                tileColor: AppColors.expenseRed.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: AppColors.expenseRed.withOpacity(0.3))),
                leading: const Icon(Icons.logout_rounded,
                    color: AppColors.expenseRed),
                title: Text('Sign Out',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.expenseRed)),
                onTap: () => _confirmSignOut(context, ref),
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  void _showEditNameDialog(
      BuildContext context, WidgetRef ref, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Display Name'),
        content: TextField(
          controller: controller,
          decoration:
              const InputDecoration(hintText: 'Enter your name'),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(guestNameProvider.notifier).setName(name);
              }
              Navigator.pop(context);
            },
            child: Text('Save',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showAutoLockDialog(
      BuildContext context, WidgetRef ref, SettingsState settings) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Auto Lock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [1, 2, 5, 10, 30]
              .map((min) => RadioListTile<int>(
                    value: min,
                    groupValue: settings.autoLockMinutes,
                    onChanged: (v) {
                      ref
                          .read(settingsNotifierProvider.notifier)
                          .updateAutoLock(v!);
                      Navigator.pop(context);
                    },
                    title: Text('$min minutes'),
                    activeColor: AppColors.primary,
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _showResetDayDialog(
      BuildContext context, WidgetRef ref, SettingsState settings) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Budget Reset Day'),
        content: SizedBox(
          width: double.maxFinite,
          height: 350,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: 28,
            itemBuilder: (_, i) {
              final day = i + 1;
              return RadioListTile<int>(
                value: day,
                groupValue: settings.budgetResetDay,
                onChanged: (v) {
                  ref
                      .read(settingsNotifierProvider.notifier)
                      .updateBudgetResetDay(v!);
                  Navigator.pop(context);
                },
                title: Text('Day $day'),
                activeColor: AppColors.primary,
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out',
                style: TextStyle(color: AppColors.expenseRed)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authNotifierProvider.notifier).signOut();
    }
  }
}

class _ProfileCard extends StatelessWidget {
  final String name;
  final String email;
  final String? photoUrl;

  const _ProfileCard({
    required this.name,
    required this.email,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary.withOpacity(0.2),
            backgroundImage:
                photoUrl != null ? NetworkImage(photoUrl!) : null,
            child: photoUrl == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: AppTextStyles.headlineMedium
                        .copyWith(color: AppColors.primary),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.bodyMedium),
                Text(email,
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.overline
            .copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        tileColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, color: AppColors.primary, size: 22),
        title: Text(title, style: AppTextStyles.bodyMedium),
        subtitle: subtitle != null
            ? Text(subtitle!,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary))
            : null,
        trailing: trailing ??
            (onTap != null
                ? const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary)
                : null),
        onTap: onTap,
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────────
// Guest Upgrade Banner
// ───────────────────────────────────────────────────────────────────────────────
class _GuestUpgradeBanner extends StatelessWidget {
  final VoidCallback onSignIn;

  const _GuestUpgradeBanner({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.15),
            AppColors.primary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.primary.withOpacity(0.3), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.cloud_sync_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('You\'re in Guest Mode',
                        style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600)),
                    Text('Data is stored locally only',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '• Sign in to sync across devices\n• Unlock biometric security\n• Enable cloud backup',
            style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.6),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onSignIn,
              icon: const Text('G',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4285F4))),
              label: const Text('Continue with Google'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1A1A2E),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────────
// Locked Feature (guest-mode placeholder)
// ───────────────────────────────────────────────────────────────────────────────
class _LockedFeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onSignIn;

  const _LockedFeatureTile({
    required this.icon,
    required this.title,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        tileColor: AppColors.surfaceCard,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, color: AppColors.textSecondary, size: 22),
        title: Text(title,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary)),
        subtitle: Text('Sign in with Google to enable',
            style: AppTextStyles.caption
                .copyWith(color: AppColors.primary.withOpacity(0.8))),
        trailing: const Icon(Icons.lock_rounded,
            color: AppColors.textSecondary, size: 18),
        onTap: onSignIn,
      ),
    );
  }
}
