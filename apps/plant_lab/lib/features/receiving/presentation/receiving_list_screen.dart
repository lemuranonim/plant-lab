import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/config/app_config.dart';
import '../data/receiving_repository.dart';

class ReceivingListScreen extends ConsumerWidget {
  const ReceivingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final harvestsAsync = ref.watch(recentHarvestsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final mutedTextColor = isDark
        ? AppColors.textMutedDark
        : AppColors.textMutedLight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receiving Harvest'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: AppConfig.operationalWritesEnabled
                ? () => context.go('/app/receiving/new')
                : null,
          ),
        ],
      ),
      body: harvestsAsync.when(
        data: (harvests) {
          if (harvests.isEmpty) {
            return const Center(child: Text('No harvest data available.'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              // ignore: unused_result
              ref.refresh(recentHarvestsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: harvests.length,
              itemBuilder: (context, index) {
                final item = harvests[index];
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
                              status: item['field_status'] ?? 'DRAFT',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.eco,
                              size: 16,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              item['hybrid_code'] ?? '-',
                              style: AppTextStyles.body2.copyWith(
                                color: secondaryTextColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(Icons.scale, size: 16, color: mutedTextColor),
                            const SizedBox(width: 4),
                            Text(
                              '${item['shelling_qty_kg'] ?? 0} kg',
                              style: AppTextStyles.body2.copyWith(
                                color: secondaryTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Date: ${item['incoming_date'] != null ? item['incoming_date'].toString().split('T')[0] : '-'}',
                          style: AppTextStyles.caption.copyWith(
                            color: mutedTextColor,
                          ),
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
          child: Text(
            'Error: $err',
            style: const TextStyle(color: AppColors.danger),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: AppConfig.operationalWritesEnabled
            ? () => context.go('/app/receiving/new')
            : null,
        icon: const Icon(Icons.add),
        label: const Text(
          AppConfig.operationalWritesEnabled ? 'New Intake' : 'Read-only',
        ),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
      ),
    );
  }
}
