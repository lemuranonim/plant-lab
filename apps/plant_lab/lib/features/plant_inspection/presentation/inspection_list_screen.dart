import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../data/inspection_repository.dart';

class InspectionListScreen extends ConsumerWidget {
  const InspectionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspectionsAsync = ref.watch(recentInspectionsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final mutedTextColor = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plant Inspections'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.go('/app/inspections/processes'),
          ),
        ],
      ),
      body: inspectionsAsync.when(
        data: (inspections) {
          if (inspections.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_outlined, size: 64, color: mutedTextColor),
                  const SizedBox(height: 16),
                  Text(
                    'Belum Ada Inspeksi Plant Tersimpan',
                    style: AppTextStyles.body1.copyWith(color: primaryTextColor, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Klik tombol di bawah untuk mengisi inspeksi baru',
                    style: AppTextStyles.caption.copyWith(color: mutedTextColor),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/app/inspections/processes'),
                    icon: const Icon(Icons.add),
                    label: const Text('Isi Form Inspeksi baru'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              // ignore: unused_result
              ref.refresh(recentInspectionsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: inspections.length,
              itemBuilder: (context, index) {
                final item = inspections[index];
                final processType = item['process_type'] ?? 'UNKNOWN';
                final isOos = item['is_oos'] == true;
                final dateRaw = item['created_at'] ?? item['submitted_at'] ?? item['inspection_date'];
                final inspectedAt = dateRaw != null
                    ? dateRaw.toString().split('T')[0]
                    : '-';
                final inspectorEmail = item['inspector_email'] ?? 'Plant Inspector';
                final notes = item['notes'] ?? item['remarks'] ?? 'Hasil pengawasan proses $processType';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                processType,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppColors.accentDark,
                                ),
                              ),
                            ),
                            StatusBadge(
                              status: isOos ? 'REJECTED' : 'APPROVED',
                              labelOverride: isOos ? 'OUT OF SPEC' : 'PASSED',
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          notes,
                          style: AppTextStyles.body1.copyWith(
                            color: primaryTextColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Oleh: $inspectorEmail',
                              style: AppTextStyles.caption.copyWith(color: secondaryTextColor),
                            ),
                            Text(
                              'Tanggal: $inspectedAt',
                              style: AppTextStyles.caption.copyWith(color: mutedTextColor),
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
        onPressed: () => context.go('/app/inspections/processes'),
        icon: const Icon(Icons.add),
        label: const Text('New Inspection'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
      ),
    );
  }
}
