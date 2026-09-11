import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_sizes.dart';
import '../../../constants/app_theme.dart';
import '../data/goals_repository.dart';
import 'goal_form_sheet.dart';

class GoalsListScreen extends ConsumerStatefulWidget {
  const GoalsListScreen({super.key});

  @override
  ConsumerState<GoalsListScreen> createState() => _GoalsListScreenState();
}

class _GoalsListScreenState extends ConsumerState<GoalsListScreen> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(amount);
  }

  Color _hexToColor(String hex) {
    return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const GoalFormSheet(),
    );
  }

  void _showEditSheet(GoalModel goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GoalFormSheet(existing: goal),
    );
  }

  Future<void> _confirmDelete(GoalModel goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = context.colors;
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          title: Text(
            'Delete Goal?',
            style: TextStyle(color: colors.textPrimary),
          ),
          content: Text(
            'This removes "${goal.name}" and its saved progress.',
            style: TextStyle(color: colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Delete', style: TextStyle(color: colors.error)),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await ref.read(goalListProvider.notifier).remove(goal.id);
    }
  }

  void _showContributeDialog(GoalModel goal) {
    final amountController = TextEditingController();
    final screenContext = context;
    showDialog(
      context: context,
      builder: (context) {
        final colors = context.colors;
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          title: Text(
            'Contribute to ${goal.name}',
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: amountController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Amount',
              labelStyle: TextStyle(color: colors.textSecondary),
              fillColor: colors.cardBg,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(
                Icons.currency_rupee_rounded,
                color: colors.primaryLight,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? 0.0;
                if (amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a valid amount')),
                  );
                  return;
                }
                Navigator.pop(context);
                final crossed = await ref
                    .read(goalListProvider.notifier)
                    .contribute(goal, amount);
                if (!mounted) return;
                if (crossed != null) {
                  _confettiController.play();
                  final label = crossed >= 1.0
                      ? 'Goal complete! 🎉'
                      : '${(crossed * 100).toStringAsFixed(0)}% milestone reached!';
                  ScaffoldMessenger.of(screenContext).showSnackBar(
                    SnackBar(
                      content: Text('$label ${goal.name} is on track.'),
                      backgroundColor: colors.success,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(screenContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${_formatCurrency(amount)} added to ${goal.name}',
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: colors.primary),
              child: const Text(
                'Contribute',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(goalListProvider);
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Text(
          'Savings Goals',
          style: TextStyle(color: colors.textPrimary),
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: colors.primary,
        onPressed: _showAddSheet,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          goalsAsync.when(
            data: (goals) {
              if (goals.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.savings_rounded,
                        color: colors.textSecondary,
                        size: 40,
                      ),
                      AppSizes.h12,
                      Text(
                        'No savings goals yet.',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                      AppSizes.h12,
                      ElevatedButton.icon(
                        onPressed: _showAddSheet,
                        icon: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Create Goal',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(AppSizes.md),
                itemCount: goals.length,
                itemBuilder: (context, index) {
                  final g = goals[index];
                  final color = _hexToColor(g.colorHex);
                  final progress = g.progress;

                  return Card(
                    color: colors.cardBg,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      onTap: () => _showEditSheet(g),
                      onLongPress: () => _confirmDelete(g),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSizes.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: color.withValues(alpha: 0.2),
                                  child: Text(
                                    g.icon,
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                ),
                                AppSizes.w12,
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        g.name,
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (g.targetDate != null)
                                        Text(
                                          'By ${DateFormat('MMM yyyy').format(g.targetDate!)}',
                                          style: TextStyle(
                                            color: colors.textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${(progress * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            AppSizes.h12,
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: colors.border,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  color,
                                ),
                                minHeight: 6,
                              ),
                            ),
                            AppSizes.h4,
                            Text(
                              '${_formatCurrency(g.currentAmount)} of ${_formatCurrency(g.targetAmount)}',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            AppSizes.h8,
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _showContributeDialog(g),
                                icon: Icon(
                                  Icons.add_circle_outline_rounded,
                                  size: 16,
                                  color: colors.primaryLight,
                                ),
                                label: Text(
                                  'Contribute',
                                  style: TextStyle(color: colors.primaryLight),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            numberOfParticles: 24,
            maxBlastForce: 20,
            minBlastForce: 8,
            gravity: 0.3,
            colors: [
              colors.primary,
              colors.success,
              colors.warning,
              colors.secondary,
            ],
          ),
        ],
      ),
    );
  }
}
