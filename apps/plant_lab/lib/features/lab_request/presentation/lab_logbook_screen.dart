import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/database/supabase_client.dart';
import 'lab_logbook_download.dart';

const logbookStatuses = <String, String>{
  'DRAFT': 'Draft',
  'WAITING_TEST': 'Belum mulai uji',
  'ASSIGNED': 'Ditugaskan',
  'IN_PROGRESS': 'Sedang diuji',
  'SUBMITTED': 'Dikirim untuk diperiksa',
  'IN_REVIEW': 'Menunggu QA',
  'APPROVED': 'Analisis disetujui QA',
  'RETEST': 'Perlu uji ulang',
  'REJECTED': 'Ditolak QA',
  'CANCELLED': 'Dibatalkan',
  'APPROVAL_INCOMPLETE': 'Perlu pemeriksaan bukti QA',
  'VERIFIED_RECORD': 'Catatan MC diverifikasi QA',
  'RETURNED': 'Catatan MC dikembalikan',
};
const logbookOrigins = <String, String>{
  'PLANT_RUN': 'Permintaan Plant',
  'PLANT_PENDING': 'Permintaan Plant · belum mulai',
  'ROUTINE': 'Uji rutin Lab',
  'MC_DRAFT': 'MC Lab',
};
Map<String, dynamic> emptyLogbookFilters() => {
  'p_lab_site_id': null,
  'p_search': '',
  'p_from': null,
  'p_to': null,
  'p_date_basis': 'RECORDED',
  'p_origin': 'ALL',
  'p_method': 'ALL',
  'p_status': 'ALL',
};
String logbookWib(dynamic value) {
  final t = DateTime.tryParse(value?.toString() ?? '');
  if (t == null) return 'Belum dicatat';
  final w = t.toUtc().add(const Duration(hours: 7));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${w.year}-${two(w.month)}-${two(w.day)} ${two(w.hour)}:${two(w.minute)} WIB';
}

String logbookResult(Map<String, dynamic> row) {
  final value = row['result_percent'];
  if (value == null) return 'Angka hasil belum tersedia';
  final label = ['DRAFT_MEAN', 'MC_RECORD_MEAN'].contains(row['result_state'])
      ? 'Rata-rata 3 pembacaan MC'
      : 'Hasil analisis';
  final number = (value as num)
      .toStringAsFixed(6)
      .replaceFirst(RegExp(r'\.?0+$'), '')
      .replaceAll('.', ',');
  return '$label: $number%';
}

typedef LogbookLoader =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> args);

class LabLogbookScreen extends StatefulWidget {
  const LabLogbookScreen({
    super.key,
    this.loadRecords,
    this.download = fetchLogbookExport,
    this.share = shareLogbookExport,
  });
  final LogbookLoader? loadRecords;
  final LogbookExporter download;
  final LogbookSharer share;
  @override
  State<LabLogbookScreen> createState() => _LabLogbookScreenState();
}

class _LabLogbookScreenState extends State<LabLogbookScreen> {
  Map<String, dynamic> filters = emptyLogbookFilters();
  Map<String, dynamic> applied = emptyLogbookFilters();
  Map<String, dynamic> last = emptyLogbookFilters();
  Map<String, dynamic>? page, catalog;
  final search = TextEditingController();
  bool busy = false, changed = false;
  bool exporting = false;
  bool get working => busy || exporting;
  String? exportError;
  String? error;
  int lastOffset = 0;
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

