import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';

/// The device's theme and language preferences, both stored on the same
/// single-row `local_settings` table as [isProProvider] -- this is the
/// natural starting point for the full Settings module Phase 12 will
/// eventually build out.
final themeModeProvider = StreamProvider<ThemeMode>((ref) {
  return AppDatabase.instance.watchLocalSettings().map((row) {
    switch (row.themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      case 'dark':
      default:
        return ThemeMode.dark;
    }
  });
});

Future<void> setThemeMode(ThemeMode mode) {
  final value = switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.system => 'system',
    ThemeMode.dark => 'dark',
  };
  return AppDatabase.instance.setThemeMode(value);
}

/// Null means "follow the device's system locale" -- the default, and the
/// only way to get any of the languages this app doesn't have an explicit
/// selector entry for but the OS + Flutter's localization resolution
/// still support.
final localeProvider = StreamProvider<Locale?>((ref) {
  return AppDatabase.instance.watchLocalSettings().map((row) {
    return row.languageCode != null ? Locale(row.languageCode!) : null;
  });
});

Future<void> setLanguageCode(String? code) {
  return AppDatabase.instance.setLanguageCode(code);
}
