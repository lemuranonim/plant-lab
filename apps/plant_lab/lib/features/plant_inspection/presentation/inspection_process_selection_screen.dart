import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';

class InspectionProcessSelectionScreen extends StatelessWidget {
  const InspectionProcessSelectionScreen({super.key});

  static const processes = [
    {
      'type': 'INTAKE',
      'title': 'Intake Inspection',
      'subtitle': 'Waiting time, Manpower, Akurasi Sortir (≥95%), COH',
      'icon': Icons.move_to_inbox,
      'color': Color(0xFF0EA5E9),
    },
    {
      'type': 'DRIER',
      'title': 'Drier Inspection',
      'subtitle': 'Suhu BIN (39–41°C), MC Stop (10.0–10.5%), Tipe BIN',
      'icon': Icons.local_fire_department,
      'color': Color(0xFFF59E0B),
    },
    {
      'type': 'SHELLING',
      'title': 'Shelling Inspection',
      'subtitle': 'MC DSS (10.0–10.5%), RPM & Inverter, Identitas JB',
      'icon': Icons.grain,
      'color': Color(0xFF8B5CF6),
    },
    {
      'type': 'CLEANING',
      'title': 'Cleaning Inspection',
      'subtitle': 'Clearance, Sampling PP, MC DCS (<12%), Reject Dominan',
      'icon': Icons.filter_alt,
      'color': Color(0xFF10B981),
    },
    {
      'type': 'TREATMENT',
      'title': 'Treatment Inspection',
      'subtitle': 'Dosis Bahan Kimia, Kalibrasi Slurry, Keseragaman',
      'icon': Icons.science,
      'color': Color(0xFFEC4899),
    },
    {
      'type': 'PACKING',
      'title': 'Packing Inspection',
      'subtitle': 'Printing, Sealing, Berat (1000–1020g), MC FG (<12%)',
      'icon': Icons.inventory_2,
      'color': Color(0xFF6366F1),
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final mutedTextColor = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Proses Inspeksi'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: processes.length,
        itemBuilder: (context, index) {
          final p = processes[index];
          final color = p['color'] as Color;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              onTap: () {
                context.go('/app/inspections/new/${p['type']}');
              },
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      p['icon'] as IconData,
                      color: color,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p['title'] as String,
                          style: AppTextStyles.body1.copyWith(
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p['subtitle'] as String,
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
        },
      ),
    );
  }
}
