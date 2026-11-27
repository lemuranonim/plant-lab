import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/database/supabase_client.dart';
import 'routine_workflow_card.dart';
import 'routine_sample_reference.dart';
import 'routine_form_details.dart';
import 'routine_form_download.dart';
import 'lab_revalidation.dart';
import 'lab_workspace_widgets.dart';

typedef RoutineQuery = ({String? site, String search, int offset});
final routineCatalogProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, RoutineQuery>((ref, query) async {
      return supabase
          .schema(AppConfig.isolatedApiSchema)
          .rpc<Map<String, dynamic>>(
            'get_routine_lab_options',
            params: {
              'p_lab_site_id': query.site,
              'p_search': query.search,
              'p_offset': query.offset,
            },
          );
    });
final routineDraftsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, site) async {
      return supabase
          .schema(AppConfig.isolatedApiSchema)
          .rpc<Map<String, dynamic>>(
            'list_routine_lab_drafts',
            params: {'p_lab_site_id': site},
          );
    });
final routineRecordProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
      return supabase
          .schema(AppConfig.isolatedApiSchema)
          .rpc<Map<String, dynamic>>(
            'get_routine_lab_record',
            params: {'p_draft_id': id},
          );
    });
final approvedRoutineProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ({String module, int offset})>((
      ref,
      query,
    ) async {
      return supabase
          .schema(AppConfig.isolatedApiSchema)
          .rpc<Map<String, dynamic>>(
            'list_approved_routine_lab_results',
            params: {'p_module': query.module, 'p_offset': query.offset},
          );
    });

const routineCountLabels = {
  'first_normal': 'Normal first count',
  'final_normal': 'Normal final count',
  'abnormal': 'Abnormal',
  'fresh': 'Fresh',
  'hard': 'Hard',
  'dead': 'Mati',
  'radicle_at_least_2mm': 'Radikula minimal 2 mm',
};

class RoutineWorkflowScreen extends ConsumerWidget {
  const RoutineWorkflowScreen({super.key, required this.draftId});
  final String draftId;

