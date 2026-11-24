import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/database/supabase_client.dart';
import 'lab_logbook_screen.dart';
import 'moisture_lab_screen.dart';
import 'routine_lab_screen.dart';

const monitoringGroups = <String, String>{
  'ALL': 'Semua pekerjaan',
  'ACTIVE': 'Pekerjaan yang belum selesai',
  'WAITING_SAMPLE': 'Menunggu sampel',
  'WAITING_TEST': 'Belum mulai uji',
  'TESTING': 'Sedang dikerjakan',
  'WAITING_QA': 'Menunggu QA',
  'RETEST': 'Perlu uji ulang',
  'RETURNED': 'Catatan dikembalikan',
  'COMPLETED': 'Selesai diperiksa',
  'HISTORY': 'Riwayat uji ulang',
  'CLOSED': 'Ditutup / dibatalkan',
  'INCOMPLETE': 'Catatan belum lengkap',
};
Map<String, dynamic> emptyMonitoringFilters() => {
  'p_lab_site_id': null,
  'p_search': '',
  'p_from': null,
  'p_to': null,
  'p_date_basis': 'RECORDED',
  'p_origin': 'ALL',
  'p_method': 'ALL',
  'p_work_group': 'ALL',
};
String monitoringHours(dynamic value) {
  if (value == null) return 'Belum dapat dihitung';
  String number(num n) => n
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'\.?0+$'), '')
      .replaceAll('.', ',');
  final h = value as num;
  return h >= 24
      ? '${number(h / 24)} hari (${number(h)} jam)'
      : '${number(h)} jam';
}

Map<String, dynamic> validateMonitoringPage(Map<String, dynamic> p) {
  if (p['version'] != 1 ||
      p['read_only'] != true ||
      p['sla_applied'] != false ||
      p['authorizes_lot_release'] != false ||
      p['grain'] != 'ONE_TEST_ATTEMPT_OR_UNSTARTED_ITEM_OR_DRAFT' ||
      p['summary'] is! Map ||
      p['summary']['total'] != p['total'] ||
      p['entries'] is! List ||
      p['lab_sites'] is! List ||
      p['method_options'] is! List ||
      DateTime.tryParse('${p['as_of']}') == null) {
    throw const FormatException('Sumber pemantauan tidak sesuai.');
  }
  final s = Map<String, dynamic>.from(p['summary'] as Map);
  for (final key in [
    'total',
    'active',
    'waiting_sample',
    'waiting_test',
    'testing',
    'waiting_qa',
    'retest',
    'returned',
    'incomplete',
    'approved_analysis',
    'verified_mc',
    'missing_sample_time',
    'missing_qa_time',
    'clock_issues',
    'analytical_decisions',
    'retest_decisions',
    'sample_tat_count',
    'qa_tat_count',
    'mc_qa_count',
  ]) {
    if (s[key] is! int || (s[key] as int) < 0) {
      throw const FormatException('Jumlah pekerjaan tidak sesuai.');
    }
  }
  for (final pair in [
    ['sample_tat_count', 'sample_tat_hours'],
    ['qa_tat_count', 'qa_tat_hours'],
    ['mc_qa_count', 'mc_qa_hours'],
  ]) {
    final value = s[pair[1]];
    if (s[pair[0]] == 0
        ? value != null
        : value is! num || !value.isFinite || value < 0) {
      throw const FormatException('Rata-rata waktu tidak sesuai.');
    }
  }
  final rate = s['retest_rate_percent'];
  if (s['active'] > s['total'] ||
      s['retest_decisions'] > s['analytical_decisions'] ||
      (s['analytical_decisions'] == 0
          ? rate != null
          : rate is! num ||
                !rate.isFinite ||
                (rate - s['retest_decisions'] * 100 / s['analytical_decisions'])
                        .abs() >
                    .011)) {
    throw const FormatException('Perhitungan uji ulang tidak sesuai.');
  }
  for (final e in p['entries'] as List) {
    if (!monitoringGroups.containsKey(e['work_group'])) {
      throw const FormatException('Kelompok pekerjaan tidak sesuai.');
    }
    for (final key in [
      'open_sample_hours',
      'waiting_qa_hours',
      'retest_wait_hours',
      'sample_to_submit_hours',
      'qa_tat_hours',
    ]) {
      final v = e[key];
      if (v != null && (v is! num || !v.isFinite || v < 0)) {
        throw const FormatException('Waktu pemantauan tidak sesuai.');
      }
    }
  }
  return p;
}

