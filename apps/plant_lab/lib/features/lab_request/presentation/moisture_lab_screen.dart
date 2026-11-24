import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/config/app_config.dart';
import '../../../core/database/supabase_client.dart';
import 'routine_lab_screen.dart';
import 'routine_sample_reference.dart';
import 'routine_form_download.dart';
import 'moisture_record_workflow.dart';

Map<String, dynamic> emptyMoistureContent() => {
  'version': 1,
  'sample_reference': null,
  'sample_type': null,
  'received_at': null,
  'measured_at': null,
  'instrument': null,
  'method': null,
  'analyst_name': null,
  'note': null,
  'readings': [null, null, null],
};
double? moistureMean(List<dynamic> readings) =>
    readings.length == 3 && readings.every((x) => x is num)
    ? readings.cast<num>().fold<double>(0, (a, b) => a + b) / 3
    : null;
String moistureNumber(dynamic value) => value == null
    ? 'belum lengkap'
    : (value as num).toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '');
final moistureDraftsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ({String site, int offset})>(
      (ref, q) => supabase
          .schema(AppConfig.isolatedApiSchema)
          .rpc<Map<String, dynamic>>(
            'list_lab_moisture_drafts',
            params: {'p_lab_site_id': q.site, 'p_offset': q.offset},
          ),
    );

class MoistureLabScreen extends ConsumerStatefulWidget {
  const MoistureLabScreen({super.key});
  @override
  ConsumerState<MoistureLabScreen> createState() => _MoistureLabScreenState();
}

