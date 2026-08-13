import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final String? labelOverride;

  const StatusBadge({
    super.key,
    required this.status,
    this.labelOverride,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = status.toUpperCase();

    Color fgColor;
    Color bgColor;

    if (s == 'ACCEPTED' || s == 'APPROVED' || s == 'ACTIVE') {
      fgColor = isDark ? const Color(0xFF34D399) : const Color(0xFF15803D);
      bgColor = isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7);
    } else if (s == 'REJECTED' || s == 'CANCELLED') {
      fgColor = isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C);
      bgColor = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2);
    } else if (s == 'DRAFT' || s == 'PROPOSED' || s == 'RF' || s == 'YF') {
      fgColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
      bgColor = isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);
    } else {
      fgColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
      bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fgColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: fgColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            labelOverride ?? s,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: fgColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