  Future<void> load(Map<String, dynamic> selected, [int offset = 0]) async {
    if (working) return;
    final from = selected['p_from'] as String?,
        to = selected['p_to'] as String?;
    if (from != null && to != null && from.compareTo(to) > 0) {
      setState(
        () => error = 'Tanggal awal tidak boleh melebihi tanggal akhir.',
      );
      return;
    }
    last = Map.of(selected);
    lastOffset = offset;
    setState(() {
      busy = true;
      error = null;
      exportError = null;
      page = null;
    });
    try {
      final args = {
        ...selected,
        'p_search': (selected['p_search'] as String).trim(),
        'p_offset': offset,
        'p_limit': 50,
      };
      final data =
          await (widget.loadRecords?.call(args) ??
              supabase
                  .schema(AppConfig.isolatedApiSchema)
                  .rpc<Map<String, dynamic>>('get_lab_logbook', params: args));
      if (!mounted) return;
      setState(() {
        page = data;
        catalog = data;
        applied = {...selected, 'p_lab_site_id': data['selected_lab_site_id']};
        filters['p_lab_site_id'] = data['selected_lab_site_id'];
        changed = filters.toString() != applied.toString();
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Catatan belum dimuat. Periksa koneksi dan penugasan Lab, lalu coba lagi. Data lama tidak ditampilkan sebagai hasil filter baru.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void patch(String key, dynamic value) => setState(() {
    filters[key] = value;
    changed = true;
  });
  Future<void> download() async {
    if (working || changed || page == null) return;
    setState(() {
      exporting = true;
      exportError = null;
    });
    try {
      final file = await widget.download(Map.of(applied));
      if (mounted) await widget.share(file);
    } catch (e) {
      if (mounted) {
        setState(
          () => exportError = e is StateError
              ? e.message.toString()
              : e is FormatException
              ? e.message
              : 'Unduhan belum berhasil. Periksa koneksi lalu coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  Widget select(String label, String key, Map<String, String> options) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: DropdownButtonFormField<String>(
          key: ValueKey('$key:${filters[key]}:${options.keys.join()}'),
          initialValue: filters[key] as String?,
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
          onChanged: working
              ? null
              : (v) {
                  if (v != null) patch(key, v);
                },
        ),
      );
  Widget date(String label, String key) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: working
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
                onPressed: working ? null : () => patch(key, null),
                child: const Text('Hapus tanggal'),
              ),
          ],
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Buku pengujian Lab')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Baca saja. Satu catatan berarti satu percobaan uji, draft, atau item permintaan yang belum mulai. Uji ulang tetap terpisah; bukan jumlah lot, benih, atau permintaan. Histori Excel tetap terpisah. Analisis disetujui QA bukan pelepasan lot.',
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (catalog != null)
          select('Lab', 'p_lab_site_id', {
            for (final s in catalog!['lab_sites'] as List)
              s['id'] as String: s['site_name'] as String,
          }),
        TextField(
          controller: search,
          maxLength: 120,
          enabled: !working,
          decoration: const InputDecoration(
            labelText: 'Cari lot, hybrid, label, nomor uji',
          ),
          onChanged: (v) => patch('p_search', v),
          onSubmitted: (_) => load(filters),
        ),
        const SizedBox(height: 16),
        select('Dasar tanggal', 'p_date_basis', {
          'RECORDED': 'Pertama dicatat di aplikasi',
          'OBSERVED': 'Pengamatan final / ukur MC aktual',
        }),
        date('Dari tanggal (WIB)', 'p_from'),
        date('Sampai tanggal (WIB)', 'p_to'),
        const Text(
          'Batas tanggal termasuk hari awal dan akhir. Jika memakai tanggal pengamatan, catatan tanpa waktu pengamatan tidak masuk rentang tanggal.',
        ),
        const SizedBox(height: 16),
        select('Asal catatan', 'p_origin', {
          'ALL': 'Semua asal',
          'PLANT': 'Permintaan Plant',
          'ROUTINE': 'Uji rutin Lab',
          'MC': 'MC Lab',
        }),
        select('Metode', 'p_method', {
          'ALL': 'Semua metode',
          for (final m in (catalog?['method_options'] as List? ?? []))
            m['method_code'] as String: m['method_name'] as String,
        }),
        select('Status', 'p_status', {
          'ALL': 'Semua status',
          ...logbookStatuses,
        }),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: working ? null : () => load(filters),
              child: const Text('Tampilkan catatan'),
            ),
            OutlinedButton(
              onPressed: working
                  ? null
                  : () {
                      setState(() {
                        final site = filters['p_lab_site_id'];
                        filters = emptyLogbookFilters()
                          ..['p_lab_site_id'] = site;
                        search.clear();
                      });
                      load(filters);
                    },
              child: const Text('Hapus filter'),
            ),
          ],
        ),
        if (changed && page != null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Filter berubah. Tekan Tampilkan catatan; hasil di bawah masih memakai filter sebelumnya.',
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                TextButton(
                  onPressed: working ? null : () => load(last, lastOffset),
                  child: const Text('Coba muat ulang'),
                ),
              ],
            ),
          ),
        if (busy)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (page != null) ...[
          const SizedBox(height: 24),
          Text(
            '${page!['total']} catatan cocok',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Ringkasan seluruh hasil filter, bukan hanya halaman ini.',
          ),
          Text('Dimuat ${logbookWib(page!['as_of'])}'),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: working || changed || (page!['total'] as int) > 2000
                  ? null
                  : download,
              icon: const Icon(Icons.download),
              label: const Text('Unduh rekap Excel'),
            ),
          ),
          const Text(
            'Seluruh catatan sesuai filter diterapkan, bukan hanya 50 pada halaman ini. Maksimal 2000 catatan; persempit filter jika lebih. Data terbaru diambil saat diunduh, waktunya dicatat pada file. Ini rekap, bukan gabungan form pengujian.',
          ),
          if (changed)
            const Text('Terapkan perubahan filter dahulu sebelum mengunduh.'),
          if ((page!['total'] as int) > 2000)
            const Text(
              'Lebih dari 2000 catatan cocok. Persempit tanggal atau filter agar rekap tidak terpotong.',
            ),
          if (exporting) const Text('Menyiapkan rekap Excel…'),
          if (exportError != null)
            Text(
              exportError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in <String, String>{
                    'approved': 'Analisis disetujui QA',
                    'draft': 'Draft',
                    'waiting_qa': 'Menunggu QA',
                    'retest': 'Perlu uji ulang',
                    'other': 'Status lainnya',
                  }.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('${page!['summary'][e.key]} · ${e.value}'),
                    ),
                  Text(
                    '${page!['summary']['missing_observation_time']} catatan belum punya waktu pengamatan final / ukur MC.',
                  ),
                ],
              ),
            ),
          ),
          if ((page!['entries'] as List).isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Tidak ada catatan yang cocok. Periksa lot, tanggal, dan filter; jangan memilih lot lain sebagai pengganti.',
              ),
            ),
          for (final row in page!['entries'] as List)
            LogbookEntryCard(row: Map<String, dynamic>.from(row)),
          Text(
            '${page!['total'] == 0 ? 0 : (page!['offset'] as int) + 1}–${(page!['offset'] as int) + (page!['entries'] as List).length} dari ${page!['total']} catatan',
          ),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: working || page!['offset'] == 0
                    ? null
                    : () => load(
                        applied,
                        (page!['offset'] as int) - (page!['limit'] as int),
                      ),
                child: const Text('Sebelumnya'),
              ),
              OutlinedButton(
                onPressed: working || page!['has_more'] != true
                    ? null
                    : () => load(
                        applied,
                        (page!['offset'] as int) + (page!['limit'] as int),
                      ),
                child: const Text('Berikutnya'),
              ),
              TextButton(
                onPressed: working
                    ? null
                    : () => load(applied, page!['offset'] as int),
                child: const Text('Muat ulang hasil'),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ],
    ),
  );
}

