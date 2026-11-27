import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/database/supabase_client.dart';
import 'lab_logbook_download.dart';
import 'lab_workspace_widgets.dart';
import 'routine_form_download.dart';
import 'workflow_presentation.dart';

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
typedef LogbookFormLoader =
    Future<Uint8List> Function(
      String id,
      int revision,
      String format, {
      required String module,
    });
typedef LogbookFormSharer =
    Future<void> Function(Uint8List bytes, String name, String format);

({String id, int revision, String module, String name})? logbookFormTarget(
  Map<String, dynamic> row,
) {
  final id = row['entry_id'];
  final revision = row['revision'];
  if (id is! String ||
      !RegExp(
        r'^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$',
        caseSensitive: false,
      ).hasMatch(id) ||
      revision is! int ||
      revision < 1 ||
      revision > 999999999) {
    return null;
  }
  final method = row['method_code'];
  final target = switch ((row['entry_kind'], method)) {
    ('MC_DRAFT', 'MC_LAB') => (module: 'lab-moisture', name: 'MC-Lab'),
    ('ROUTINE', 'RET_16C_72H') => (module: 'lab-ret', name: 'RET'),
    ('ROUTINE', 'SAND_25C') => (module: 'lab-routine', name: 'Germinasi'),
    ('ROUTINE', String code) when code.isNotEmpty && code != 'UNASSIGNED' => (
      module: 'lab-routine',
      name: 'Vigor',
    ),
    _ => null,
  };
  return target == null
      ? null
      : (id: id, revision: revision, module: target.module, name: target.name);
}

class LabLogbookScreen extends StatefulWidget {
  const LabLogbookScreen({
    super.key,
    this.loadRecords,
    this.download = fetchLogbookExport,
    this.share = shareLogbookExport,
    this.downloadForm = fetchLabForm,
    this.shareForm = shareRoutineForm,
  });
  final LogbookLoader? loadRecords;
  final LogbookExporter download;
  final LogbookSharer share;
  final LogbookFormLoader downloadForm;
  final LogbookFormSharer shareForm;
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
    if (working || changed || page == null || (page!['total'] as int) > 2000) {
      return;
    }
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

  List<String> appliedLabels() {
    final current = page;
    if (current == null) return const [];
    final query = (applied['p_search'] as String).trim();
    final origin = const {
      'PLANT': 'Permintaan Plant',
      'ROUTINE': 'Uji rutin Lab',
      'MC': 'MC Lab',
    }[applied['p_origin']];
    final scope = [
      for (final site in current['lab_sites'] as List)
        if (site['id'] == applied['p_lab_site_id']) site['site_name'] as String,
      if (query.isNotEmpty) 'Cari: $query',
      if (origin != null) origin,
      if (applied['p_method'] != 'ALL')
        for (final m in current['method_options'] as List)
          if (m['method_code'] == applied['p_method'])
            m['method_name'] as String,
      if (applied['p_status'] != 'ALL')
        logbookStatuses[applied['p_status']] ?? applied['p_status'] as String,
      if (applied['p_from'] != null || applied['p_to'] != null)
        "${applied['p_date_basis'] == 'OBSERVED' ? 'Pengamatan' : 'Pencatatan'}: "
            "${applied['p_from'] ?? 'tanpa awal'} – ${applied['p_to'] ?? 'tanpa akhir'} (WIB)",
    ];
    return scope;
  }