typedef MonitoringLoader =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> args);

class LabMonitoringScreen extends StatefulWidget {
  const LabMonitoringScreen({super.key, this.loadRecords});
  final MonitoringLoader? loadRecords;
  @override
  State<LabMonitoringScreen> createState() => _LabMonitoringScreenState();
}

class _LabMonitoringScreenState extends State<LabMonitoringScreen> {
  Map<String, dynamic> filters = emptyMonitoringFilters(),
      applied = emptyMonitoringFilters(),
      last = emptyMonitoringFilters();
  Map<String, dynamic>? page, catalog;
  final search = TextEditingController();
  bool busy = false;
  int lastOffset = 0;
  String? error;
  bool get changed => jsonEncode(filters) != jsonEncode(applied);
  @override
  void initState() {
    super.initState();
    load(filters);
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void patch(String key, dynamic value) => setState(() => filters[key] = value);
  Future<void> load(Map<String, dynamic> selected, [int offset = 0]) async {
    if (busy) return;
    final from = selected['p_from'] as String?,
        to = selected['p_to'] as String?;
    if (from != null && to != null && from.compareTo(to) > 0) {
      setState(
        () => error = 'Tanggal awal tidak boleh melebihi tanggal akhir.',
      );
      return;
    }
    final snapshot = Map<String, dynamic>.from(selected);
    last = Map.of(snapshot);
    lastOffset = offset;
    setState(() {
      busy = true;
      error = null;
      page = null;
    });
    try {
      final args = {
        ...snapshot,
        'p_search': (snapshot['p_search'] as String).trim(),
        'p_offset': offset,
        'p_limit': 50,
      };
      final p = validateMonitoringPage(
        await (widget.loadRecords?.call(args) ??
            supabase
                .schema(AppConfig.isolatedApiSchema)
                .rpc<Map<String, dynamic>>(
                  'get_lab_work_monitoring',
                  params: args,
                )),
      );
      if (snapshot['p_lab_site_id'] != null &&
          snapshot['p_lab_site_id'] != p['selected_lab_site_id']) {
        throw const FormatException('Lokasi Lab tidak sesuai.');
      }
      if (!mounted) return;
      setState(() {
        page = p;
        catalog = p;
        applied = {...snapshot, 'p_lab_site_id': p['selected_lab_site_id']};
        filters['p_lab_site_id'] = p['selected_lab_site_id'];
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Pemantauan belum dimuat. Periksa koneksi dan penugasan Lab. Hasil lama tidak dipakai untuk filter baru.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget select(String label, String key, Map<String, String> options) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: DropdownButtonFormField<String>(
          initialValue: options.containsKey(filters[key] ?? '')
              ? filters[key] ?? ''
              : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: options.entries
              .map(
                (e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(
                    e.value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: busy
              ? null
              : (v) {
                  if (v != null) patch(key, v.isEmpty ? null : v);
                },
        ),
      );
  Widget date(String label, String key) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            DateTime.tryParse(filters[key] ?? '') ??
                            DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null && mounted) {
                        patch(key, picked.toIso8601String().substring(0, 10));
                      }
                    },
              icon: const Icon(Icons.calendar_month),
              label: Text(filters[key] ?? 'Tanpa batas tanggal'),
            ),
            if (filters[key] != null)
              TextButton(
                onPressed: busy ? null : () => patch(key, null),
                child: const Text('Hapus tanggal'),
              ),
          ],
        ),
      ],
    ),
  );
  Widget metric(String label, dynamic value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Text('$label: $value'),
  );
  Widget row(Map<String, dynamic> e) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(logbookOrigins[e['entry_kind']] ?? '${e['entry_kind']}'),
          Text(
            '${e['lot_code']}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text('${e['hybrid']} · ${e['method_name']}'),
          Text(
            monitoringGroups[e['work_group']]!,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            '${logbookStatuses[e['status']] ?? e['status']}${e['attempt_no'] == null ? '' : ' · Percobaan ${e['attempt_no']}'}',
          ),
          Text(
            [
              e['request_code'],
              e['run_code'],
              e['sample_reference'],
            ].whereType<String>().join(' / '),
          ),
          metric('Sampel diterima / tersedia', logbookWib(e['received_at'])),
          metric('Kirim ke QA', logbookWib(e['submitted_at'])),
          metric('Keputusan QA', logbookWib(e['decision_at'])),
          for (final k in {
            'open_sample_hours': 'Sejak sampel diterima, belum kirim hasil',
            'waiting_qa_hours': 'Sudah menunggu QA',
            'retest_wait_hours': 'Sejak QA meminta uji ulang',
            'sample_to_submit_hours': 'Sampel diterima sampai kirim hasil',
            'qa_tat_hours': 'Kirim hasil sampai keputusan QA',
          }.entries)
            if (e[k.key] != null) metric(k.value, monitoringHours(e[k.key])),
          if (e['receipt_basis'] == 'RECEIPT_EVENT_TIME')
            const Text(
              'Waktu penerimaan mengikuti catatan serah-terima aplikasi, bukan tanggal tanam/pengamatan.',
            ),
          if (e['clock_issue'] == true)
            const Text(
              'Urutan waktu perlu diperiksa pada catatan asal. Tidak diberi waktu tebakan.',
            ),
          OutlinedButton(
            onPressed: () => e['entry_kind'].toString().startsWith('PLANT_')
                ? Navigator.of(context).pop()
                : Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => e['entry_kind'] == 'MC_DRAFT'
                          ? const MoistureLabScreen()
                          : e['entry_kind'] == 'ROUTINE'
                          ? const RoutineLabScreen()
                          : const LabLogbookScreen(),
                    ),
                  ),
            child: const Text('Buka menu catatan asal'),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pemantauan kerja Lab')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Baca saja. Jumlah di sini adalah pekerjaan per percobaan uji, item yang belum mulai, atau draft. Bukan jumlah sampel fisik/lot. Satu sampel bisa dipakai beberapa metode. Histori Excel tidak dicampur. Belum ada batas SLA atau cap terlambat.',
            ),
          ),
        ),
        const SizedBox(height: 16),
        select(
          'Lab',
          'p_lab_site_id',
          catalog == null
              ? {'': 'Lab sesuai penugasan'}
              : {
                  for (final s in catalog!['lab_sites'] as List)
                    s['id'] as String: s['site_name'] as String,
                },
        ),
        TextField(
          controller: search,
          maxLength: 120,
          enabled: !busy,
          decoration: const InputDecoration(
            labelText: 'Cari lot, hybrid, label, nomor uji',
          ),
          onChanged: (v) => patch('p_search', v),
          onSubmitted: (_) => load(filters),
        ),
        select('Asal catatan', 'p_origin', {
          'ALL': 'Semua asal',
          'PLANT': 'Permintaan Plant',
          'ROUTINE': 'Uji rutin Lab',
          'MC': 'MC Lab',
        }),
        select('Metode', 'p_method', {
          'ALL': 'Semua metode',
          for (final m in catalog?['method_options'] as List? ?? [])
            m['method_code'] as String: m['method_name'] as String,
        }),
        select('Kelompok pekerjaan', 'p_work_group', monitoringGroups),
        select('Dasar tanggal', 'p_date_basis', {
          'RECORDED': 'Pertama dicatat di aplikasi',
          'RECEIVED': 'Sampel diterima / tersedia di Lab',
          'REVIEWED': 'Keputusan QA',
        }),
        date('Dari tanggal (WIB)', 'p_from'),
        date('Sampai tanggal (WIB)', 'p_to'),
        const Text(
          'Batas tanggal termasuk hari awal dan akhir. Catatan tanpa tanggal pada dasar yang dipilih tidak masuk rentang tanggal. Pilih Keputusan QA untuk rekap keputusan pada periode tertentu.',
        ),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: busy ? null : () => load(filters),
              child: const Text('Tampilkan pemantauan'),
            ),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () {
                      setState(() {
                        filters = emptyMonitoringFilters()
                          ..['p_lab_site_id'] = filters['p_lab_site_id'];
                        search.clear();
                      });
                      load(filters);
                    },
              child: const Text('Hapus filter'),
            ),
          ],
        ),
        if (changed && page != null)
          const Text(
            'Filter berubah. Tekan Tampilkan pemantauan; hasil di bawah masih memakai pilihan sebelumnya.',
          ),
        if (error != null) ...[
          Text(error!),
          TextButton(
            onPressed: busy ? null : () => load(last, lastOffset),
            child: const Text('Coba muat ulang'),
          ),
        ],
        if (busy) const LinearProgressIndicator(),
        if (page != null) ...[
          const SizedBox(height: 24),
          Text(
            '${page!['total']} pekerjaan cocok',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            'Ringkasan seluruh hasil filter, bukan hanya halaman ini. Dimuat ${logbookWib(page!['as_of'])}. Waktu tidak berjalan otomatis; muat ulang untuk memperbarui.',
          ),
          for (final x in {
            'waiting_sample': 'Menunggu sampel',
            'waiting_test': 'Belum mulai uji',
            'testing': 'Sedang dikerjakan',
            'waiting_qa': 'Menunggu QA',
            'retest': 'Perlu uji ulang',
            'returned': 'Catatan dikembalikan',
            'incomplete': 'Catatan belum lengkap',
            'approved_analysis': 'Analisis disetujui QA',
            'verified_mc': 'Catatan MC diverifikasi',
          }.entries)
            metric(x.value, page!['summary'][x.key]),
          const Divider(),
          const Text('Waktu pengerjaan pada hasil filter'),
          metric(
            'Rata-rata sampel sampai kirim hasil analisis',
            '${monitoringHours(page!['summary']['sample_tat_hours'])} · ${page!['summary']['sample_tat_count']} percobaan dengan waktu lengkap',
          ),
          metric(
            'Rata-rata kirim hasil sampai keputusan QA',
            '${monitoringHours(page!['summary']['qa_tat_hours'])} · ${page!['summary']['qa_tat_count']} percobaan dengan waktu lengkap',
          ),
          metric(
            'Rata-rata pemeriksaan catatan MC oleh QA',
            '${monitoringHours(page!['summary']['mc_qa_hours'])} · ${page!['summary']['mc_qa_count']} catatan dengan waktu lengkap',
          ),
          metric(
            'Keputusan QA yang meminta uji ulang',
            page!['summary']['retest_rate_percent'] == null
                ? 'Belum ada keputusan analisis'
                : '${page!['summary']['retest_decisions']} dari ${page!['summary']['analytical_decisions']} keputusan (${page!['summary']['retest_rate_percent']}%)',
          ),
          const Text(
            'MC tidak dicampur ke rata-rata atau persentase keputusan analisis. Revalidation bukan otomatis uji ulang QA. Riwayat uji ulang yang sudah punya percobaan lanjutan tidak dihitung aktif.',
          ),
          Text(
            '${page!['summary']['missing_sample_time']} catatan belum punya waktu sampel; ${page!['summary']['missing_qa_time']} pekerjaan menunggu QA belum punya waktu kirim; ${page!['summary']['clock_issues']} catatan punya urutan waktu yang perlu diperiksa. Waktu yang belum lengkap tidak diganti nol.',
          ),
          if ((page!['entries'] as List).isEmpty)
            const Text(
              'Tidak ada pekerjaan yang cocok. Periksa filter/tanggal.',
            ),
          for (final e in page!['entries'] as List)
            row(Map<String, dynamic>.from(e as Map)),
          Text(
            page!['total'] == 0
                ? '0 dari 0 pekerjaan'
                : '${page!['offset'] + 1}–${(page!['offset'] as int) + (page!['entries'] as List).length} dari ${page!['total']} pekerjaan',
          ),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: busy || page!['offset'] == 0
                    ? null
                    : () => load(
                        applied,
                        ((page!['offset'] as int) - (page!['limit'] as int))
                            .clamp(0, 100000),
                      ),
                child: const Text('Sebelumnya'),
              ),
              OutlinedButton(
                onPressed: busy || page!['has_more'] != true
                    ? null
                    : () => load(
                        applied,
                        (page!['offset'] as int) + (page!['limit'] as int),
                      ),
                child: const Text('Berikutnya'),
              ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => load(applied, page!['offset'] as int),
                child: const Text('Muat ulang pemantauan'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LabLogbookScreen(),
                  ),
                ),
                child: const Text('Buku pengujian / rekap Excel'),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}
