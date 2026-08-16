import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/photo_evidence_picker.dart';
import '../../../core/config/app_config.dart';
import '../data/inspection_repository.dart';

class DynamicInspectionFormScreen extends ConsumerStatefulWidget {
  final String processType;

  const DynamicInspectionFormScreen({super.key, required this.processType});

  @override
  ConsumerState<DynamicInspectionFormScreen> createState() =>
      _DynamicInspectionFormScreenState();
}

class _DynamicInspectionFormScreenState
    extends ConsumerState<DynamicInspectionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formData = {};
  List<File> _mcPhotos = [];
  List<File> _ppPhotos = [];
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(inspectionRepositoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final mutedTextColor = isDark
        ? AppColors.textMutedDark
        : AppColors.textMutedLight;

    return Scaffold(
      appBar: AppBar(
        title: Text('Form Inspeksi ${widget.processType.toUpperCase()}'),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: repository.fetchFormTemplateByProcess(widget.processType),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Text(
                'Template untuk ${widget.processType} tidak ditemukan.',
                style: const TextStyle(color: AppColors.danger),
              ),
            );
          }

          final template = snapshot.data!;
          final rawFields = template['fields'];
          final List<dynamic> fields = rawFields is Map
              ? (rawFields['fields'] ?? [])
              : [];

          // Determine if MC or PP parameters exist to set mandatory photo requirements (Rule R-002 & R-003)
          final hasMcParam = fields.any((f) {
            final k = (f as Map)['key']?.toString().toLowerCase() ?? '';
            return k.contains('mc');
          });

          final hasPpParam = fields.any((f) {
            final k = (f as Map)['key']?.toString().toLowerCase() ?? '';
            return k.contains('pp');
          });

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header Info Card
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.assignment,
                              color: AppColors.accent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            template['template_name'] ?? 'Form Inspeksi',
                            style: AppTextStyles.heading3.copyWith(
                              color: primaryTextColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Isi data hasil pengawasan sesuai parameter di bawah ini:',
                        style: AppTextStyles.caption.copyWith(
                          color: mutedTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Render Dynamic Fields
                ...fields.map((field) {
                  final fieldMap = field as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildDynamicField(
                      fieldMap,
                      primaryTextColor,
                      mutedTextColor,
                    ),
                  );
                }),

                // Photo Evidence Picker: Rule R-002 (MC min 3 photos)
                if (hasMcParam) ...[
                  const SizedBox(height: 8),
                  PhotoEvidencePicker(
                    title: 'Foto Bukti Kadar Air (MC)',
                    subtitle:
                        'Wajib mengunggah minimal 3 foto bukti pengujian MC (Aturan R-002)',
                    minPhotos: 3,
                    onPhotosChanged: (photos) {
                      setState(() => _mcPhotos = photos);
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Photo Evidence Picker: Rule R-003 (PP min 1 photo)
                if (hasPpParam) ...[
                  const SizedBox(height: 8),
                  PhotoEvidencePicker(
                    title: 'Foto Bukti Kemurnian Fisik (PP)',
                    subtitle:
                        'Wajib mengunggah minimal 1 foto bukti pengujian PP (Aturan R-003)',
                    minPhotos: 1,
                    onPhotosChanged: (photos) {
                      setState(() => _ppPhotos = photos);
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed:
                      AppConfig.operationalWritesEnabled && !_isSubmitting
                      ? () => _submitForm(fields, hasMcParam, hasPpParam)
                      : null,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          AppConfig.operationalWritesEnabled
                              ? 'Simpan Inspeksi ${widget.processType.toUpperCase()}'
                              : 'Mode read-only aktif',
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDynamicField(
    Map<String, dynamic> field,
    Color primaryTextColor,
    Color mutedTextColor,
  ) {
    final key = field['key'] as String;
    final label = field['label'] as String;
    final type = field['type'] as String;
    final isRequired = field['required'] == true;

    if (type == 'text' || type == 'number' || type == 'textarea') {
      return TextFormField(
        keyboardType: type == 'number'
            ? TextInputType.number
            : TextInputType.text,
        maxLines: type == 'textarea' ? 3 : 1,
        decoration: InputDecoration(
          labelText: label + (isRequired ? ' *' : ''),
        ),
        validator: (val) {
          if (isRequired && (val == null || val.trim().isEmpty)) {
            return '$label wajib diisi';
          }
          return null;
        },
        onChanged: (val) {
          _formData[key] = type == 'number' ? double.tryParse(val) ?? val : val;
        },
      );
    }

    if (type == 'radio') {
      final rawOptions = field['options'] as List<dynamic>? ?? [];
      final currentValue = _formData[key];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label + (isRequired ? ' *' : ''),
            style: AppTextStyles.body1.copyWith(
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: rawOptions.map((opt) {
              final optMap = opt as Map<String, dynamic>;
              final val = optMap['value'];
              final optLabel = optMap['label'] as String;
              final isSelected = currentValue == val;
              final isPass = optMap['pass'] != false;

              return ChoiceChip(
                label: Text(optLabel),
                selected: isSelected,
                selectedColor: isPass
                    ? AppColors.accent.withValues(alpha: 0.2)
                    : AppColors.danger.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color: isSelected
                      ? (isPass ? AppColors.accentDark : AppColors.danger)
                      : primaryTextColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _formData[key] = val;
                      _formData['${key}_pass'] = isPass;
                    });
                  }
                },
              );
            }).toList(),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _submitForm(
    List<dynamic> fields,
    bool hasMcParam,
    bool hasPpParam,
  ) async {
    if (!_formKey.currentState!.validate()) return;

    // Enforce Rule R-002: Minimum 3 MC Photos
    if (hasMcParam && _mcPhotos.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aturan R-002: Anda wajib melampirkan minimal 3 foto bukti pengujian MC!',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    // Enforce Rule R-003: Minimum 1 PP Photo
    if (hasPpParam && _ppPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aturan R-003: Anda wajib melampirkan minimal 1 foto bukti pengujian PP!',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      bool isOos = false;

      // Evaluate OOS triggers
      for (final field in fields) {
        final fieldMap = field as Map<String, dynamic>;
        final key = fieldMap['key'];
        if (fieldMap['oos_trigger'] == true) {
          if (_formData['${key}_pass'] == false) {
            isOos = true;
          }
        }
      }

      _formData['mc_photo_count'] = _mcPhotos.length;
      _formData['pp_photo_count'] = _ppPhotos.length;

      final repository = ref.read(inspectionRepositoryProvider);
      await repository.submitInspection(
        processType: widget.processType,
        formData: _formData,
        isOos: isOos,
        remarks: _formData['remarks']?.toString(),
      );

      // ignore: unused_result
      ref.refresh(recentInspectionsProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isOos
                ? 'Inspeksi ${widget.processType} berhasil disimpan (Status: OUT OF SPEC).'
                : 'Inspeksi ${widget.processType} berhasil disimpan (Status: PASSED).',
          ),
          backgroundColor: isOos ? AppColors.warning : AppColors.success,
        ),
      );

      context.go('/app/inspections');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan inspeksi: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