  Widget _reviewEvidence(Map<String, dynamic> record, Widget detail) {
    final content = (record['content'] as Map?) ?? const {};
    String time(String field) => routineWib(content[field] as String?);
    return LabFormCard(
      title: 'Bukti sampel & waktu',
      icon: Icons.inventory_2_outlined,
      children: [
        LabFieldGrid(
          minFieldWidth: 132,
          fields: [
            LabRecordValue(
              'Label sampel',
              content['sample_reference'] as String?,
            ),
            LabRecordValue('Sampel tersedia', time('received_at')),
            LabRecordValue(
              record['method_code'] == 'RET_16C_72H'
                  ? 'Mulai ditempatkan pada 16 °C'
                  : 'Mulai uji / perlakuan',
              time('started_at'),
            ),
            LabRecordValue('Pengamatan final', time('final_at')),
          ],
        ),
        detail,
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordState = ref.watch(routineRecordProvider(draftId));
    final lot = recordState.hasError
        ? null
        : recordState.valueOrNull?['lot_code'] as String?;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: lot == null ? null : LabLotTitle.toolbarHeight(context),
        title: lot == null
            ? const Text('Hasil & pemeriksaan rutin')
            : LabLotTitle(lot: lot, reference: 'Hasil & pemeriksaan rutin'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang catatan',
            onPressed: () => ref.invalidate(routineRecordProvider(draftId)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: recordState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: TextButton(
              onPressed: () => ref.invalidate(routineRecordProvider(draftId)),
              child: const Text(
                'Catatan belum dimuat. Periksa akses/koneksi lalu coba lagi.',
              ),
            ),
          ),
        ),
        data: (record) {
          final reviewing =
              AppConfig.canonicalWritesEnabled &&
              (record['workflow'] as Map?)?['can_review'] == true;
          final download = RoutineFormDownload(
            record: record,
            formName: record['method_code'] == 'RET_16C_72H' ? 'RET' : null,
            load: record['method_code'] == 'RET_16C_72H'
                ? fetchRetForm
                : fetchRoutineForm,
          );
          final detail = ExpansionTile(
            title: Text(
              reviewing
                  ? 'Catatan dan hitungan tercatat'
                  : 'Isian sampel & waktu nyata',
            ),
            tilePadding: reviewing ? EdgeInsets.zero : null,
            childrenPadding: const EdgeInsets.all(12),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!reviewing) ...[
                Text(
                  'Referensi sampel: ${record['content']['sample_reference'] ?? 'belum dicatat'}',
                ),
                Text(
                  'Sampel tersedia: ${routineWib(record['content']['received_at'] as String?)}',
                ),
                Text(
                  'Mulai: ${routineWib(record['content']['started_at'] as String?)}',
                ),
                Text(
                  'Final: ${routineWib(record['content']['final_at'] as String?)}',
                ),
              ],
              Text('Catatan: ${record['content']['note'] ?? 'belum dicatat'}'),
              if (record['content']['form'] != null) ...[
                Text(
                  'Tanaman / spesies: ${record['content']['form']['crop_species'] ?? 'belum dicatat'}',
                ),
                Text(
                  'Pelaksana: ${record['content']['form']['analyst_name'] ?? 'belum dicatat'}',
                ),
                Text(
                  'Suhu pada form: ${record['content']['form']['temperature_text'] ?? 'belum dicatat'} °C',
                ),
                Text(
                  'Tanam: ${routineWib(record['content']['form']['planted_at'] as String?)}',
                ),
                Text(
                  'First count: ${routineWib(record['content']['form']['first_count_at'] as String?)}',
                ),
                for (final entry
                    in (record['content']['form']['annotations'] as List)
                        .asMap()
                        .entries)
                  Text(
                    'Subulangan ${entry.key ~/ 2 + 1}${entry.key.isOdd ? 'b' : 'a'}: jenis abnormal ${entry.value['abnormal_kind'] ?? 'belum dicatat'} · catatan ${entry.value['remarks'] ?? 'belum dicatat'}',
                  ),
              ],
              for (final entry
                  in (record['content']['observations'] as List)
                      .asMap()
                      .entries)
                Text(
                  '${routineObservationLabel(entry.key, record['method_code'] == 'RET_16C_72H')}: ${(entry.value as Map).entries.map((e) => '${routineCountLabels[e.key] ?? e.key}: ${e.value ?? 'belum dicatat'}').join(', ')}',
                ),
            ],
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${record['hybrid']} · ${record['stage_code']} · Revisi ${record['revision']}',
              ),
              Text(record['method_name'] as String),
              if (!reviewing) ...[download, detail],
              if (record['can_edit'] == true &&
                  AppConfig.canonicalWritesEnabled)
                OutlinedButton(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<bool>(
                        builder: (_) => RoutineDraftEditor(
                          record: record,
                          labSiteId: record['lab_site_id'] as String,
                          saveDraft: (args) => supabase
                              .schema(AppConfig.isolatedApiSchema)
                              .rpc<Map<String, dynamic>>(
                                'save_routine_lab_draft',
                                params: args,
                              ),
                        ),
                      ),
                    );
                    ref.invalidate(routineRecordProvider(draftId));
                    ref.invalidate(
                      routineDraftsProvider(record['lab_site_id'] as String),
                    );
                  },
                  child: const Text('Lanjut isi draft'),
                ),
              RoutineWorkflowCard(
                key: ValueKey(record['revision']),
                record: record,
                canWrite: AppConfig.canonicalWritesEnabled,
                reviewEvidence: reviewing
                    ? _reviewEvidence(record, detail)
                    : null,
                checkDraft: () => supabase
                    .schema(AppConfig.isolatedApiSchema)
                    .rpc<Map<String, dynamic>>(
                      'check_routine_lab_draft',
                      params: {
                        'p_draft_id': draftId,
                        'p_expected_revision': record['revision'],
                      },
                    ),
                sendCommand: (name, args) => supabase
                    .schema(AppConfig.isolatedApiSchema)
                    .rpc<Map<String, dynamic>>(name, params: args),
                onChanged: (result) async {
                  ref.invalidate(routineRecordProvider(draftId));
                  ref.invalidate(
                    routineDraftsProvider(record['lab_site_id'] as String),
                  );
                  final nextId = result['draft_id'] as String?;
                  if (nextId != null && nextId != draftId && context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => RoutineWorkflowScreen(draftId: nextId),
                      ),
                    );
                  }
                },
              ),
              if (reviewing) download,
            ],
          );
        },
      ),
    );
  }
}

class ApprovedRoutineResultsPanel extends ConsumerStatefulWidget {
  const ApprovedRoutineResultsPanel({super.key, required this.module});
  final String module;
  @override
  ConsumerState<ApprovedRoutineResultsPanel> createState() =>
      _ApprovedRoutineResultsPanelState();
}

