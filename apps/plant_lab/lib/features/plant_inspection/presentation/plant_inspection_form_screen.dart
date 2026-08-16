import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:plant_lab/core/config/app_config.dart';

class PlantInspectionFormScreen extends ConsumerStatefulWidget {
  final String planId;
  final String? stepId;

  const PlantInspectionFormScreen({
    super.key,
    required this.planId,
    this.stepId,
  });

  @override
  ConsumerState<PlantInspectionFormScreen> createState() =>
      _PlantInspectionFormScreenState();
}

class _PlantInspectionFormScreenState
    extends ConsumerState<PlantInspectionFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Dynamic form fields for Plant Inspection
  double _moistureContent = 12.5;
  double _temperature = 28.0;
  String _visualQuality = 'GOOD';
  bool _isOos = false;
  bool _isSubmitting = false;

  final List<XFile> _capturedImages = [];

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (photo != null) {
        setState(() {
          _capturedImages.add(photo);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengambil foto: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _evalOos() {
    // Standard rule: MC > 14.0% is OOS for seed moisture
    setState(() {
      _isOos = _moistureContent > 14.0 || _visualQuality == 'POOR';
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isSubmitting = true);

    try {
      // Simulate/perform inspection submission
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isOos
                  ? 'Inspeksi tersimpan dengan status OUT OF SPEC (OOS)'
                  : 'Inspeksi berhasil dikirim!',
            ),
            backgroundColor: _isOos
                ? const Color(0xFFF59E0B)
                : const Color(0xFF22C55E),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim inspeksi: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F0A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF86EFAC)),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Form Inspeksi Plant',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Color(0xFFF0FDF4),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: AppConfig.operationalWritesEnabled && !_isSubmitting
                ? _handleSubmit
                : null,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF22C55E),
                    ),
                  )
                : const Icon(Icons.check, color: Color(0xFF22C55E), size: 20),
            label: Text(
              _isSubmitting
                  ? 'Kirim...'
                  : (AppConfig.operationalWritesEnabled
                        ? 'Simpan'
                        : 'Read-only'),
              style: const TextStyle(
                color: Color(0xFF22C55E),
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // OOS Warning Banner if triggered
            if (_isOos)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEF4444)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Parameter melebihi toleransi standar (Out of Spec). Perlu QA Review.',
                        style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Section 1: Measurement Data
            _buildSectionHeader('1. Pengukuran Parameter Field/Plant'),
            const SizedBox(height: 12),
            _buildCard([
              // Moisture Content
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Kadar Air (MC %)',
                    style: TextStyle(
                      color: Color(0xFFF0FDF4),
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${_moistureContent.toStringAsFixed(1)} %',
                    style: TextStyle(
                      color: _moistureContent > 14.0
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF22C55E),
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _moistureContent,
                min: 8.0,
                max: 20.0,
                divisions: 120,
                activeColor: _moistureContent > 14.0
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF22C55E),
                inactiveColor: const Color(0xFF1F4A30),
                onChanged: (val) {
                  setState(() => _moistureContent = val);
                  _evalOos();
                },
              ),
              const Divider(color: Color(0xFF1F4A30)),
              const SizedBox(height: 8),

              // Temperature
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Suhu (°C)',
                    style: TextStyle(
                      color: Color(0xFFF0FDF4),
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${_temperature.toStringAsFixed(1)} °C',
                    style: const TextStyle(
                      color: Color(0xFF86EFAC),
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _temperature,
                min: 15.0,
                max: 45.0,
                divisions: 60,
                activeColor: const Color(0xFF16A34A),
                inactiveColor: const Color(0xFF1F4A30),
                onChanged: (val) {
                  setState(() => _temperature = val);
                },
              ),
            ]),

            const SizedBox(height: 20),

            // Section 2: Visual Quality
            _buildSectionHeader('2. Kualitas Visual & Kebersihan'),
            const SizedBox(height: 12),
            _buildCard([
              const Text(
                'Kondisi Benih / Lot',
                style: TextStyle(
                  color: Color(0xFFF0FDF4),
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children:
                    [
                      ('EXCELLENT', 'Sangat Baik', const Color(0xFF22C55E)),
                      ('GOOD', 'Baik', const Color(0xFF16A34A)),
                      ('FAIR', 'Cukup', const Color(0xFFF59E0B)),
                      ('POOR', 'Buruk (OOS)', const Color(0xFFEF4444)),
                    ].map((item) {
                      final selected = _visualQuality == item.$1;
                      return ChoiceChip(
                        label: Text(
                          item.$2,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : const Color(0xFF4B7A5F),
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        selected: selected,
                        selectedColor: item.$3,
                        backgroundColor: const Color(0xFF162019),
                        onSelected: (val) {
                          if (val) {
                            setState(() => _visualQuality = item.$1);
                            _evalOos();
                          }
                        },
                      );
                    }).toList(),
              ),
            ]),

            const SizedBox(height: 20),

            // Section 3: Evidence Attachments
            _buildSectionHeader('3. Foto Evidence (Wajib Min 1)'),
            const SizedBox(height: 12),
            _buildCard([
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt, size: 16),
                    label: const Text(
                      'Kamera',
                      style: TextStyle(fontFamily: 'Inter'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library, size: 16),
                    label: const Text(
                      'Galeri',
                      style: TextStyle(fontFamily: 'Inter'),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF86EFAC),
                      side: const BorderSide(color: Color(0xFF1F4A30)),
                    ),
                  ),
                ],
              ),
              if (_capturedImages.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _capturedImages.length,
                    itemBuilder: (ctx, i) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1F4A30),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF22C55E),
                                ),
                              ),
                              child: const Icon(
                                Icons.image,
                                color: Color(0xFF86EFAC),
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _capturedImages.removeAt(i);
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Color(0xB3000000),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ]),

            const SizedBox(height: 20),

            // Section 4: Notes
            _buildSectionHeader('4. Catatan Tambahan'),
            const SizedBox(height: 12),
            _buildCard([
              TextFormField(
                maxLines: 3,
                style: const TextStyle(
                  color: Color(0xFFF0FDF4),
                  fontFamily: 'Inter',
                  fontSize: 13,
                ),
                decoration: const InputDecoration(
                  hintText: 'Tuliskan catatan inspeksi atau temuan khusus...',
                  hintStyle: TextStyle(color: Color(0xFF4B7A5F)),
                  border: InputBorder.none,
                ),
                onChanged: (val) {}, // Notes ignored in this dummy form
              ),
            ]),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF86EFAC),
        fontFamily: 'Inter',
        fontWeight: FontWeight.w700,
        fontSize: 14,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF162019),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1F4A30)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
