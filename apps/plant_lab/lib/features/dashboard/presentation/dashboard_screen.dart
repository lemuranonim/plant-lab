import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../receiving/data/receiving_repository.dart';
import '../../lab_test/data/lab_repository.dart';
import '../../plant_inspection/data/inspection_repository.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final mutedTextColor = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plant+Lab'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome Section
            Text(
              'Field Inspector Panel',
              style: AppTextStyles.heading2.copyWith(color: primaryTextColor),
            ),
            const SizedBox(height: 4),
            Text(
              'Your daily operations overview',
              style: AppTextStyles.body2.copyWith(color: mutedTextColor),
            ),
            const SizedBox(height: 24),

            // Metrics Grid (3 Cards)
            Row(
              children: [
                Expanded(
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.agriculture, color: AppColors.accent, size: 24),
                        const SizedBox(height: 8),
                        ref.watch(recentHarvestsProvider).when(
                          data: (items) => Text(
                            '${items.length}',
                            style: AppTextStyles.heading2.copyWith(
                              color: primaryTextColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          loading: () => Text('-', style: AppTextStyles.heading2.copyWith(color: primaryTextColor)),
                          error: (_, __) => Text('0', style: AppTextStyles.heading2.copyWith(color: primaryTextColor)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Receiving',
                          style: AppTextStyles.caption.copyWith(color: mutedTextColor, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.assignment, color: Color(0xFF0EA5E9), size: 24),
                        const SizedBox(height: 8),
                        ref.watch(recentInspectionsProvider).when(
                          data: (items) => Text(
                            '${items.length}',
                            style: AppTextStyles.heading2.copyWith(
                              color: primaryTextColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          loading: () => Text('-', style: AppTextStyles.heading2.copyWith(color: primaryTextColor)),
                          error: (_, __) => Text('0', style: AppTextStyles.heading2.copyWith(color: primaryTextColor)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Inspections',
                          style: AppTextStyles.caption.copyWith(color: mutedTextColor, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.science, color: AppColors.warning, size: 24),
                        const SizedBox(height: 8),
                        ref.watch(recentLabTestsProvider).when(
                          data: (items) => Text(
                            '${items.length}',
                            style: AppTextStyles.heading2.copyWith(
                              color: primaryTextColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          loading: () => Text('-', style: AppTextStyles.heading2.copyWith(color: primaryTextColor)),
                          error: (_, __) => Text('0', style: AppTextStyles.heading2.copyWith(color: primaryTextColor)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Lab Tests',
                          style: AppTextStyles.caption.copyWith(color: mutedTextColor, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Quick Actions
            Text(
              'Quick Actions',
              style: AppTextStyles.heading3.copyWith(color: primaryTextColor, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildActionTile(
              context,
              icon: Icons.assignment_add,
              title: 'Plant Process Inspection',
              subtitle: 'Intake, Drier, Shelling, Cleaning, Treatment, Packing',
              color: const Color(0xFF0EA5E9),
              primaryTextColor: primaryTextColor,
              mutedTextColor: mutedTextColor,
              onTap: () => context.go('/app/inspections/processes'),
            ),
            const SizedBox(height: 12),
            _buildActionTile(
              context,
              icon: Icons.qr_code_scanner,
              title: 'Scan QR/Barcode',
              subtitle: 'Scan physical lot tag to view details',
              primaryTextColor: primaryTextColor,
              mutedTextColor: mutedTextColor,
              onTap: () => context.push('/app/scanner'),
            ),
            const SizedBox(height: 12),
            _buildActionTile(
              context,
              icon: Icons.add_business,
              title: 'Log New Intake',
              subtitle: 'Record field harvest delivery',
              color: AppColors.accent,
              primaryTextColor: primaryTextColor,
              mutedTextColor: mutedTextColor,
              onTap: () => context.go('/app/receiving/new'),
            ),
            const SizedBox(height: 12),
            _buildActionTile(
              context,
              icon: Icons.local_shipping,
              title: 'Track Lab Samples',
              subtitle: 'Monitor sample shipping & testing progress',
              color: const Color(0xFF8B5CF6),
              primaryTextColor: primaryTextColor,
              mutedTextColor: mutedTextColor,
              onTap: () => context.push('/app/lab/requests'),
            ),
            const SizedBox(height: 12),
            _buildActionTile(
              context,
              icon: Icons.science,
              title: 'Input Lab Evaluation',
              subtitle: 'Record Germination & Vigor',
              color: AppColors.warning,
              primaryTextColor: primaryTextColor,
              mutedTextColor: mutedTextColor,
              onTap: () => context.go('/app/lab/new'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color primaryTextColor,
    required Color mutedTextColor,
    Color color = AppColors.accent,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(color: mutedTextColor),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: mutedTextColor),
          ],
        ),
      ),
    );
  }
}
