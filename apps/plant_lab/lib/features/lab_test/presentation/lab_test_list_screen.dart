import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../data/lab_repository.dart';

class LabTestListScreen extends ConsumerWidget {
  const LabTestListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labTestsAsync = ref.watch(recentLabTestsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final mutedTextColor = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lab Evaluations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.go('/app/lab/new'),
          ),
        ],
      ),
      body: labTestsAsync.when(
        data: (tests) {
          if (tests.isEmpty) {
            return const Center(child: Text('No lab tests available.'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              // ignore: unused_result
              ref.refresh(recentLabTestsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tests.length,
              itemBuilder: (context, index) {
                final item = tests[index];
                final germPct = item['germ_normal_pct'];
                final soakPct = item['soak_normal_pct'];
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item['lot_id_raw'] ?? 'Unknown Lot',
                              style: AppTextStyles.heading3.copyWith(
                                color: primaryTextColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            StatusBadge(
                              status: item['germ_conclusion'] ?? 'PENDING',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.eco, size: 16, color: AppColors.accent),
                            const SizedBox(width: 4),
                            Text(
                              item['hybrid_code'] ?? '-',
                              style: AppTextStyles.body2.copyWith(
                                color: secondaryTextColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Germ: ${germPct != null ? '$germPct%' : '-'}',
                              style: AppTextStyles.body2.copyWith(
                                color: germPct != null && germPct >= 80 ? AppColors.accent : AppColors.warning,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Date: ${item['germ_date'] ?? '-'}',
                              style: AppTextStyles.caption.copyWith(color: mutedTextColor),
                            ),
                            Text(
                              'Vigor: ${soakPct != null ? '$soakPct%' : '-'}',
                              style: AppTextStyles.caption.copyWith(color: secondaryTextColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: ShimmerList(itemCount: 5),
        ),
        error: (err, stack) => Center(
          child: Text('Error: $err', style: const TextStyle(color: AppColors.danger)),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/app/lab/new'),
        icon: const Icon(Icons.science),
        label: const Text('New Evaluation'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
      ),
    );
  }
}