class _ApprovedRoutineResultsPanelState
    extends ConsumerState<ApprovedRoutineResultsPanel> {
  bool opened = false;
  int offset = 0;
  @override
  Widget build(BuildContext context) {
    final query = (module: widget.module, offset: offset);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Hasil rutin Lab disetujui QA',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text(
              'Terpisah dari jumlah request Plant. Hanya hasil dalam cakupan Anda yang sudah disetujui ditampilkan. Bukan pelepasan lot.',
            ),
            OutlinedButton(
              onPressed: () {
                setState(() => opened = true);
                ref.invalidate(approvedRoutineProvider(query));
              },
              child: const Text('Muat hasil rutin Lab'),
            ),
            if (opened)
              ref
                  .watch(approvedRoutineProvider(query))
                  .when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => const Text(
                      'Hasil belum dimuat. Periksa koneksi; tidak dianggap kosong.',
                    ),
                    data: (page) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${page['total']} hasil disetujui dalam cakupan akun Anda.',
                        ),
                        for (final row
                            in (page['results'] as List)
                                .cast<Map<String, dynamic>>())
                          if (row['status'] == 'APPROVED')
                            ExpansionTile(
                              title: Text(
                                '${row['lot_code']} · ${row['method_name']}',
                              ),
                              children: [
                                Text(
                                  '${row['hybrid']} · ${row['stage_code']} · ${row['workflow']['run_code']}',
                                ),
                                RoutineSummaryCard(
                                  summary:
                                      row['workflow']['summary']
                                          as Map<String, dynamic>,
                                ),
                                Text(
                                  'Catatan QA: ${row['workflow']['review_reason']}',
                                ),
                                const Text(
                                  'Unduh catatan hasil melalui web Plant, bagian Hasil rutin Lab yang disetujui QA.',
                                ),
                              ],
                            ),
                        Wrap(
                          spacing: 12,
                          children: [
                            OutlinedButton(
                              onPressed: offset == 0
                                  ? null
                                  : () => setState(() => offset -= 50),
                              child: const Text('Hasil sebelumnya'),
                            ),
                            OutlinedButton(
                              onPressed: page['has_more'] == true
                                  ? () => setState(() => offset += 50)
                                  : null,
                              child: const Text('Hasil berikutnya'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

String routineObservationLabel(int index, bool ret) => ret
    ? 'Ulangan ${index + 1} · 100 benih'
    : 'Ulangan ${index ~/ 2 + 1}${index.isOdd ? 'b' : 'a'} · 50 benih';

Map<String, dynamic> emptyRoutineContent(String method, int replicates) => {
  'sample_reference': null,
  'received_at': null,
  'started_at': null,
  'final_at': null,
  'note': null,
  'replicate_count': replicates,
  'observations': List.generate(
    method == 'RET_16C_72H' ? replicates : replicates * 2,
    (_) => <String, dynamic>{
      for (final key
          in method == 'RET_16C_72H'
              ? ['radicle_at_least_2mm']
              : routineCountLabels.keys.where(
                  (k) => k != 'radicle_at_least_2mm',
                ))
        key: null,
    },
  ),
};
String routineWib(String? value) {
  if (value == null || value.isEmpty) return 'Belum diisi';
  final date = DateTime.parse(value).toUtc().add(const Duration(hours: 7));
  return '${date.toIso8601String().substring(0, 16).replaceFirst('T', ' ')} WIB';
}

class RoutineLabScreen extends ConsumerStatefulWidget {
  const RoutineLabScreen({super.key});
  @override
  ConsumerState<RoutineLabScreen> createState() => _RoutineLabScreenState();
}

class _RoutineLabScreenState extends ConsumerState<RoutineLabScreen> {
  final search = TextEditingController();
  String? site;
  String term = '';
  String? method;
  int offset = 0;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> openEditor(
    Map<String, dynamic> catalog,
    Map<String, dynamic> record,
  ) async {
    final goToReview = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => RoutineDraftEditor(
          record: {
            ...record,
            'can_edit':
                record['can_edit'] == true && AppConfig.canonicalWritesEnabled,
          },
          labSiteId: catalog['selected_lab_site_id'] as String,
          canOpenReview: true,
          saveDraft: (args) => supabase
              .schema(AppConfig.isolatedApiSchema)
              .rpc<Map<String, dynamic>>(
                'save_routine_lab_draft',
                params: args,
              ),
        ),
      ),
    );
    if (!mounted) return;
    final site = catalog['selected_lab_site_id'] as String;
    ref.invalidate(routineDraftsProvider(site));
    if (goToReview == true) {
      final draftId = record['id'] as String;
      ref.invalidate(routineRecordProvider(draftId));
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => RoutineWorkflowScreen(draftId: draftId),
        ),
      );
      if (mounted) ref.invalidate(routineDraftsProvider(site));
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = (site: site, search: term, offset: offset);
    return Scaffold(
      appBar: AppBar(title: const Text('Catatan uji rutin')),
      body: ref
          .watch(routineCatalogProvider(query))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Catatan rutin belum bisa dimuat. Periksa koneksi dan penugasan Lab. Antrean request Plant tetap tersedia.',
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(routineCatalogProvider(query)),
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
            ),
            data: (catalog) {
              final selectedSite = catalog['selected_lab_site_id'] as String;
              final methods = (catalog['methods'] as List)
                  .cast<Map<String, dynamic>>();
              final selectedMethod =
                  method ??
                  (methods
                              .where((m) => m['method_code'] == 'SAND_25C')
                              .firstOrNull ??
                          methods.first)['method_code']
                      as String;
              final lots = (catalog['lots'] as List)
                  .cast<Map<String, dynamic>>();
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const _RoutineNotice(),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: selectedSite,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Lab tempat pengujian',
                    ),
                    items: (catalog['lab_sites'] as List)
                        .cast<Map<String, dynamic>>()
                        .map(
                          (s) => DropdownMenuItem(
                            value: s['id'] as String,
                            child: Text(
                              s['site_name'] as String,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      site = value;
                      offset = 0;
                    }),
                  ),
                  const SizedBox(height: 16),
                  LabRevalidationPanel(
                    key: ValueKey('revalidation-$selectedSite'),
                    labSiteId: selectedSite,
                    onCreated: () =>
                        ref.invalidate(routineDraftsProvider(selectedSite)),
                  ),
                  Text(
                    'Catatan tersimpan',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  ref
                      .watch(routineDraftsProvider(selectedSite))
                      .when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => TextButton(
                          onPressed: () => ref.invalidate(
                            routineDraftsProvider(selectedSite),
                          ),
                          child: const Text('Daftar belum dimuat. Coba lagi'),
                        ),
                        data: (page) {
                          final drafts = (page['drafts'] as List)
                              .cast<Map<String, dynamic>>();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '${page['total']} catatan rutin. Terpisah dari jumlah request Plant.',
                              ),
                              if (drafts.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Text('Belum ada draft di Lab ini.'),
                                ),
                              for (final draft in drafts)
                                Card(
                                  child: Column(
                                    children: [
                                      ListTile(
                                        title: Text(
                                          '${draft['lot_code']} · ${routineWorkflowStatus(draft['status'] as String)}',
                                        ),
                                        subtitle: Text(
                                          '${draft['method_name']} · ${revalidationPurpose(draft)}\nRevisi ${draft['revision']} · ${routineWib(draft['updated_at'] as String)}',
                                        ),
                                        isThreeLine: true,
                                        onTap: () async {
                                          if (draft['workflow'] == null) {
                                            await openEditor(catalog, draft);
                                          } else {
                                            await Navigator.of(context).push(
                                              MaterialPageRoute<void>(
                                                builder: (_) =>
                                                    RoutineWorkflowScreen(
                                                      draftId:
                                                          draft['id'] as String,
                                                    ),
                                              ),
                                            );
                                            ref.invalidate(
                                              routineDraftsProvider(
                                                selectedSite,
                                              ),
                                            );
                                          }
                                        },
                                        trailing: const Icon(
                                          Icons.chevron_right,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          await Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  RoutineWorkflowScreen(
                                                    draftId:
                                                        draft['id'] as String,
                                                  ),
                                            ),
                                          );
                                          ref.invalidate(
                                            routineDraftsProvider(selectedSite),
                                          );
                                        },
                                        child: Text(
                                          draft['workflow'] == null
                                              ? 'Periksa / kirim ke QA'
                                              : 'Lihat hasil & pemeriksaan',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (page['has_more'] == true)
                                const Text(
                                  'Daftar APK menampilkan 50 draft terbaru. Halaman web menyediakan halaman berikutnya.',
                                ),
                              TextButton(
                                onPressed: () => ref.invalidate(
                                  routineDraftsProvider(selectedSite),
                                ),
                                child: const Text('Muat ulang draft'),
                              ),
                            ],
                          );
                        },
                      ),
                  const Divider(height: 32),
                  Text(
                    'Catatan baru',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (catalog['can_write'] != true ||
                      !AppConfig.canonicalWritesEnabled)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Akun QA dapat membaca draft. Pencatatan dilakukan Analis, bukan memakai akun QA.',
                      ),
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedMethod,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Metode untuk catatan baru',
                    ),
                    items: methods
                        .map(
                          (m) => DropdownMenuItem(
                            value: m['method_code'] as String,
                            child: Text(
                              m['method_name'] as String,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged:
                        catalog['can_write'] == true &&
                            AppConfig.canonicalWritesEnabled
                        ? (value) => setState(() => method = value)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: search,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      labelText: 'Cari kode lot atau hybrid',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => setState(() {
                      term = search.text.trim();
                      offset = 0;
                    }),
                  ),
                  OutlinedButton(
                    onPressed: () => setState(() {
                      term = search.text.trim();
                      offset = 0;
                    }),
                    child: const Text('Cari lot'),
                  ),
                  Text(
                    '${catalog['total']} lot sesuai pencarian. Pilih kode yang benar, bukan lot pengganti.',
                  ),
                  if (lots.isEmpty)
                    const Text(
                      'Lot tidak ditemukan. Periksa kode atau hubungi petugas master Plant.',
                    ),
                  for (final lot in lots)
                    Card(
                      child: ListTile(
                        title: Text(lot['lot_code'] as String),
                        subtitle: Text(
                          '${lot['hybrid']} · ${lot['stage_code']}\n${lot['plant_site']}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.add),
                        onTap:
                            catalog['can_write'] != true ||
                                !AppConfig.canonicalWritesEnabled
                            ? null
                            : () {
                                final selected = methods.firstWhere(
                                  (m) => m['method_code'] == selectedMethod,
                                );
                                openEditor(catalog, {
                                  ...lot,
                                  'id': const Uuid().v4(),
                                  'lot_id': lot['id'],
                                  'revision': 0,
                                  'method_code': selectedMethod,
                                  'method_name': selected['method_name'],
                                  'replicate_counts':
                                      selected['replicate_counts'] ??
                                      [selected['replicate_count']],
                                  'can_edit': true,
                                  'content': emptyRoutineContent(
                                    selectedMethod,
                                    selected['replicate_count'] as int,
                                  ),
                                });
                              },
                      ),
                    ),
                  Wrap(
                    spacing: 12,
                    children: [
                      OutlinedButton(
                        onPressed: offset == 0
                            ? null
                            : () => setState(() => offset -= 50),
                        child: const Text('Sebelumnya'),
                      ),
                      OutlinedButton(
                        onPressed: catalog['has_more'] != true
                            ? null
                            : () => setState(() => offset += 50),
                        child: const Text('Berikutnya'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
    );
  }
}

class _RoutineNotice extends StatelessWidget {
  const _RoutineNotice();
  @override
  Widget build(BuildContext context) => const LabHelp(
    text:
        'Uji rutin tidak memerlukan request atau pengiriman Plant. Simpan draft, periksa, lalu kirim ke QA. Revisi terkirim dikunci; persetujuan analisis bukan pelepasan lot. PDF/Excel per pengujian bisa diunduh dari Hasil & pemeriksaan.',
  );
}

class RoutineDraftEditor extends StatefulWidget {
  const RoutineDraftEditor({
    super.key,
    required this.record,
    required this.labSiteId,
    required this.saveDraft,
    this.loadSampleReferences,
    this.canOpenReview = false,
  });
  final Map<String, dynamic> record;
  final String labSiteId;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) saveDraft;
  final RoutineReferenceLoader? loadSampleReferences;
  final bool canOpenReview;
  @override
  State<RoutineDraftEditor> createState() => _RoutineDraftEditorState();
}

class _RoutineDraftEditorState extends State<RoutineDraftEditor> {
  final form = GlobalKey<FormState>();
  final identitySection = GlobalKey(),
      timeSection = GlobalKey(),
      countsSection = GlobalKey();
  late final Map<String, dynamic> content;
  late final TextEditingController sample;
  late final TextEditingController note;
  late final List<Map<String, TextEditingController>> counts;
  late int revision;
  int replicateChoiceRevision = 0;
  bool busy = false;
  bool allowExit = false;
  String? storedSignature;
  String? error;
  String? message;
  String? action;
  Map<String, dynamic>? lastArgs;
  bool get ret => widget.record['method_code'] == 'RET_16C_72H';
  bool get editable => widget.record['can_edit'] == true;
  String get signature => jsonEncode([
    content,
    sample.text.trim(),
    note.text.trim(),
    [for (final row in counts) row.values.map((c) => c.text).toList()],
  ]);
  @override
  void initState() {
    super.initState();
    revision = widget.record['revision'] as int;
    content = Map<String, dynamic>.from(widget.record['content'] as Map);
    if (!ret && revision == 0 && content['form'] == null) {
      content['form'] = emptyRoutineForm(
        widget.record['method_code'] as String,
        (content['observations'] as List).length,
      );
    }
    sample = TextEditingController(
      text: content['sample_reference'] as String? ?? '',
    );
    note = TextEditingController(text: content['note'] as String? ?? '');
    counts = (content['observations'] as List)
        .map(
          (row) => {
            for (final key
                in ret
                    ? ['radicle_at_least_2mm']
                    : routineCountLabels.keys.where(
                        (k) => k != 'radicle_at_least_2mm',
                      ))
              key: TextEditingController(
                text: (row as Map)[key]?.toString() ?? '',
              ),
          },
        )
        .toList();
    if (revision > 0) storedSignature = signature;
  }

  @override
  void dispose() {
    sample.dispose();
    note.dispose();
    for (final row in counts) {
      for (final c in row.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  Future<void> pickTime(String key) async {
    final initial = content[key] == null
        ? DateTime.now().toUtc().add(const Duration(hours: 7))
        : DateTime.parse(
            content[key] as String,
          ).toUtc().add(const Duration(hours: 7));
    final day = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().toUtc().add(const Duration(hours: 7)),
    );
    if (day == null || !mounted) return;
    final clock = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
    );
    if (clock == null || !mounted) return;
    setState(
      () => content[key] = DateTime.utc(
        day.year,
        day.month,
        day.day,
        clock.hour,
        clock.minute,
      ).subtract(const Duration(hours: 7)).toIso8601String(),
    );
  }

  Future<void> changeReplicates(int n) async {
    if (busy || revision > 0 || !editable || n == content['replicate_count']) {
      return;
    }
    final notes = (content['form'] as Map?)?['annotations'] as List? ?? [];
    if (counts.any((row) => row.values.any((c) => c.text.isNotEmpty)) ||
        notes.any(
          (row) => (row as Map).values.any(
            (v) => v != null && v.toString().trim().isNotEmpty,
          ),
        )) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ganti jumlah ulangan?'),
          content: const Text(
            'Hitungan dan catatan tiap subulangan yang belum disimpan akan dikosongkan. Label sampel dan waktu tetap.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Tetap rancangan lama'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ganti dan kosongkan hitungan'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (confirmed != true) {
        setState(() => replicateChoiceRevision++);
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      for (final row in counts) {
        for (final c in row.values) {
          c.dispose();
        }
      }
      counts.clear();
      final blank = emptyRoutineContent(
        widget.record['method_code'] as String,
        n,
      );
      content['replicate_count'] = n;
      content['observations'] = blank['observations'];
      if (content['form'] != null) {
        content['form'] = {
          ...Map<String, dynamic>.from(content['form'] as Map),
          'annotations': emptyRoutineForm(
            widget.record['method_code'] as String,
            (blank['observations'] as List).length,
          )['annotations'],
        };
      }
      replicateChoiceRevision++;
      for (final row in blank['observations'] as List) {
        counts.add({
          for (final key in (row as Map).keys)
            key as String: TextEditingController(),
        });
      }
      action = null;
      lastArgs = null;
      message = null;
      error = null;
    });
  }

  Future<void> save() async {
    if (busy || !editable) return;
    final valid = form.currentState!.validate();
    for (final row in counts) {
      for (final controller in row.values) {
        final text = controller.text;
        if (text.isNotEmpty) {
          final value = int.tryParse(text);
          if (value == null || value < 0 || value > (ret ? 100 : 50)) {
            setState(
              () => error =
                  'Periksa semua ulangan. Jumlah benih harus bilangan bulat 0–${ret ? 100 : 50}.',
            );
            return;
          }
        }
      }
    }
    if (!valid) {
      setState(() => error = 'Periksa kolom yang ditandai sebelum menyimpan.');
      return;
    }
    final snapshot = {
      ...content,
      'sample_reference': sample.text.trim().isEmpty
          ? null
          : sample.text.trim(),
      'note': note.text.trim().isEmpty ? null : note.text.trim(),
      'observations': [
        for (final row in counts)
          {
            for (final e in row.entries)
              e.key: e.value.text.isEmpty ? null : int.parse(e.value.text),
          },
      ],
    };
    final args = <String, dynamic>{
      'p_draft_id': widget.record['id'],
      'p_expected_revision': revision,
      'p_lab_site_id': widget.labSiteId,
      'p_lot_id': widget.record['lot_id'],
      'p_method_code': widget.record['method_code'],
      'p_content': snapshot,
    };
    // Stable action for unchanged retries; optimistic revision guards uncertain saves.
    if (lastArgs.toString() != args.toString()) {
      action = const Uuid().v4();
      lastArgs = args;
    }
    setState(() {
      busy = true;
      error = null;
      message = null;
    });
    try {
      final result = await widget.saveDraft({...args, 'p_action_id': action});
      if (!mounted) return;
      setState(() {
        revision = result['revision'] as int;
        storedSignature = signature;
        action = null;
        lastArgs = null;
        message =
            'Draft tersimpan di server · revisi $revision. Belum dikirim ke QA.';
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Belum dapat memastikan penyimpanan. Cek jumlah benih, urutan waktu dan koneksi. Coba simpan dengan isian sama. Jika draft sudah berubah, buka versi terbaru, jangan membuat catatan ganda.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> leave() async {
    if (busy) return;
    if (editable && signature != storedSignature) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tutup isian?'),
          content: const Text(
            'Perubahan sejak penyimpanan terakhir tidak ikut disimpan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Lanjut isi'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    closeEditor();
  }

  void closeEditor({bool goToReview = false}) {
    if (allowExit) return;
    FocusScope.of(context).unfocus();
    setState(() => allowExit = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, goToReview);
    });
  }

  void openReview() {
    if (!editable || busy || revision == 0) return;
    if (signature != storedSignature) {
      setState(() {
        message = null;
        error = 'Simpan perubahan sebelum membuka pemeriksaan QA.';
      });
      return;
    }
    closeEditor(goToReview: true);
  }

  Widget countField(MapEntry<String, TextEditingController> entry) {
    final limit = ret ? 100 : 50;
    return TextFormField(
      controller: entry.value,
      enabled: editable && !busy,
      decoration: InputDecoration(labelText: routineCountLabels[entry.key]),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.isEmpty) return null;
        final n = int.tryParse(value);
        return n == null || n < 0 || n > limit
            ? 'Isi bilangan bulat 0–$limit'
            : null;
      },
    );
  }

  Widget draftActions() {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 4,
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
                        : 'Revisi $revision tersimpan'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: error == null
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.error,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton(
                  key: const ValueKey('routine-save-draft'),
                  onPressed: busy ? null : save,
                  child: Text(busy ? 'Menyimpan…' : 'Simpan draft'),
                ),
                if (widget.canOpenReview && revision > 0)
                  TextButton(
                    onPressed: busy ? null : openReview,
                    child: const Text('Ke pemeriksaan QA'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy && (allowExit || !editable),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !busy) {
        leave();
      }
    },
    child: Scaffold(
      appBar: AppBar(
        toolbarHeight: LabLotTitle.toolbarHeight(context),
        title: LabLotTitle(
          lot: widget.record['lot_code'] as String,
          reference: 'Draft pengujian rutin',
        ),
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back),
          onPressed: busy ? null : leave,
        ),
      ),
      bottomNavigationBar:
          editable && MediaQuery.viewInsetsOf(context).bottom == 0
          ? draftActions()
          : null,
      body: Form(
        key: form,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.record['hybrid']} · ${widget.record['stage_code']}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('${widget.record['method_name']} · Revisi $revision'),
              Text('Jenis uji: ${revalidationPurpose(widget.record)}'),
              LabFormSections(
                sections: ['Identitas', 'Waktu (WIB)', 'Ulangan'],
                targets: [identitySection, timeSection, countsSection],
              ),
              RevalidationContextCard(record: widget.record),
              const SizedBox(height: 16),
              LabFormCard(
                key: identitySection,
                title: 'Identitas sampel & rancangan uji',
                icon: Icons.inventory_2_outlined,
                children: [
                  DropdownButtonFormField<int>(
                    key: ValueKey(
                      'routine-replicates-${content['replicate_count']}-$replicateChoiceRevision',
                    ),
                    initialValue: content['replicate_count'] as int,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Jumlah ulangan',
                    ),
                    items:
                        (widget.record['replicate_counts'] as List? ??
                                [content['replicate_count']])
                            .map(
                              (n) => DropdownMenuItem<int>(
                                value: n as int,
                                child: Text('$n × 100 benih'),
                              ),
                            )
                            .toList(),
                    onChanged: editable && !busy && revision == 0
                        ? (n) {
                            if (n != null) changeReplicates(n);
                          }
                        : null,
                  ),
                  const Text('Jumlah ulangan dikunci setelah simpan pertama.'),
                  const SizedBox(height: 16),
                  RoutineSampleReferenceField(
                    controller: sample,
                    enabled: editable && !busy,
                    locked:
                        widget.record['retest_of_run_id'] != null ||
                        (widget.record['revalidation']
                                as Map?)?['sample_plan'] ==
                            'RETAINED_LAB',
                    loadReferences:
                        widget.loadSampleReferences ??
                        (search, offset) => supabase
                            .schema(AppConfig.isolatedApiSchema)
                            .rpc<Map<String, dynamic>>(
                              'list_routine_sample_references',
                              params: {
                                'p_lab_site_id': widget.labSiteId,
                                'p_lot_id': widget.record['lot_id'],
                                'p_search': search,
                                'p_offset': offset,
                              },
                            ),
                  ),
                ],
              ),
              LabFormCard(
                key: timeSection,
                title: 'Waktu pengujian (WIB)',
                icon: Icons.schedule_outlined,
                children: [
                  for (final entry in {
                    'received_at': 'Sampel tersedia di Lab',
                    'started_at': ret
                        ? 'Mulai ditempatkan pada 16 °C'
                        : 'Mulai uji / tanam',
                    'final_at': 'Pengamatan final',
                  }.entries)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${entry.value} (WIB)'),
                      subtitle: Text(routineWib(content[entry.key] as String?)),
                      onTap:
                          editable &&
                              !busy &&
                              !(widget.record['retest_of_run_id'] != null &&
                                  entry.key == 'received_at')
                          ? () => pickTime(entry.key)
                          : null,
                      trailing:
                          editable &&
                              !busy &&
                              !(widget.record['retest_of_run_id'] != null &&
                                  entry.key == 'received_at')
                          ? IconButton(
                              tooltip: 'Kosongkan waktu',
                              icon: const Icon(Icons.clear),
                              onPressed: () =>
                                  setState(() => content[entry.key] = null),
                            )
                          : null,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (!ret && content['form'] != null)
                RoutineFormDetailsFields(
                  value: Map<String, dynamic>.from(content['form'] as Map),
                  enabled: editable && !busy,
                  germination: widget.record['method_code'] == 'SAND_25C',
                  onChanged: (value) => setState(() => content['form'] = value),
                )
              else if (!ret && editable)
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(
                          () => content['form'] = emptyRoutineForm(
                            widget.record['method_code'] as String,
                            counts.length,
                          ),
                        ),
                  child: const Text('Lengkapi rincian form cetak'),
                ),
              TextFormField(
                controller: note,
                enabled: editable && !busy,
                maxLength: 1000,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Catatan kondisi, alat, atau pekerjaan',
                ),
              ),
              Text(
                key: countsSection,
                ret
                    ? 'Radikula ≥2 mm · minimal 72 jam pada 16 °C sebelum kirim ke QA.'
                    : 'Kosong bukan nol. First count tidak ditambah ke final.',
              ),
              LabHelp(
                label: 'Cara isi hitungan',
                text: ret
                    ? 'RET memakai 4 × 100 benih. Jangan isi hitungan kecambah normal.'
                    : '${content['replicate_count']} × 100 benih; a/b masing-masing 50 benih. Catat fresh, hard, dan mati terpisah.',
              ),
              if (widget.record['retest_of_run_id'] != null)
                const Text(
                  'Uji ulang: sampel yang sama, waktu mulai baru sesudah keputusan QA.',
                ),
              const SizedBox(height: 10),
              for (var i = 0; i < counts.length; i++)
                Card(
                  child: ExpansionTile(
                    initiallyExpanded: i == 0,
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Text(routineObservationLabel(i, ret)),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!ret) ...[
                              countField(
                                MapEntry(
                                  'first_normal',
                                  counts[i]['first_normal']!,
                                ),
                              ),
                              const Divider(height: 28),
                              const LabLabel('Pengamatan final'),
                              const SizedBox(height: 10),
                            ],
                            LabFieldGrid(
                              fields: [
                                for (final entry in counts[i].entries)
                                  if (entry.key != 'first_normal')
                                    countField(entry),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _RoutineCountTotal(
                              ret: ret,
                              controllers: [
                                for (final entry in counts[i].entries)
                                  if (entry.key != 'first_normal') entry.value,
                              ],
                            ),
                            if (!ret && content['form'] != null)
                              for (final key in ['abnormal_kind', 'remarks'])
                                Padding(
                                  padding: const EdgeInsets.only(top: 14),
                                  child: TextFormField(
                                    key: ValueKey(
                                      'routine-form-$key-$i-$replicateChoiceRevision',
                                    ),
                                    initialValue:
                                        ((content['form'] as Map)['annotations']
                                                as List)[i][key]
                                            as String?,
                                    enabled: editable && !busy,
                                    maxLength: 300,
                                    minLines: 1,
                                    maxLines: 4,
                                    decoration: InputDecoration(
                                      labelText: key == 'abnormal_kind'
                                          ? 'Jenis abnormal'
                                          : 'Catatan subulangan',
                                    ),
                                    onChanged: (text) => setState(() {
                                      final details = Map<String, dynamic>.from(
                                        content['form'] as Map,
                                      );
                                      final notes = [
                                        for (final row
                                            in details['annotations'] as List)
                                          Map<String, dynamic>.from(row as Map),
                                      ];
                                      notes[i][key] = text.trim().isEmpty
                                          ? null
                                          : text;
                                      content['form'] = {
                                        ...details,
                                        'annotations': notes,
                                      };
                                    }),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _RoutineCountTotal extends StatelessWidget {
  const _RoutineCountTotal({required this.ret, required this.controllers});

  final bool ret;
  final List<TextEditingController> controllers;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge(controllers),
    builder: (context, _) {
      final numbers = controllers
          .map((controller) => int.tryParse(controller.text))
          .nonNulls
          .toList();
      final total = numbers.fold(0, (sum, n) => sum + n);
      final overflow = !ret && total > 50;
      final theme = Theme.of(context);
      final text = ret
          ? numbers.isEmpty
                ? 'Radikula: belum dicatat'
                : 'Radikula: $total/100 benih'
          : numbers.isEmpty
          ? 'Final: belum dicatat'
          : 'Final: $total/50 benih · ${numbers.length}/5 kategori terisi';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: overflow
              ? theme.colorScheme.errorContainer
              : theme.colorScheme.surfaceContainer,
        ),
        child: Text(
          overflow ? '$text\nJumlah melebihi 50 benih.' : text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: overflow
                ? theme.colorScheme.onErrorContainer
                : theme.colorScheme.onSurface,
          ),
        ),
      );
    },
  );
}