class _MoistureLabScreenState extends ConsumerState<MoistureLabScreen> {
  String? site;
  String term = '';
  int lotOffset = 0, draftOffset = 0;
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> edit(Map<String, dynamic> record, String lab) async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => MoistureDraftEditor(
          record: record,
          labSiteId: lab,
          saveDraft: (args) => supabase
              .schema(AppConfig.isolatedApiSchema)
              .rpc<Map<String, dynamic>>(
                'save_lab_moisture_draft',
                params: args,
              ),
          loadReferences: (term, offset) => supabase
              .schema(AppConfig.isolatedApiSchema)
              .rpc<Map<String, dynamic>>(
                'list_mc_sample_references',
                params: {
                  'p_lab_site_id': lab,
                  'p_lot_id': record['lot_id'],
                  'p_search': term,
                  'p_offset': offset,
                },
              ),
        ),
      ),
    );
    ref.invalidate(moistureDraftsProvider);
    if (mounted) setState(() => draftOffset = 0);
  }

  @override
  Widget build(BuildContext context) {
    final query = (site: site, search: term, offset: lotOffset);
    return Scaffold(
      appBar: AppBar(title: const Text('Catatan MC Lab')),
      body: ref
          .watch(routineCatalogProvider(query))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: TextButton(
                onPressed: () => ref.invalidate(routineCatalogProvider(query)),
                child: const Text('Data belum dimuat. Coba lagi.'),
              ),
            ),
            data: (options) {
              final lab = options['selected_lab_site_id'] as String,
                  canWrite =
                      options['can_write'] == true &&
                      AppConfig.canonicalWritesEnabled;
              final draftQuery = (site: lab, offset: draftOffset);
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'MC Lab mandiri, tanpa request Plant; bukan MC PI/Plant. Catat 3 pembacaan persen; kosong bukan nol. Lengkapi label, jenis sampel, tanggal, petugas, alat dan metode aktual. Simpan lalu kirim ke QA. QA memverifikasi catatan atau mengembalikan untuk diperbaiki, tanpa lulus/gagal atau pelepasan lot.',
                      ),
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: lab,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Lab tempat pengukuran',
                    ),
                    items: [
                      for (final s in options['lab_sites'] as List)
                        DropdownMenuItem(
                          value: s['id'] as String,
                          child: Text(s['site_name'] as String),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          site = v;
                          lotOffset = 0;
                          draftOffset = 0;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: search,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      labelText: 'Cari kode lot atau hybrid',
                    ),
                    onSubmitted: (_) => setState(() {
                      term = search.text;
                      lotOffset = 0;
                    }),
                  ),
                  OutlinedButton(
                    onPressed: () => setState(() {
                      term = search.text;
                      lotOffset = 0;
                    }),
                    child: const Text('Cari lot'),
                  ),
                  if (!canWrite)
                    const Text(
                      'QA memeriksa catatan yang telah dikirim. Input bacaan tetap dilakukan Analis yang ditugaskan.',
                    ),
                  Text(
                    '${options['total']} lot cocok. Maksimal 50 tiap halaman.',
                  ),
                  for (final lot in options['lots'] as List)
                    Card(
                      child: ListTile(
                        title: Text(lot['lot_code'] as String),
                        subtitle: Text(
                          '${lot['hybrid']} · ${lot['stage_code']} · ${lot['plant_site']}',
                        ),
                        trailing: canWrite ? const Icon(Icons.add) : null,
                        onTap: canWrite
                            ? () => edit({
                                'id': const Uuid().v4(),
                                'lot_id': lot['id'],
                                'lot_code': lot['lot_code'],
                                'hybrid': lot['hybrid'],
                                'stage_code': lot['stage_code'],
                                'revision': 0,
                                'content': emptyMoistureContent(),
                              }, lab)
                            : null,
                      ),
                    ),
                  if ((options['lots'] as List).isEmpty)
                    const Text(
                      'Lot belum ditemukan. Jangan pilih lot pengganti.',
                    ),
                  Wrap(
                    spacing: 12,
                    children: [
                      TextButton(
                        onPressed: lotOffset == 0
                            ? null
                            : () => setState(() => lotOffset -= 50),
                        child: const Text('Sebelumnya'),
                      ),
                      TextButton(
                        onPressed: options['has_more'] == true
                            ? () => setState(() => lotOffset += 50)
                            : null,
                        child: const Text('Berikutnya'),
                      ),
                    ],
                  ),
                  const Divider(),
                  Text(
                    'Catatan MC tersimpan',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(moistureDraftsProvider(draftQuery)),
                    child: const Text('Muat ulang daftar MC'),
                  ),
                  ref
                      .watch(moistureDraftsProvider(draftQuery))
                      .when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => const Text(
                          'Daftar belum dimuat, bukan berarti kosong. Coba muat ulang.',
                        ),
                        data: (page) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('${page['total']} catatan MC Lab'),
                            for (final d in page['drafts'] as List)
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        '${d['lot_code']} · ${moistureStatus(d['status'])}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      Text(
                                        '${d['hybrid']} · ${d['stage_code']} · revisi ${d['revision']}',
                                      ),
                                      Text(
                                        'Label: ${d['content']['sample_reference'] ?? 'belum dicatat'}',
                                      ),
                                      Text(
                                        'MC1/2/3: ${(d['content']['readings'] as List).map((v) => v == null ? 'belum dicatat' : '${moistureNumber(v)}%').join(' / ')}',
                                      ),
                                      Text(
                                        'Rata-rata 3 pembacaan: ${moistureNumber(d['mean_percent'])}${d['mean_percent'] == null ? '' : '%'} · tidak dinilai lulus/gagal.',
                                      ),
                                      ExpansionTile(
                                        title: const Text('Rincian pengukuran'),
                                        children: [
                                          Text(
                                            'Pelaksana: ${d['content']['analyst_name'] ?? 'belum dicatat'}\nAlat: ${d['content']['instrument'] ?? 'belum dicatat'}\nMetode: ${d['content']['method'] ?? 'belum dicatat'}\nSampel tersedia: ${routineWib(d['content']['received_at'] as String?)}\nUkur: ${routineWib(d['content']['measured_at'] as String?)}\nCatatan: ${d['content']['note'] ?? 'belum dicatat'}',
                                          ),
                                        ],
                                      ),
                                      if (d['review'] != null)
                                        Text(
                                          'QA: ${d['review']['reviewer_name']} · '
                                          '${d['review']['decision'] == 'RETURN' ? 'Dikembalikan' : 'Catatan diverifikasi'} '
                                          '· revisi ${d['review']['revision']} · ${routineWib(d['review']['reviewed_at'] as String?)}\n'
                                          '${d['review']['note'] ?? ''}',
                                        ),
                                      if (d['record_review_enabled'] == true)
                                        MoistureRecordWorkflow(
                                          key: ValueKey(
                                            '${d['id']}-${d['revision']}-${d['status']}',
                                          ),
                                          record: Map<String, dynamic>.from(
                                            d as Map,
                                          ),
                                          onChanged: () => ref.invalidate(
                                            moistureDraftsProvider,
                                          ),
                                        ),
                                      if (canWrite &&
                                          d['can_edit'] == true &&
                                          d['can_submit'] != true)
                                        const Text(
                                          'Lengkapi dan simpan label, jenis sampel, tanggal, nama pelaksana, alat, metode dan 3 bacaan dahulu. Catatan yang dikembalikan perlu disimpan sebagai revisi baru sebelum dikirim lagi.',
                                        ),
                                      if (canWrite && d['can_edit'] == true)
                                        OutlinedButton(
                                          onPressed: () => edit(
                                            Map<String, dynamic>.from(d as Map),
                                            lab,
                                          ),
                                          child: const Text('Lanjut isi MC'),
                                        ),
                                      RoutineFormDownload(
                                        record: Map<String, dynamic>.from(
                                          d as Map,
                                        ),
                                        load: fetchMcForm,
                                        formName: 'MC-Lab',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            Wrap(
                              spacing: 12,
                              children: [
                                TextButton(
                                  onPressed: draftOffset == 0
                                      ? null
                                      : () => setState(() => draftOffset -= 50),
                                  child: const Text('Sebelumnya'),
                                ),
                                TextButton(
                                  onPressed: page['has_more'] == true
                                      ? () => setState(() => draftOffset += 50)
                                      : null,
                                  child: const Text('Berikutnya'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                ],
              );
            },
          ),
    );
  }
}