class LogbookEntryCard extends StatelessWidget {
  const LogbookEntryCard({super.key, required this.row});
  final Map<String, dynamic> row;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            logbookOrigins[row['entry_kind']] ?? row['entry_kind'].toString(),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          Text(
            row['lot_code'] as String,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text('${row['hybrid']} · ${row['stage_code']}'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              logbookStatuses[row['status']] ?? row['status'].toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Text(row['method_name'] as String),
          Text('Label sampel: ${row['sample_reference'] ?? 'Belum dicatat'}'),
          Text('Permintaan: ${row['request_code'] ?? 'Tidak ada'}'),
          Text('Nomor uji: ${row['run_code'] ?? 'Belum ada'}'),
          if (row['attempt_no'] != null)
            Text('Percobaan ke-${row['attempt_no']}'),
          if (row['revision'] != null) Text('Revisi ${row['revision']}'),
          const Divider(),
          Text('Pertama dicatat: ${logbookWib(row['recorded_at'])}'),
          Text('Pengamatan final / ukur MC: ${logbookWib(row['observed_at'])}'),
          Text('Pemeriksaan QA terakhir: ${logbookWib(row['reviewed_at'])}'),
          const SizedBox(height: 12),
          Text(
            logbookResult(row),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            row['result_state'] == 'QA_APPROVED'
                ? 'Analisis disetujui QA; bukan pelepasan lot.'
                : row['result_state'] == 'DRAFT_MEAN'
                ? 'Masih draft MC. Belum ada penilaian lulus/gagal.'
                : row['result_state'] == 'MC_RECORD_MEAN'
                ? 'QA hanya memeriksa catatan MC. Tidak menilai lulus/gagal dan bukan pelepasan lot.'
                : 'Belum menjadi analisis yang disetujui QA.',
          ),
        ],
      ),
    ),
  );
}
