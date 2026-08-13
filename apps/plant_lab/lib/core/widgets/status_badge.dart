import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final String? labelOverride;

  const StatusBadge({
    super.key,
    required this.status,
    this.labelOverride,
  });

  Color _getStatusColor(String status) {
    final s = status.toUpperCase();
    if (s == 'DRAFT' || s == 'PROPOSED') return AppColors.warning;
    if (s == 'APPROVED' || s == 'ACTIVE') return AppColors.success;
    if (s == 'REJECTED' || s == 'CANCELLED') return AppColors.danger;
    if (s == 'SUBMITTED') return Colors.blue;
    return AppColors.statusDraft;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor(status);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            labelOverride ?? status.toUpperCase(),
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