class MoistureDraftEditor extends StatefulWidget {
  const MoistureDraftEditor({
    super.key,
    required this.record,
    required this.labSiteId,
    required this.saveDraft,
    required this.loadReferences,
  });
  final Map<String, dynamic> record;
  final String labSiteId;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) saveDraft;
  final RoutineReferenceLoader loadReferences;
  @override
  State<MoistureDraftEditor> createState() => _MoistureDraftEditorState();
}

class _MoistureDraftEditorState extends State<MoistureDraftEditor> {
  late Map<String, dynamic> content;
  late int revision;
  late Map<String, TextEditingController> fields;
  late List<TextEditingController> readings;
  bool busy = false, changed = false;
  String? error, message, action, previous;
  final labels = const {
    'sample_type': 'Jenis sampel pada form',
    'analyst_name': 'Nama pelaksana MC Lab',
    'instrument': 'Alat / nomor identitas alat',
    'method': 'Metode pengukuran aktual',
    'note': 'Catatan pengukuran',
  };
  @override
  void initState() {
    super.initState();
    content = Map<String, dynamic>.from(widget.record['content'] as Map);
    revision = widget.record['revision'] as int;
    fields = {
      for (final k in ['sample_reference', ...labels.keys])
        k: TextEditingController(text: content[k] as String?),
    };
    readings = [
      for (final v in content['readings'] as List)
        TextEditingController(text: v?.toString() ?? ''),
    ];
    for (final c in [...fields.values, ...readings]) {
      c.addListener(() => changed = true);
    }
  }

  @override
  void dispose() {
    for (final c in [...fields.values, ...readings]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> pick(String key) async {
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: now.hour, minute: now.minute),
    );
    if (time == null || !mounted) return;
    setState(() {
      content[key] = DateTime.utc(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ).subtract(const Duration(hours: 7)).toIso8601String();
      changed = true;
    });
  }

