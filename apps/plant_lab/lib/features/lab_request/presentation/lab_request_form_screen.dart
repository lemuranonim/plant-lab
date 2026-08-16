import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/config/app_config.dart';
import '../data/lab_request_repository.dart';

class LabRequestFormScreen extends ConsumerStatefulWidget {
  const LabRequestFormScreen({super.key});

  @override
  ConsumerState<LabRequestFormScreen> createState() =>
      _LabRequestFormScreenState();
}

class _LabRequestFormScreenState extends ConsumerState<LabRequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _lotIdController = TextEditingController();
  final _sampleQtyController = TextEditingController(text: '500');
  final _notesController = TextEditingController();
  String _selectedTestType = 'Germination & Vigor';
  bool _isSubmitting = false;

  static const testTypes = [
    'Germination & Vigor',
    'Physical Purity (PP)',
    'Moisture Content (MC)',
    'Grow Out Test (GOT)',
    'Field Emergence Test (FET)',
  ];

  @override
  void dispose() {
    _lotIdController.dispose();
    _sampleQtyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final repository = ref.read(labRequestRepositoryProvider);
      await repository.createLabRequest(
        lotIdRaw: _lotIdController.text.trim(),
        testType: _selectedTestType,
        sampleQtyGrams: double.tryParse(_sampleQtyController.text) ?? 500,
        notes: _notesController.text.trim(),
      );

      // ignore: unused_result
      ref.refresh(labRequestsProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Request sampel lab berhasil dibuat! Status: PREPARED.',
          ),
          backgroundColor: AppColors.success,
        ),
      );

      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat request: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final mutedTextColor = isDark
        ? AppColors.textMutedDark
        : AppColors.textMutedLight;

    return Scaffold(
      appBar: AppBar(title: const Text('Buat Request Sampel Lab')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Form Permintaan Pengujian Sampel Benih',
                    style: AppTextStyles.heading3.copyWith(
                      color: primaryTextColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Isi data pengambilan sampel dari Plant/Kebun ke Laboratorium:',
                    style: AppTextStyles.caption.copyWith(
                      color: mutedTextColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _lotIdController,
              decoration: const InputDecoration(
                labelText: 'Lot ID Raw / Batch ID *',
                prefixIcon: Icon(Icons.qr_code),
                hintText: 'Misal: PPR5D2007',
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Lot ID wajib diisi';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _selectedTestType,
              decoration: const InputDecoration(
                labelText: 'Jenis Pengujian Lab *',
                prefixIcon: Icon(Icons.science),
              ),
              items: testTypes.map((type) {
                return DropdownMenuItem(value: type, child: Text(type));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedTestType = val);
                }
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _sampleQtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Jumlah Berat Sampel (Gram) *',
                prefixIcon: Icon(Icons.scale),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Berat sampel wajib diisi';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Catatan Pengiriman / Lokasi BIN',
                prefixIcon: Icon(Icons.notes),
                hintText: 'Misal: Sampel BIN 04, dikirim via kurir internal',
              ),
            ),
            const SizedBox(height: 28),

            ElevatedButton(
              onPressed: AppConfig.operationalWritesEnabled && !_isSubmitting
                  ? _submit
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
                  : const Text(
                      AppConfig.operationalWritesEnabled
                          ? 'Kirim Request Sampel Lab'
                          : 'Mode read-only aktif',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
