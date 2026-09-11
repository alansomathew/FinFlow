import 'package:flutter/material.dart';
import '../../../constants/app_theme.dart';
import 'investments_tab.dart';

/// Full-screen wrapper around [InvestmentsTab] for the profile-menu entry
/// point -- Investments moved out of the bottom tab bar (alongside
/// Accounts/Goals) to restore a symmetric 2-left/2-right tab split around
/// the centered Add Transaction FAB.
class InvestmentsScreen extends StatelessWidget {
  const InvestmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Text('Investments', style: TextStyle(color: colors.textPrimary)),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: const InvestmentsTab(),
    );
  }
}
