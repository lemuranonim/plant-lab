import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/database/supabase_client.dart';
import 'lab_logbook_screen.dart';
import 'lab_workspace_widgets.dart';
import 'moisture_lab_screen.dart';
import 'routine_lab_screen.dart';
import 'workflow_presentation.dart';

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
const monitoringQuickGroups = {
  'ALL': 'Semua',
  'ACTIVE': 'Belum selesai',
  'WAITING_QA': 'Menunggu QA',
  'RETEST': 'Perlu uji ulang',
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

class _FocusPanel extends StatelessWidget {
  const _FocusPanel(this.focus);
  final MonitoringFocus focus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: focus.warning
            ? theme.colorScheme.tertiaryContainer
            : theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          color: focus.warning
              ? theme.colorScheme.onTertiaryContainer
              : theme.colorScheme.onSurface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              focus.label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (focus.showHours) Text(monitoringHours(focus.hours)),
            if (focus.since != null) Text('Sejak ${logbookWib(focus.since)}'),
          ],
        ),
      ),
    );
  }
}

class _MonitoringDetail extends StatelessWidget {
  const _MonitoringDetail({required this.entry});
  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final focus = monitoringFocus(entry);
    final scheme = Theme.of(context).colorScheme;
    final timestamps = {
      'Sampel diterima / tersedia': entry['received_at'],
      'Kirim ke QA': entry['submitted_at'],
      'Keputusan QA': entry['decision_at'],
    };
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: LabLotTitle.toolbarHeight(context),
        title: LabLotTitle(
          lot: entry['lot_code'] as String,
          reference:
              (entry['run_code'] ?? entry['request_code'])?.toString() ??
              'Rincian pemantauan',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LabFormCard(
            title: entry['method_name'] as String,
            icon: Icons.fact_check_outlined,
            hint:
                "${entry['hybrid']} · ${logbookOrigins[entry['entry_kind']] ?? entry['entry_kind']}",
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: WorkflowStatusBadge(
                  status: entry['status'] as String,
                  label: monitoringGroups[entry['work_group']],
                ),
              ),
              if (focus != null) ...[
                const SizedBox(height: 12),
                _FocusPanel(focus),
              ],
            ],
          ),
          LabFormCard(
            title: 'Waktu yang tercatat',
            icon: Icons.schedule_outlined,
            children: [
              for (final step in timestamps.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        step.value == null
                            ? Icons.circle_outlined
                            : Icons.circle,
                        size: 12,
                        color: step.value == null
                            ? scheme.outline
                            : scheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LabRecordValue(step.key, logbookWib(step.value)),
                      ),
                    ],
                  ),
                ),
              if (entry['receipt_basis'] == 'RECEIPT_EVENT_TIME')
                const Text(
                  'Waktu penerimaan mengikuti catatan serah terima aplikasi, bukan tanggal tanam atau pengamatan.',
                ),
              if (entry['clock_issue'] == true)
                const Text(
                  'Periksa urutan tanggal di catatan asal. Waktu tunggu tidak diberi angka perkiraan.',
                ),
            ],
          ),
          LabFormCard(
            title: 'Catatan asal',
            icon: Icons.list_alt_outlined,
            children: [
              LabFieldGrid(
                fields: [
                  LabRecordValue(
                    'Status catatan asal',
                    logbookStatuses[entry['status']] ??
                        entry['status'] as String?,
                  ),
                  LabRecordValue(
                    'Label sampel',
                    entry['sample_reference'] as String?,
                  ),
                  LabRecordValue(
                    'Nomor permintaan',
                    entry['request_code'] as String? ?? 'Tidak ada',
                  ),
                  LabRecordValue('Nomor uji', entry['run_code'] as String?),
                  if (entry['attempt_no'] != null)
                    LabRecordValue('Percobaan ke', "${entry['attempt_no']}"),
                  if (entry['sample_to_submit_hours'] != null)
                    LabRecordValue(
                      'Sampel diterima sampai kirim hasil',
                      monitoringHours(entry['sample_to_submit_hours']),
                    ),
                  if (entry['qa_tat_hours'] != null)
                    LabRecordValue(
                      'Kirim hasil sampai keputusan QA',
                      monitoringHours(entry['qa_tat_hours']),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Buka menu catatan asal'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

typedef MonitoringFocus = ({
  String label,
  bool showHours,
  num? hours,
  String? since,
  bool warning,
});

MonitoringFocus? monitoringFocus(Map<String, dynamic> entry) {
  MonitoringFocus item(
    String label, {
    String? hoursKey,
    String? sinceKey,
    bool warning = false,
  }) => (
    label: label,
    showHours: hoursKey != null,
    hours: hoursKey == null ? null : entry[hoursKey] as num?,
    since: sinceKey == null ? null : entry[sinceKey] as String?,
    warning: warning,
  );
  if (entry['clock_issue'] == true) {
    return item('Urutan waktu perlu diperiksa', warning: true);
  }
  return switch (entry['work_group']) {
    'WAITING_SAMPLE' => item(
      entry['received_at'] == null
          ? 'Penerimaan sampel belum tercatat'
          : 'Periksa status serah terima',
    ),
    'WAITING_QA' => item(
      'Sudah menunggu QA',
      hoursKey: 'waiting_qa_hours',
      sinceKey: 'submitted_at',
    ),
    'RETEST' => item(
      'Sejak QA meminta uji ulang',
      hoursKey: 'retest_wait_hours',
      sinceKey: 'decision_at',
    ),
    'WAITING_TEST' || 'TESTING' => item(
      'Sejak sampel diterima, belum kirim hasil',
      hoursKey: 'open_sample_hours',
      sinceKey: 'received_at',
    ),
    'RETURNED' => item('Perlu perbaikan catatan', sinceKey: 'decision_at'),
    _ => null,
  };
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
  void quickGroup(String group) {
    if (busy || changed || applied['p_work_group'] == group) return;
    final next = {...applied, 'p_work_group': group};
    setState(() => filters = next);
    load(next);
  }

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
  Future<void> openDetail(Map<String, dynamic> entry) async {
    final source = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => _MonitoringDetail(entry: entry)),
    );
    if (!mounted || source != true) return;
    if (entry['entry_kind'].toString().startsWith('PLANT_')) {
      Navigator.of(context).maybePop();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => switch (entry['entry_kind']) {
          'MC_DRAFT' => const MoistureLabScreen(),
          'ROUTINE' => const RoutineLabScreen(),
          _ => const LabLogbookScreen(),
        },
      ),
    );
  }

  Widget row(Map<String, dynamic> e) {
    final focus = monitoringFocus(e);
    final source = [
      logbookOrigins[e['entry_kind']] ?? e['entry_kind'],
      e['run_code'] ?? e['request_code'],
      if (e['attempt_no'] != null) 'Percobaan ${e['attempt_no']}',
    ].whereType<String>().join(' · ');
    return LabFormCard(
      title: e['lot_code'] as String,
      icon: Icons.inventory_2_outlined,
      hint: "${e['hybrid']} · ${e['method_name']}",
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: WorkflowStatusBadge(
            status: e['status'] as String,
            label: monitoringGroups[e['work_group']],
          ),
        ),
        const SizedBox(height: 8),
        Text(source, style: Theme.of(context).textTheme.bodySmall),
        if (focus != null) ...[const SizedBox(height: 10), _FocusPanel(focus)],
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => openDetail(e),
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            iconAlignment: IconAlignment.end,
            label: const Text('Buka rincian waktu'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pemantauan kerja Lab')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const LabReadOnlyIntro(
          title: 'Pantau pekerjaan Lab',
          icon: Icons.query_stats,
          description:
              'Lihat status dan waktu yang sudah tercatat, tanpa mengisi rekap baru.',
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
        ExpansionTile(
          key: const PageStorageKey('monitor-filters'),
          tilePadding: EdgeInsets.zero,
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          title: const Text('Filter lanjutan'),
          children: [
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
            const LabHelp(
              label: 'Cara pakai filter tanggal',
              text:
                  'Hari awal dan akhir ikut dihitung. Catatan tanpa tanggal pada dasar yang dipilih tidak masuk hasil. Pilih Keputusan QA untuk rekap keputusan per periode.',
            ),
          ],
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
          Text('Dimuat ${logbookWib(page!['as_of'])}'),
          Text(
            'Ditampilkan: ${[monitoringGroups[applied['p_work_group']], for (final site in page!['lab_sites'] as List)
              if (site['id'] == applied['p_lab_site_id']) site['site_name'], if ((applied['p_search'] as String).trim().isNotEmpty) "Cari: ${(applied['p_search'] as String).trim()}"].whereType<String>().join(' · ')}',
          ),
          const SizedBox(height: 8),
          Semantics(
            container: true,
            label: 'Filter cepat kelompok pekerjaan',
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final entry in monitoringQuickGroups.entries)
                  ChoiceChip(
                    key: ValueKey('monitor-quick-${entry.key}'),
                    selected: applied['p_work_group'] == entry.key,
                    label: Text(entry.value),
                    onSelected: busy || changed
                        ? null
                        : (_) => quickGroup(entry.key),
                  ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: busy
                  ? null
                  : () => load(applied, page!['offset'] as int),
              child: const Text('Muat ulang pemantauan'),
            ),
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            key: const PageStorageKey('monitor-summary'),
            title: const Text('Ringkasan jumlah & waktu pengerjaan'),
            tilePadding: EdgeInsets.zero,
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Jumlah per percobaan atau draft. Waktu hanya sampai data dimuat, tanpa penilaian SLA.',
              ),
              LabMenuGrid(
                cards: [
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
                    LabMetricTile(
                      title: x.value,
                      value: '${page!['summary'][x.key]}',
                    ),
                ],
              ),
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
              const LabHelp(
                label: 'Cara membaca waktu',
                text:
                    'MC tidak masuk rata-rata atau persentase keputusan analisis. Revalidation bukan uji ulang QA. Uji ulang yang sudah punya percobaan lanjutan tidak dihitung aktif.',
              ),
              Text(
                '${page!['summary']['missing_sample_time']} catatan belum punya waktu sampel; ${page!['summary']['missing_qa_time']} pekerjaan menunggu QA belum punya waktu kirim; ${page!['summary']['clock_issues']} catatan punya urutan waktu yang perlu diperiksa. Waktu yang belum lengkap tidak diganti nol.',
              ),
            ],
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
