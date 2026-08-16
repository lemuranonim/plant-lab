import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/config/app_config.dart';
import '../data/lab_request_repository.dart';

class SampleTrackerDetailScreen extends StatelessWidget {
  final Map<String, dynamic> item;
  final WidgetRef ref;

  const SampleTrackerDetailScreen({
    super.key,
    required this.item,
    required this.ref,
  });

  static const stages = [
    {'code': 'REQUESTED', 'label': 'Requested', 'icon': Icons.note_add},
    {'code': 'PREPARED', 'label': 'Prepared', 'icon': Icons.inventory},
    {'code': 'SENT', 'label': 'Sent', 'icon': Icons.local_shipping},
    {
      'code': 'RECEIVED',
      'label': 'Received',
      'icon': Icons.domain_verification,
    },
    {'code': 'IN_TESTING', 'label': 'In Testing', 'icon': Icons.science},
    {'code': 'APPROVED', 'label': 'Approved', 'icon': Icons.check_circle},
  ];

  static void show(
    BuildContext context, {
    required Map<String, dynamic> item,
    required WidgetRef ref,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SampleTrackerDetailScreen(item: item, ref: ref),
    );
  }

  int _getStageIndex(String currentStatus) {
    final s = currentStatus.toUpperCase();
    final idx = stages.indexWhere((st) => st['code'] == s);
    return idx != -1 ? idx : 0;
  }

  @override
  Widget build(BuildContext context) {
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

    final currentStatus = (item['status'] ?? 'REQUESTED')
        .toString()
        .toUpperCase();
    final currentIdx = _getStageIndex(currentStatus);
    final reqNo = item['request_no'] ?? 'REQ-2026';
    final lotId = item['lot_id_raw'] ?? 'Unknown Lot';
    final testType = item['test_type'] ?? 'Germination';
    final notes =
        item['notes'] ?? 'Pengiriman sampel benih untuk uji laboratorium.';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: mutedTextColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reqNo,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lotId,
                    style: AppTextStyles.heading2.copyWith(
                      color: primaryTextColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              StatusBadge(status: currentStatus),
            ],
          ),
          const SizedBox(height: 16),

          Text(
            'Jenis Pengujian: $testType',
            style: AppTextStyles.body2.copyWith(
              color: secondaryTextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Catatan: $notes',
            style: AppTextStyles.caption.copyWith(color: mutedTextColor),
          ),
          const SizedBox(height: 24),

          // Visual Stepper Timeline
          Text(
            'Alur Status Tracking Sampel:',
            style: AppTextStyles.labelMedium.copyWith(
              color: primaryTextColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          Column(
            children: stages.asMap().entries.map((entry) {
              final idx = entry.key;
              final st = entry.value;
              final code = st['code'] as String;
              final label = st['label'] as String;
              final icon = st['icon'] as IconData;
              final isPassed = idx <= currentIdx;
              final isCurrent = idx == currentIdx;

              return InkWell(
                onTap: AppConfig.operationalWritesEnabled
                    ? () async {
                        final repository = ref.read(
                          labRequestRepositoryProvider,
                        );
                        await repository.updateSampleStatus(
                          requestId: item['id'].toString(),
                          newStatus: code,
                        );
                        // ignore: unused_result
                        ref.refresh(labRequestsProvider);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Status sampel diperbarui menjadi $label',
                            ),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    : null,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCurrent
                              ? AppColors.accent
                              : (isPassed
                                    ? AppColors.accent.withValues(alpha: 0.2)
                                    : mutedTextColor.withValues(alpha: 0.15)),
                          border: Border.all(
                            color: isPassed
                                ? AppColors.accent
                                : mutedTextColor.withValues(alpha: 0.3),
                            width: isCurrent ? 2 : 1,
                          ),
                        ),
                        child: Icon(
                          icon,
                          size: 18,
                          color: isCurrent
                              ? Colors.white
                              : (isPassed
                                    ? AppColors.accentDark
                                    : mutedTextColor),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : (isPassed
                                      ? FontWeight.w600
                                      : FontWeight.normal),
                            color: isCurrent
                                ? AppColors.accentDark
                                : (isPassed
                                      ? primaryTextColor
                                      : mutedTextColor),
                          ),
                        ),
                      ),
                      if (isCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Aktif',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accentDark,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
