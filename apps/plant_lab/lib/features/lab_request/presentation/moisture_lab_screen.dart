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
import 'lab_workspace_widgets.dart';
import 'workflow_presentation.dart';

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
    readings.length == 3 &&
        readings.every((x) => x is num && x.isFinite && x >= 0 && x <= 100)
    ? readings.cast<num>().fold<double>(0, (a, b) => a + b) / 3
    : null;
String moistureNumber(dynamic value) => value == null
    ? 'belum lengkap'
    : (value as num).toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '');
String _moistureDisplay(num value) =>
    '${moistureNumber(value).replaceAll('.', ',')}%';

double? _readMoisture(String input) {
  final value = double.tryParse(input.trim().replaceAll(',', '.'));
  return value != null && value.isFinite && value >= 0 && value <= 100
      ? value
      : null;
}

class _MoistureMeanPanel extends StatelessWidget {
  const _MoistureMeanPanel({required this.value, this.entered});
  final num? value;
  final int? entered;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: entered != null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entered == null
                  ? 'Rata-rata 3 pembacaan'
                  : 'Pratinjau rata-rata · $entered/3 terisi',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 3),
            Text(
              value == null ? 'Belum lengkap' : _moistureDisplay(value!),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoistureSampleFacts extends StatelessWidget {
  const _MoistureSampleFacts(this.content, {this.compact = false});
  final Map<dynamic, dynamic> content;
  final bool compact;

  @override
  Widget build(BuildContext context) => LabFieldGrid(
    minFieldWidth: 132,
    fields: [
      LabRecordValue('Label sampel', content['sample_reference'] as String?),
      LabRecordValue('Jenis sampel', content['sample_type'] as String?),
      LabRecordValue('Pelaksana', content['analyst_name'] as String?),
      LabRecordValue('Alat', content['instrument'] as String?),
      LabRecordValue('Metode', content['method'] as String?),
      LabRecordValue(
        'Waktu ukur',
        routineWib(content['measured_at'] as String?),
      ),
      if (!compact)
        LabRecordValue(
          'Sampel tersedia',
          routineWib(content['received_at'] as String?),
        ),
      if (!compact) LabRecordValue('Catatan', content['note'] as String?),
    ],
  );
}

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
                  const LabHelp(
                    text:
                        'Ini MC Lab mandiri, bukan MC PI/Plant. Rata-rata muncul setelah tiga pembacaan lengkap. Simpan sebelum kirim ke QA. QA memverifikasi catatan, bukan menilai lulus/gagal atau melepas lot.',
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
                                        d['lot_code'] as String,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      Text(
                                        '${d['hybrid']} · ${d['stage_code']} · revisi ${d['revision']}',
                                      ),
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: WorkflowStatusBadge(
                                          status: d['status'] as String,
                                          label: moistureStatus(d['status']),
                                        ),
                                      ),
                                      Text(
                                        'Label: ${d['content']['sample_reference'] ?? 'belum dicatat'}',
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        child: Wrap(
                                          spacing: 18,
                                          runSpacing: 6,
                                          children: [
                                            for (final reading
                                                in (d['content']['readings']
                                                        as List)
                                                    .asMap()
                                                    .entries)
                                              LabRecordValue(
                                                'MC ${reading.key + 1}',
                                                reading.value == null
                                                    ? null
                                                    : _moistureDisplay(
                                                        reading.value as num,
                                                      ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      _MoistureMeanPanel(
                                        value: d['mean_percent'] as num?,
                                      ),
                                      ExpansionTile(
                                        title: const Text('Rincian pengukuran'),
                                        tilePadding: EdgeInsets.zero,
                                        expandedCrossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _MoistureSampleFacts(
                                            d['content'] as Map,
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
                                          evidence: _MoistureSampleFacts(
                                            d['content'] as Map,
                                            compact: true,
                                          ),
                                          onChanged: () => ref.invalidate(
                                            moistureDraftsProvider,
                                          ),
                                        ),
                                      if (canWrite &&
                                          d['can_edit'] == true &&
                                          d['can_submit'] != true)
                                        const LabHelp(
                                          label: 'Syarat kirim ke QA',
                                          text:
                                              'Lengkapi label, jenis sampel, dua waktu aktual, pelaksana, alat, metode, dan tiga bacaan. Catatan yang dikembalikan harus disimpan sebagai revisi baru.',
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
  final identitySection = GlobalKey(),
      timeSection = GlobalKey(),
      countsSection = GlobalKey();
  late Map<String, dynamic> content;
  late int revision;
  late Map<String, TextEditingController> fields;
  late List<TextEditingController> readings;
  bool busy = false, changed = false;
  String? error, message, action, previous;
  late String observedInput;
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
    observedInput = _inputText();
    for (final c in [...fields.values, ...readings]) {
      c.addListener(_inputChanged);
    }
  }

  String _inputText() => jsonEncode([
    for (final c in [...fields.values, ...readings]) c.text,
  ]);
  void _inputChanged() {
    final next = _inputText();
    if (next == observedInput) return;
    observedInput = next;
    if (changed && message == null && error == null) return;
    setState(() {
      changed = true;
      message = null;
      error = null;
    });
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
      message = null;
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
      final raw = c.text.trim(), value = _readMoisture(raw);
      if (raw.isNotEmpty && value == null) {
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
          message = 'MC Lab tersimpan · revisi $revision. Belum diperiksa QA.';
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

  Widget draftFooter(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  error ??
                      message ??
                      (revision == 0
                          ? 'Draft baru'
                          : changed
                          ? 'Perubahan belum tersimpan · revisi terakhir $revision'
                          : 'Revisi $revision tersimpan'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: error == null
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.error,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              FilledButton(
                key: const ValueKey('mc-save-draft'),
                onPressed: busy ? null : save,
                child: Text(busy ? 'Menyimpan…' : 'Simpan draft MC Lab'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !changed && !busy,
    onPopInvokedWithResult: (didPop, _) async {
      if (!didPop && await leave() && context.mounted) {
        setState(() => changed = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) Navigator.pop(context);
        });
      }
    },
    child: Scaffold(
      appBar: AppBar(
        toolbarHeight: LabLotTitle.toolbarHeight(context),
        title: LabLotTitle(
          lot: widget.record['lot_code'] as String,
          reference: 'Draft MC Lab',
        ),
      ),
      bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom == 0
          ? draftFooter(context)
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.record['hybrid']} · ${widget.record['stage_code']}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            LabFormSections(
              sections: const ['Identitas', 'Waktu (WIB)', 'Pembacaan'],
              targets: [identitySection, timeSection, countsSection],
            ),
            const SizedBox(height: 12),
            LabFormCard(
              key: identitySection,
              title: 'Identitas sampel & pengukuran',
              icon: Icons.inventory_2_outlined,
              children: [
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
              ],
            ),
            LabFormCard(
              key: timeSection,
              title: 'Waktu pengukuran (WIB)',
              icon: Icons.schedule_outlined,
              children: [
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
                              message = null;
                            }),
                      icon: const Icon(Icons.clear),
                    ),
                  ),
              ],
            ),
            LabFormCard(
              key: countsSection,
              title: 'Tiga pembacaan kadar air',
              icon: Icons.water_drop_outlined,
              hint: 'Kosong berarti belum dicatat, bukan nol.',
              children: [
                LabFieldGrid(
                  maxColumns: 3,
                  minFieldWidth: 142,
                  fields: [
                    for (int i = 0; i < 3; i++)
                      TextField(
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
                  ],
                ),
                const SizedBox(height: 12),
                ListenableBuilder(
                  listenable: Listenable.merge(readings),
                  builder: (_, _) {
                    final values = readings
                        .map((c) => _readMoisture(c.text))
                        .toList();
                    return _MoistureMeanPanel(
                      value: moistureMean(values),
                      entered: values.nonNulls.length,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
