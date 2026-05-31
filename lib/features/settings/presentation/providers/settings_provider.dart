import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/constants/app_constants.dart';

// ── Theme Mode ────────────────────────────────────────────────────────────
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, bool>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<bool> {
  ThemeModeNotifier() : super(true) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(AppConstants.keyDarkMode) ?? true;
  }

  Future<void> toggle() async {
    final prefs = await SharedPreferences.getInstance();
    state = !state;
    await prefs.setBool(AppConstants.keyDarkMode, state);
  }
}

// ── Settings Notifier ─────────────────────────────────────────────────────
class SettingsState {
  final bool smsParsingEnabled;
  final bool biometricEnabled;
  final int autoLockMinutes;
  final int budgetResetDay;
  final String currency;
  final bool notificationsEnabled;

  const SettingsState({
    this.smsParsingEnabled = false,
    this.biometricEnabled = false,
    this.autoLockMinutes = 5,
    this.budgetResetDay = 1,
    this.currency = 'INR',
    this.notificationsEnabled = true,
  });

  SettingsState copyWith({
    bool? smsParsingEnabled,
    bool? biometricEnabled,
    int? autoLockMinutes,
    int? budgetResetDay,
    String? currency,
    bool? notificationsEnabled,
  }) =>
      SettingsState(
        smsParsingEnabled: smsParsingEnabled ?? this.smsParsingEnabled,
        biometricEnabled: biometricEnabled ?? this.biometricEnabled,
        autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
        budgetResetDay: budgetResetDay ?? this.budgetResetDay,
        currency: currency ?? this.currency,
        notificationsEnabled:
            notificationsEnabled ?? this.notificationsEnabled,
      );
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final user = ref.watch(currentUserProvider);
  return SettingsNotifier(
      user.value,
      FirebaseFirestore.instance,
      FirebaseAuth.instance);
});

// Alias for backward compatibility
final settingsNotifierProvider = settingsProvider;

class SettingsNotifier extends StateNotifier<SettingsState> {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  SettingsNotifier(UserModel? user, this._firestore, this._auth)
      : super(SettingsState(
          smsParsingEnabled: user?.smsParsingEnabled ?? false,
          biometricEnabled: user?.biometricEnabled ?? false,
          autoLockMinutes: user?.autoLockMinutes ?? 5,
          budgetResetDay: user?.budgetResetDay ?? 1,
          currency: user?.currency ?? 'INR',
        ));

  String get _uid => _auth.currentUser?.uid ?? '';
  bool get _isGuest => _auth.currentUser?.isAnonymous ?? true;

  Future<void> updateSetting(String field, dynamic value) async {
    if (_isGuest || _uid.isEmpty) return; // local-only for guest users
    try {
      await _firestore
          .collection(AppConstants.colUsers)
          .doc(_uid)
          .update({field: value});
    } catch (_) {
      // Silently ignore Firestore errors (e.g. PERMISSION_DENIED, offline)
    }
  }

  Future<void> toggleSmsParsing(bool value) async {
    state = state.copyWith(smsParsingEnabled: value);
    await updateSetting('smsParsingEnabled', value);
  }

  Future<bool> toggleBiometric(bool value) async {
    if (value) {
      final localAuth = LocalAuthentication();
      final canAuth = await localAuth.canCheckBiometrics;
      if (!canAuth) return false;
      final authenticated = await localAuth.authenticate(
        localizedReason: 'Authenticate to enable biometric lock',
      );
      if (!authenticated) return false;
    }
    state = state.copyWith(biometricEnabled: value);
    await updateSetting('biometricEnabled', value);
    return true;
  }

  Future<void> updateAutoLock(int minutes) async {
    state = state.copyWith(autoLockMinutes: minutes);
    await updateSetting('autoLockMinutes', minutes);
  }

  Future<void> updateBudgetResetDay(int day) async {
    state = state.copyWith(budgetResetDay: day);
    await updateSetting('budgetResetDay', day);
  }
}
