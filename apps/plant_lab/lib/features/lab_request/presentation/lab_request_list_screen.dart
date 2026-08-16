import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/config/app_config.dart';
import '../data/lab_request_repository.dart';
import 'sample_tracker_detail_screen.dart';

class LabRequestListScreen extends ConsumerWidget {
  const LabRequestListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(labRequestsProvider);
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
        title: const Text('Lab Requests & Tracking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: AppConfig.operationalWritesEnabled
                ? () => context.push('/app/lab/requests/new')
                : null,
          ),
        ],
      ),
      body: requestsAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 64,
                    color: mutedTextColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Belum Ada Request Sampel Lab',
                    style: AppTextStyles.body1.copyWith(
                      color: primaryTextColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Buat permintaan pengujian lab baru untuk Lot benih',
                    style: AppTextStyles.caption.copyWith(
                      color: mutedTextColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: AppConfig.operationalWritesEnabled
                        ? () => context.push('/app/lab/requests/new')
                        : null,
                    icon: const Icon(Icons.add),
                    label: const Text(
                      AppConfig.operationalWritesEnabled
                          ? 'Buat Request Sampel Baru'
                          : 'Mode read-only aktif',
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              // ignore: unused_result
              ref.refresh(labRequestsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final item = requests[index];
                final reqNo = item['request_no'] ?? 'REQ-2026';
                final lotId = item['lot_id_raw'] ?? 'Unknown Lot';
                final testType = item['test_type'] ?? 'Germination';
                final status = item['status'] ?? 'REQUESTED';
                final sampleQty = item['sample_qty_grams'] ?? 500;
                final samplerName = item['sampler_name'] ?? 'Inspector';
                final requestedAt = item['requested_at'] != null
                    ? item['requested_at'].toString().split('T')[0]
                    : '-';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    onTap: () {
                      SampleTrackerDetailScreen.show(
                        context,
                        item: item,
                        ref: ref,
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              reqNo,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accent,
                              ),
                            ),
                            StatusBadge(status: status),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              lotId,
                              style: AppTextStyles.heading3.copyWith(
                                color: primaryTextColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${sampleQty}g',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Pengujian: $testType',
                          style: AppTextStyles.body2.copyWith(
                            color: secondaryTextColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Pengambil: $samplerName',
                              style: AppTextStyles.caption.copyWith(
                                color: mutedTextColor,
                              ),
                            ),
                            Text(
                              'Tgl: $requestedAt',
                              style: AppTextStyles.caption.copyWith(
                                color: mutedTextColor,
                              ),
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
          child: Text(
            'Error: $err',
            style: const TextStyle(color: AppColors.danger),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: AppConfig.operationalWritesEnabled
            ? () => context.push('/app/lab/requests/new')
            : null,
        icon: const Icon(Icons.send),
        label: const Text(
          AppConfig.operationalWritesEnabled ? 'New Request' : 'Read-only',
        ),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
      ),
    );
  }
}
