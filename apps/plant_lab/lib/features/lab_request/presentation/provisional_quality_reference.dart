import 'package:flutter/material.dart';

bool validQualityReferences(List<Map<String, dynamic>?> rules) {
  final scoped = rules.length == 8;
  final expected = {
    for (final programme in scoped ? ['COMMERCIAL', 'PARENT_SEED'] : [''])
      for (final crop in ['FC', 'SWC'])
        for (final test in ['GERMINATION', 'VIGOUR']) '$programme:$crop:$test',
  };
  return (scoped || rules.length == 4) &&
      rules.every(
        (rule) =>
            rule != null &&
            expected.remove(
              '${scoped ? rule['programme_code'] : ''}:${rule['crop_category_code']}:${rule['test_code']}',
            ) &&
            (scoped
                ? rule['validation_status'] == 'PENDING_CONTROLLED_SOP' &&
                      rule['business_confirmation_status'] == 'USER_CONFIRMED'
                : [
                    'PENDING_RESKI',
                    'USER_CONFIRMED',
                  ].contains(rule['validation_status'])) &&
            rule['minimum_percent'] is num &&
            (rule['minimum_percent'] as num).isFinite &&
            (rule['minimum_percent'] as num) >= 0 &&
            (rule['minimum_percent'] as num) <= 100,
      ) &&
      expected.isEmpty;
}

String qualityProgrammeLabel(dynamic code) => switch (code) {
  'COMMERCIAL' => 'Komersial',
  'PARENT_SEED' => 'Parent Seed (PS)',
  'UNRESOLVED_EQUAL_LIMITS' =>
    'Programme belum dipastikan; batas Germinasi sama',
  _ => '',
};

String qualityReferenceConfirmation(Map<String, dynamic> rule) =>
    switch (rule['business_confirmation_status'] == 'USER_CONFIRMED'
    ? 'USER_CONFIRMED'
    : rule['validation_status']) {
      'USER_CONFIRMED' => 'Angka dikonfirmasi tim',
      'PENDING_RESKI' => 'Menunggu validasi Reski',
      _ => 'Status konfirmasi mengikuti snapshot sumber',
    };

List<Map<String, dynamic>> filterReferenceLots(
  List<Map<String, dynamic>> lots,
  String query,
  String? selectedId,
) {
  final key = query.trim().toUpperCase();
  return lots
      .where(
        (lot) =>
            lot['id'] == selectedId ||
            '${lot['lot_code']}'.toUpperCase().contains(key),
      )
      .toList();
}

class ProvisionalQualityReference extends StatelessWidget {
  const ProvisionalQualityReference({
    super.key,
    required this.rules,
    this.methods = const [],
    this.vigourEnabled = false,
    this.retEnabled = false,
  });
  final List<Map<String, dynamic>> rules;
  final List<Map<String, dynamic>> methods;
  final bool vigourEnabled;
  final bool retEnabled;

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      title: const Text('Acuan mutu sementara FC / Sweet Corn'),
      subtitle: Text(
        rules.every(
              (r) => r['business_confirmation_status'] == 'USER_CONFIRMED',
            )
            ? 'Angka dikonfirmasi tim'
            : 'Menunggu validasi Reski',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final rule in rules)
          Text(
            '${qualityProgrammeLabel(rule['programme_code'])} · ${rule['crop_category_code']} · ${rule['test_code'] == 'GERMINATION' ? 'Germinasi' : 'Vigor'} ≥${rule['minimum_percent']}% · versi ${rule['version']}',
          ),
        const SizedBox(height: 12),
        const Text('Ketentuan input pengujian baru · 11 November 2026'),
        for (final method in methods)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${method['method_name']}: ${method['replicate_count']} × ${method['seeds_per_replicate']} benih'
              '${method['method_code'] == 'RET_16C_72H' ? ' · radikula ≥${method['minimum_radicle_mm']} mm · ${method['duration_days']} hari' : ''}',
            ),
          ),
        const SizedBox(height: 12),
        const Text(
          'Germinasi baru: normal + abnormal + mati = 100 benih per ulangan, 2 ulangan. Hasil approved lama tidak dihitung ulang. Programme lot yang belum pasti tidak diberi batas Vigor otomatis.',
        ),
        const SizedBox(height: 12),
        const Text(
          'Plant Officer membuat kode lot saat pertama masuk BIN berdasarkan product spec QA. Format resmi belum tersedia; kode tidak dibuat otomatis.',
        ),
        const SizedBox(height: 12),
        Text(
          vigourEnabled
              ? 'Soak/Cold Test, AAT, SCT dan AAT Extend aktif: 2×100; pembulatan dan toleransi mengikuti Excel. ${retEnabled ? 'RET aktif: radikula ≥2 mm, 4×100, minimal 72 jam sejak penempatan pada 16°C, toleransi 4 Reps.' : 'RET belum tersedia pada klien ini.'} Persetujuan hasil bukan izin pelepasan lot atau sertifikasi protokol otomatis.'
              : 'Acuan bisnis dikonfirmasi, belum menggantikan SOP/spesifikasi produk terkendali atau izin pelepasan lot. Form hasil Vigor belum aktif; perhitungan selain RET masih dicocokkan dengan Excel.',
        ),
      ],
    ),
  );
}

class ProvisionalResultSnapshot extends StatelessWidget {
  const ProvisionalResultSnapshot({super.key, required this.snapshot});
  final Map<String, dynamic>? snapshot;

  @override
  Widget build(BuildContext context) {
    final value = snapshot;
    if (value == null) {
      return const Text(
        'Evaluasi terhadap acuan mutu belum tersedia pada hasil ini. Jangan menyimpulkan lulus spesifikasi dari status approval saja. Hasil lama tidak dievaluasi ulang.',
      );
    }
    final assessment = switch (value['assessment']) {
      'MEETS_PROVISIONAL_REFERENCE' => 'Memenuhi acuan sementara',
      'BELOW_PROVISIONAL_REFERENCE' => 'Di bawah acuan sementara',
      _ => 'Evaluasi sementara belum tersedia',
    };
    return Text(
      '$assessment · minimum ${value['minimum_percent']}% · versi ${value['version']}. ${qualityProgrammeLabel(value['programme_code'])} ${qualityReferenceConfirmation(value)}; bukan izin pelepasan lot.',
    );
  }
}
