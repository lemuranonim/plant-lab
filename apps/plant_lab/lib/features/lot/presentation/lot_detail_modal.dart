import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/status_badge.dart';

class LotDetailModal extends StatelessWidget {
  final String lotId;
  final Map<String, dynamic>? lotData;

  const LotDetailModal({
    super.key,
    required this.lotId,
    this.lotData,
  });

  static void show(BuildContext context, {required String lotId, Map<String, dynamic>? lotData}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LotDetailModal(lotId: lotId, lotData: lotData),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final mutedTextColor = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    final hybridCode = lotData?['hybrid_code'] ?? 'PAC789';
    final qtyKg = lotData?['shelling_qty_kg'] ?? lotData?['quantity_kg'] ?? 1250;
    final status = lotData?['field_status'] ?? lotData?['status'] ?? 'ACTIVE';

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
          // Drag handle
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

          // Lot Header & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lotId,
                    style: AppTextStyles.heading2.copyWith(
                      color: primaryTextColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Scanned Lot Barcode / Tag',
                    style: AppTextStyles.caption.copyWith(color: mutedTextColor),
                  ),
                ],
              ),
              StatusBadge(status: status.toString()),
            ],
          ),
          const SizedBox(height: 20),

          // Key Specifications Grid
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Varietas / Hybrid', style: AppTextStyles.caption.copyWith(color: mutedTextColor)),
                      const SizedBox(height: 4),
                      Text(
                        hybridCode.toString(),
                        style: AppTextStyles.body1.copyWith(color: primaryTextColor, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Container(height: 30, width: 1, color: mutedTextColor.withValues(alpha: 0.3)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quantity (Kg)', style: AppTextStyles.caption.copyWith(color: mutedTextColor)),
                      const SizedBox(height: 4),
                      Text(
                        '$qtyKg Kg',
                        style: AppTextStyles.body1.copyWith(color: primaryTextColor, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/app/receiving/new');
                  },
                  icon: const Icon(Icons.add_business),
                  label: const Text('Receiving'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/app/inspections/processes');
                  },
                  icon: const Icon(Icons.assignment_add),
                  label: const Text('Isi Inspeksi'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