  Widget select(String label, String key, Map<String, String> options) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: DropdownButtonFormField<String>(
          key: ValueKey('$key:${filters[key]}:${options.keys.join()}'),
          initialValue: filters[key] as String?,
          isExpanded: true,
          itemHeight: null,
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
        const LabReadOnlyIntro(
          title: 'Catatan kerja Lab',
          icon: Icons.menu_book_outlined,
          description:
              'Catatan dari aplikasi, terpisah dari arsip Excel. Analisis disetujui QA bukan pelepasan lot.',
        ),
        LabFormCard(
          title: 'Cari catatan',
          icon: Icons.search,
          children: [
            TextField(
              controller: search,
              maxLength: 120,
              enabled: !working,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Cari lot, hybrid, label, nomor uji',
              ),
              onChanged: (v) => patch('p_search', v),
              onSubmitted: (_) => load(filters),
            ),
            ExpansionTile(
              key: const PageStorageKey('logbook-filter'),
              shape: const Border(),
              collapsedShape: const Border(),
              tilePadding: EdgeInsets.zero,
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              title: const Text('Filter lanjutan'),
              subtitle: Text(
                [
                  for (final s in (catalog?['lab_sites'] as List? ?? []))
                    if (s['id'] == filters['p_lab_site_id']) s['site_name'],
                  'Tanggal, asal, metode, status',
                ].join(' · '),
              ),
              children: [
                if (catalog != null)
                  select('Lab', 'p_lab_site_id', {
                    for (final s in catalog!['lab_sites'] as List)
                      s['id'] as String: s['site_name'] as String,
                  }),
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
                select('Dasar tanggal', 'p_date_basis', {
                  'RECORDED': 'Pertama dicatat di aplikasi',
                  'OBSERVED': 'Pengamatan final / ukur MC aktual',
                }),
                date('Dari tanggal (WIB)', 'p_from'),
                date('Sampai tanggal (WIB)', 'p_to'),
                const Text(
                  'Batas tanggal termasuk hari awal dan akhir. Jika memakai tanggal pengamatan, catatan tanpa waktu pengamatan tidak masuk rentang tanggal.',
                ),
                const SizedBox(height: 12),
              ],
            ),
            const SizedBox(height: 8),
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
          ],
        ),
        if (changed && page != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Semantics(
              liveRegion: true,
              child: const Text(
                'Filter berubah. Tekan Tampilkan catatan; hasil di bawah masih memakai filter sebelumnya.',
              ),
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
            padding: EdgeInsets.symmetric(vertical: 16),
            child: LinearProgressIndicator(
              semanticsLabel: 'Memuat catatan Lab',
            ),
          ),
        if (page != null) ...[
          const SizedBox(height: 24),
          Text(
            '${page!['total']} catatan cocok',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text('Dimuat ${logbookWib(page!['as_of'])}'),
          const SizedBox(height: 8),
          Wrap(
            key: const ValueKey('logbook-applied-filters'),
            spacing: 6,
            runSpacing: 6,
            children: [for (final label in appliedLabels()) LabLabel(label)],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OutlinedButton.icon(
                onPressed: working || changed || (page!['total'] as int) > 2000
                    ? null
                    : download,
                icon: const Icon(Icons.download),
                label: const Text('Unduh rekap Excel'),
              ),
              if (changed)
                const Text(
                  'Terapkan perubahan filter dahulu sebelum mengunduh.',
                ),
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
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: ExpansionTile(
              key: const PageStorageKey('logbook-summary'),
              shape: const Border(),
              collapsedShape: const Border(),
              title: const Text('Ringkasan & cara baca'),
              subtitle: const Text(
                'Seluruh hasil filter, bukan hanya halaman ini.',
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Satu catatan berarti satu percobaan uji, draft, atau item permintaan yang belum mulai. Uji ulang terpisah; ini bukan jumlah lot, benih, atau permintaan.',
                ),
                const SizedBox(height: 12),
                LabFieldGrid(
                  fields: [
                    for (final e in <String, String>{
                      'approved': 'Analisis disetujui QA',
                      'draft': 'Draft',
                      'waiting_qa': 'Menunggu QA',
                      'retest': 'Perlu uji ulang',
                      'other': 'Status lainnya',
                    }.entries)
                      LabRecordValue(e.value, '${page!['summary'][e.key]}'),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${page!['summary']['missing_observation_time']} catatan belum punya waktu pengamatan final / ukur MC.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Rekap Excel mengambil seluruh hasil filter saat diunduh (maksimal 2000 catatan). Form di rincian adalah satu catatan dan satu revisi.',
                ),
              ],
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
            LogbookEntryCard(
              key: row['entry_id'] == null
                  ? null
                  : ValueKey((row['entry_kind'], row['entry_id'])),
              row: Map<String, dynamic>.from(row),
              allowForms: !changed && AppConfig.hostedPilot,
              loadForm: widget.downloadForm,
              shareForm: widget.shareForm,
            ),
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
  const LogbookEntryCard({
    super.key,
    required this.row,
    this.allowForms = false,
    this.loadForm = fetchLabForm,
    this.shareForm = shareRoutineForm,
  });
  final Map<String, dynamic> row;
  final bool allowForms;
  final LogbookFormLoader loadForm;
  final LogbookFormSharer shareForm;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = row['status'].toString();
    final origin =
        logbookOrigins[row['entry_kind']] ?? row['entry_kind'].toString();
    return LabFormCard(
      title: row['lot_code'] as String,
      icon: Icons.inventory_2_outlined,
      hint: "${row['hybrid']} · ${row['stage_code']} · ${row['method_name']}",
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (origin != row['method_name']) LabLabel(origin),
            WorkflowStatusBadge(
              status: status,
              label: logbookStatuses[status] ?? status,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          [
            if (row['run_code'] ?? row['request_code'] case final String code)
              code,
            if (row['attempt_no'] != null) 'Percobaan ke-${row['attempt_no']}',
            if (row['revision'] != null) 'Revisi ${row['revision']}',
          ].join(' · '),
          style: theme.textTheme.bodySmall,
        ),
        Text(logbookResult(row), style: theme.textTheme.titleSmall),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _LogbookEntryDetail(
                  row: row,
                  allowForms: allowForms,
                  loadForm: loadForm,
                  shareForm: shareForm,
                ),
              ),
            ),
            label: const Text('Buka rincian'),
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            iconAlignment: IconAlignment.end,
          ),
        ),
      ],
    );
  }
}