  Future<bool> leave() async {
    if (busy) return false;
    if (!changed) return true;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Tutup isian MC?'),
            content: const Text('Perubahan yang belum disimpan akan hilang.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Tetap mengisi'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Tutup isian'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> save() async {
    if (busy || !AppConfig.canonicalWritesEnabled) return;
    final values = <double?>[];
    for (final c in readings) {
      final raw = c.text.trim(),
          value = double.tryParse(raw.replaceAll(',', '.'));
      if (raw.isNotEmpty &&
          (value == null || !value.isFinite || value < 0 || value > 100)) {
        setState(
          () => error =
              'Isi MC dalam persen 0–100. Kosongkan jika belum dicatat.',
        );
        return;
      }
      values.add(raw.isEmpty ? null : value);
    }
    final body = {
      ...content,
      for (final e in fields.entries)
        e.key: e.value.text.trim().isEmpty ? null : e.value.text,
      'readings': values,
    };
    final args = {
          'p_draft_id': widget.record['id'],
          'p_expected_revision': revision,
          'p_lab_site_id': widget.labSiteId,
          'p_lot_id': widget.record['lot_id'],
          'p_content': body,
        },
        text = jsonEncode(args);
    if (previous != text) {
      previous = text;
      action = const Uuid().v4();
    }
    setState(() {
      busy = true;
      error = null;
      message = null;
    });
    try {
      final r = await widget.saveDraft({...args, 'p_action_id': action});
      if (mounted) {
        setState(() {
          revision = r['revision'] as int;
          content = body;
          changed = false;
          previous = null;
          action = null;
          message =
              'MC Lab tersimpan · revisi $revision. Masih draft, belum disetujui QA.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Belum terkonfirmasi tersimpan. Periksa angka, waktu, akses atau perubahan revisi. Ulangi dengan isian sama; jangan membuat catatan ganda.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !changed && !busy,
    onPopInvokedWithResult: (didPop, _) async {
      if (!didPop && await leave() && context.mounted) {
        setState(() => changed = false);
        Navigator.pop(context);
      }
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('Draft MC Lab')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${widget.record['lot_code']} · ${widget.record['hybrid']} · ${widget.record['stage_code']}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text('Revisi $revision · lot tidak diganti setelah tersimpan.'),
          const Text(
            'Tiga pembacaan persen, bukan angka MC PI/Plant. Isian boleh dicicil; kosong bukan nol. Tidak ada approval atau lulus/gagal dari draft ini.',
          ),
          RoutineSampleReferenceField(
            controller: fields['sample_reference']!,
            enabled: !busy,
            locked: false,
            loadReferences: widget.loadReferences,
          ),
          for (final entry in labels.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextField(
                controller: fields[entry.key],
                enabled: !busy,
                maxLength: entry.key == 'note' ? 1000 : 120,
                maxLines: entry.key == 'note' ? 3 : 1,
                decoration: InputDecoration(labelText: entry.value),
              ),
            ),
          for (final entry in {
            'received_at': 'Sampel tersedia di Lab',
            'measured_at': 'Tanggal dan jam ukur aktual',
          }.entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${entry.value} (WIB)'),
              subtitle: Text(routineWib(content[entry.key] as String?)),
              onTap: busy ? null : () => pick(entry.key),
              trailing: IconButton(
                tooltip: 'Kosongkan waktu MC',
                onPressed: busy
                    ? null
                    : () => setState(() {
                        content[entry.key] = null;
                        changed = true;
                      }),
                icon: const Icon(Icons.clear),
              ),
            ),
          for (int i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextField(
                key: ValueKey('mc-reading-$i'),
                controller: readings[i],
                enabled: !busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Pembacaan MC ${i + 1} (%)',
                ),
              ),
            ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (message != null) Text(message!),
          FilledButton(
            onPressed: busy ? null : save,
            child: Text(busy ? 'Menyimpan…' : 'Simpan draft MC Lab'),
          ),
          const Text(
            'Setelah simpan, kembali ke daftar untuk membaca rata-rata atau mengunduh form PDF/Excel. Rata-rata belum tersedia jika salah satu pembacaan masih kosong.',
          ),
        ],
      ),
    ),
  );
}
