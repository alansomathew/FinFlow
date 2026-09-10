import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'routing/app_router.dart';
import 'constants/app_colors.dart';


class FinFlowApp extends ConsumerWidget {
  const FinFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'FinFlow',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      
      // Premium Dark Theme First configuration
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
          background: AppColors.background,
          error: AppColors.error,
        ),
        
        // Font customization
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
          bodyLarge: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 16),
          bodyMedium: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 14),
          titleLarge: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          elevation: 0,
        ),
      ),
    );
  }
}