class _LogbookEntryDetail extends StatelessWidget {
  const _LogbookEntryDetail({
    required this.row,
    required this.allowForms,
    required this.loadForm,
    required this.shareForm,
  });
  final Map<String, dynamic> row;
  final bool allowForms;
  final LogbookFormLoader loadForm;
  final LogbookFormSharer shareForm;

  @override
  Widget build(BuildContext context) {
    final target = logbookFormTarget(row);
    final theme = Theme.of(context);
    final status = row['status'].toString();
    final code = row['run_code'] ?? row['request_code'];
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: LabLotTitle.toolbarHeight(context),
        title: LabLotTitle(
          lot: row['lot_code'] as String,
          reference: code?.toString() ?? 'Rincian catatan Lab',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LabFormCard(
            title: row['method_name'] as String,
            icon: Icons.fact_check_outlined,
            hint:
                "${row['hybrid']} · ${row['stage_code']} · ${logbookOrigins[row['entry_kind']] ?? row['entry_kind']}",
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: WorkflowStatusBadge(
                  status: status,
                  label: logbookStatuses[status] ?? status,
                ),
              ),
              const SizedBox(height: 8),
              Text(logbookResult(row), style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(switch (row['result_state']) {
                'QA_APPROVED' => 'Persetujuan analisis bukan pelepasan lot.',
                'DRAFT_MEAN' ||
                'MC_RECORD_MEAN' => 'MC dicatat tanpa penilaian lulus/gagal.',
                _ => 'Belum menjadi analisis yang disetujui QA.',
              }),
            ],
          ),
          if (target != null && allowForms)
            RoutineFormDownload(
              record: {
                'id': target.id,
                'revision': target.revision,
                'method_code': row['method_code'],
              },
              title: 'Form pengujian · revisi ${target.revision}',
              description: 'PDF atau Excel untuk satu catatan ini.',
              formName: target.name,
              load: (id, revision, format) =>
                  loadForm(id, revision, format, module: target.module),
              share: shareForm,
            ),
          if (target != null && AppConfig.hostedPilot && !allowForms)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Kembali dan terapkan filter sebelum mengunduh form.',
              ),
            ),
          if (row['entry_kind'] == 'PLANT_RUN')
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Cari nomor permintaan atau lot ini di Antrean pengujian Lab untuk membuka form yang tersedia.',
              ),
            ),
          LabFormCard(
            title: 'Rincian catatan & waktu',
            icon: Icons.schedule_outlined,
            children: [
              LabFieldGrid(
                fields: [
                  LabRecordValue(
                    'Label sampel',
                    row['sample_reference']?.toString(),
                  ),
                  LabRecordValue(
                    'Permintaan',
                    '${row['request_code'] ?? 'Tidak ada'}',
                  ),
                  LabRecordValue(
                    'Nomor uji',
                    '${row['run_code'] ?? 'Belum ada'}',
                  ),
                  if (row['attempt_no'] != null)
                    LabRecordValue('Percobaan ke', '${row['attempt_no']}'),
                  if (row['revision'] != null)
                    LabRecordValue('Revisi', '${row['revision']}'),
                  LabRecordValue(
                    'Pertama dicatat',
                    logbookWib(row['recorded_at']),
                  ),
                  LabRecordValue(
                    'Pengamatan final / ukur MC',
                    logbookWib(row['observed_at']),
                  ),
                  LabRecordValue(
                    'Pemeriksaan QA terakhir',
                    logbookWib(row['reviewed_at']),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
