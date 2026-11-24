import 'dart:math' as math;
import 'package:flutter/material.dart';

Map<String, dynamic> previewTsw(List<num?> w) {
  final n = w.where((x) => x != null).length;
  final empty = <String, dynamic>{
    'weights_g': w,
    'entered_count': n,
    'mean_100_g': null,
    'cv_percent': null,
    'tsw_g': null,
    'kernel_per_kg': null,
  };
  if (w.length != 8 ||
      n != 8 ||
      w.any((x) => x == null || !x.isFinite || x < 0 || x > 100000)) {
    return {...empty, 'calculation_state': 'INCOMPLETE'};
  }
  final a = w.cast<num>(),
      mean = a.reduce((x, y) => x + y) / 8,
      variance = a.fold<double>(0, (s, x) => s + math.pow(x - mean, 2)) / 8;
  if (mean <= 0) {
    return {...empty, 'mean_100_g': mean, 'calculation_state': 'ZERO_MEAN'};
  }
  final cv = math.sqrt(variance) / mean * 100,
      within = variance <= mean * mean * .0016 + mean * mean * 1e-14;
  return {
    ...empty,
    'mean_100_g': mean,
    'cv_percent': cv,
    'tsw_g': within ? mean * 10 : null,
    'kernel_per_kg': within ? 100000 / mean : null,
    'calculation_state': within
        ? 'WITHIN_WORKBOOK_REFERENCE'
        : 'RECOUNT_WORKBOOK_REFERENCE',
  };
}

String tswNumber(dynamic v) => v == null
    ? 'Belum tersedia'
    : (v as num)
          .toStringAsFixed(6)
          .replaceFirst(RegExp(r'\.?0+$'), '')
          .replaceAll('.', ',');
String tswState(dynamic s) =>
    <String, String>{
      'INCOMPLETE': 'Lengkapi 8 timbangan',
      'ZERO_MEAN': 'Periksa bacaan nol',
      'WITHIN_WORKBOOK_REFERENCE': 'CV dalam acuan file (maksimal 4%)',
      'RECOUNT_WORKBOOK_REFERENCE':
          'Perlu hitung/timbang ulang menurut acuan file (CV >4%)',
    }[s] ??
    s.toString();

class TswWeightInputs extends StatelessWidget {
  const TswWeightInputs({
    super.key,
    required this.controllers,
    required this.enabled,
    required this.onChanged,
  });
  final List<TextEditingController> controllers;
  final bool enabled;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Timbangan 8× 100 benih',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      const Text(
        'Isi berat per 100 benih dalam gram, bukan hasil TSW. Kosong berarti belum dicatat. Nol tetap nol dan perlu diperiksa.',
      ),
      for (var i = 0; i < 8; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: TextField(
            controller: controllers[i],
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Ulangan ${i + 1} · berat 100 benih (g)',
            ),
            onChanged: (_) => onChanged(),
          ),
        ),
      TswWeightSummary(
        raw: previewTsw(
          controllers
              .map(
                (c) =>
                    c.text.trim().isEmpty ? null : num.tryParse(c.text.trim()),
              )
              .toList(),
        ),
        preview: true,
      ),
    ],
  );
}

class TswWeightSummary extends StatelessWidget {
  const TswWeightSummary({super.key, required this.raw, this.preview = false});
  final Map<String, dynamic> raw;
  final bool preview;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            preview
                ? 'Pratinjau; hasil simpan dihitung ulang server'
                : 'Rincian TSW tersimpan',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '8 ulangan × 100 benih = 800 benih ditimbang. Hasil dikonversi per 1.000 benih, bukan menimbang 1.000 benih langsung.',
          ),
          Text(
            '${raw['entered_count']}/8 timbangan · ${tswState(raw['calculation_state'])}',
          ),
          Text('Rata-rata 100 benih: ${tswNumber(raw['mean_100_g'])} g'),
          Text('CV: ${tswNumber(raw['cv_percent'])}%'),
          Text('TSW: ${tswNumber(raw['tsw_g'])} g per 1.000 benih'),
          Text('Kernel/kg (hasil hitung): ${tswNumber(raw['kernel_per_kg'])}'),
          if (!preview)
            Text(
              'Berat per 100 benih (g): ${(raw['weights_g'] as List).map((x) => x == null ? 'belum dicatat' : tswNumber(x)).join(' / ')}',
            ),
          const SizedBox(height: 8),
          const Text(
            'Variance populasi dibagi 8, sesuai file acuan. Batas CV 4% adalah acuan hitung file; bukan spesifikasi mutu baru, approval Lab, atau pelepasan lot.',
          ),
        ],
      ),
    ),
  );
}
