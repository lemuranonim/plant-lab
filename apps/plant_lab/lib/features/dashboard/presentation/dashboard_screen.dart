import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/access/access_context_provider.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../../core/config/app_config.dart';
import '../../../core/config/app_variant.dart';
import '../../../core/widgets/app_card.dart';
import '../../lab_test/data/lab_repository.dart';
import '../../plant_inspection/data/inspection_repository.dart';
import '../../receiving/data/receiving_repository.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(accessContextProvider).valueOrNull;
    final variant = ref.watch(appVariantProvider);
    if (access == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final mutedTextColor = isDark
        ? AppColors.textMutedDark
        : AppColors.textMutedLight;

    return Scaffold(
      appBar: AppBar(
        title: Text(variant.appName),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmSignOut(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              access.primaryRoleName,
              style: AppTextStyles.heading2.copyWith(color: primaryTextColor),
            ),
            const SizedBox(height: 4),
            Text(
              access.siteSummary,
              style: AppTextStyles.body2.copyWith(color: mutedTextColor),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final columnCount = constraints.maxWidth >= 720
                    ? 3
                    : constraints.maxWidth >= 420
                    ? 2
                    : 1;
                const gap = 10.0;
                final width =
                    (constraints.maxWidth - (gap * (columnCount - 1))) /
                    columnCount;

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    if (variant.isPlant && access.canAccessPlant) ...[
                      SizedBox(
                        width: width,
                        child: _DashboardMetric(
                          icon: Icons.agriculture,
                          color: AppColors.accent,
                          label: 'Receiving',
                          value: ref
                              .watch(recentHarvestsProvider)
                              .when(
                                data: (items) => '${items.length}',
                                loading: () => '-',
                                error: (_, __) => '0',
                              ),
                          primaryTextColor: primaryTextColor,
                          mutedTextColor: mutedTextColor,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _DashboardMetric(
                          icon: Icons.assignment,
                          color: const Color(0xFF0EA5E9),
                          label: 'Inspections',
                          value: ref
                              .watch(recentInspectionsProvider)
                              .when(
                                data: (items) => '${items.length}',
                                loading: () => '-',
                                error: (_, __) => '0',
                              ),
                          primaryTextColor: primaryTextColor,
                          mutedTextColor: mutedTextColor,
                        ),
                      ),
                    ],
                    if (variant.isLab && access.canAccessLab)
                      SizedBox(
                        width: width,
                        child: _DashboardMetric(
                          icon: Icons.science,
                          color: AppColors.warning,
                          label: 'Lab Tests',
                          value: ref
                              .watch(recentLabTestsProvider)
                              .when(
                                data: (items) => '${items.length}',
                                loading: () => '-',
                                error: (_, __) => '0',
                              ),
                          primaryTextColor: primaryTextColor,
                          mutedTextColor: mutedTextColor,
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 28),
            Text(
              'Quick Actions',
              style: AppTextStyles.heading3.copyWith(
                color: primaryTextColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (variant.isPlant && access.canAccessPlant) ...[
              _ActionTile(
                icon: Icons.assignment_add,
                title: 'Plant Process Inspection',
                subtitle:
                    'Intake, Drier, Shelling, Cleaning, Treatment, Packing',
                color: const Color(0xFF0EA5E9),
                primaryTextColor: primaryTextColor,
                mutedTextColor: mutedTextColor,
                onTap: AppConfig.operationalWritesEnabled
                    ? () => context.go('/app/inspections/processes')
                    : null,
              ),
              const SizedBox(height: 12),
              _ActionTile(
                icon: Icons.add_business,
                title: 'Log New Intake',
                subtitle: 'Record field harvest delivery',
                color: AppColors.accent,
                primaryTextColor: primaryTextColor,
                mutedTextColor: mutedTextColor,
                onTap: AppConfig.operationalWritesEnabled
                    ? () => context.go('/app/receiving/new')
                    : null,
              ),
              const SizedBox(height: 12),
            ],
            _ActionTile(
              icon: Icons.qr_code_scanner,
              title: 'Scan QR/Barcode',
              subtitle: 'Scan physical lot tag to view details',
              primaryTextColor: primaryTextColor,
              mutedTextColor: mutedTextColor,
              onTap: () => context.push('/app/scanner'),
            ),
            if (variant.isLab && access.canAccessLab) ...[
              const SizedBox(height: 12),
              _ActionTile(
                icon: Icons.local_shipping,
                title: 'Track Lab Samples',
                subtitle: 'Monitor sample shipping and testing progress',
                color: const Color(0xFF8B5CF6),
                primaryTextColor: primaryTextColor,
                mutedTextColor: mutedTextColor,
                onTap: () => context.push('/app/lab/requests'),
              ),
              const SizedBox(height: 12),
              _ActionTile(
                icon: Icons.science,
                title: 'Input Lab Evaluation',
                subtitle: 'Record Germination and Vigor',
                color: AppColors.warning,
                primaryTextColor: primaryTextColor,
                mutedTextColor: mutedTextColor,
                onTap: AppConfig.operationalWritesEnabled
                    ? () => context.go('/app/lab/new')
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari aplikasi?'),
        content: const Text(
          'Sesi aplikasi pada perangkat ini akan diakhiri. Anda perlu login '
          'kembali untuk melanjutkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.logout),
            label: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (shouldSignOut != true || !context.mounted) return;
    await ref.read(authNotifierProvider.notifier).signOut();
  }
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.primaryTextColor,
    required this.mutedTextColor,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final Color primaryTextColor;
  final Color mutedTextColor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.heading2.copyWith(
              color: primaryTextColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: mutedTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.primaryTextColor,
    required this.mutedTextColor,
    this.color = AppColors.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color primaryTextColor;
  final Color mutedTextColor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.55 : 1,
      child: InkWell(
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
                      style: AppTextStyles.caption.copyWith(
                        color: mutedTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                onTap == null ? Icons.lock_outline : Icons.chevron_right,
                color: mutedTextColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
