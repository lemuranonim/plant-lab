import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/access/access_context_provider.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../../core/config/app_variant.dart';
import '../../../core/config/app_config.dart';
import '../../../core/database/supabase_client.dart';
import 'workflow_presentation.dart';
import 'soft_launch_guide_screen.dart';
import 'routine_lab_screen.dart';
import 'moisture_lab_screen.dart';
import 'lab_logbook_screen.dart';
import 'lab_monitoring_screen.dart';
import 'plant_sample_request_screen.dart';
import 'standalone_request_actions.dart';
import 'standalone_sample_handoff.dart';
import 'standalone_germination.dart';
import 'standalone_vigour.dart';
import 'standalone_lot_reference.dart';
import 'provisional_quality_reference.dart';
import 'historical_quality_screen.dart';
import '../../plant_inspection/presentation/plant_operations_screen.dart';
import '../../plant_inspection/presentation/pi_quality_screen.dart';

final standaloneQualityReferenceProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
      final access = await ref.watch(accessContextProvider.future);
      if (access == null || !AppConfig.hostedPilot) return {};
      final catalog = await supabase
          .schema(AppConfig.isolatedApiSchema)
          .rpc<Map<String, dynamic>>('get_confirmed_lab_contracts');
      catalog['ret_enabled'] = (await supabase
          .schema(AppConfig.isolatedApiSchema)
          .rpc<Map<String, dynamic>>(
            'get_vigour_workflow_options_v2',
          ))['ret_enabled'];
      final rules = (catalog['rules'] as List).cast<Map<String, dynamic>>();
      if (rules.length != 8 ||
          !validQualityReferences(rules) ||
          (catalog['methods'] as List).length != 6) {
        throw StateError('Provisional reference is incomplete');
      }
      return catalog;
    });

typedef StandaloneQueueData = ({
  List<PreviewLabRequest> requests,
  bool pairLookupFailed,
  bool vigourLookupFailed,
});

Future<List<Map<String, dynamic>>?> _loadVigour(
  Map<String, dynamic> params,
) async {
  if (!AppConfig.hostedPilot) return const [];
  try {
    return (await supabase
            .schema(AppConfig.isolatedApiSchema)
            .rpc<List<dynamic>>('list_vigour_runs_v2', params: params))
        .cast<Map<String, dynamic>>();
  } catch (_) {
    return null;
  }
}

Future<Map<String, PreviewLotPair>?> _loadLotPairs(
  Map<String, dynamic> params,
) async {
  try {
    final rows = await supabase
        .schema(AppConfig.isolatedApiSchema)
        .rpc<List<dynamic>>('list_request_lot_pairs', params: params);
    return {
      for (final row in rows.cast<Map<String, dynamic>>())
        row['request_id'] as String: PreviewLotPair.fromJson(row),
    };
  } on Exception {
    // A missing reference must not hide the request or its own result.
    return null;
  }
}

final standaloneQueueProvider = FutureProvider.autoDispose<StandaloneQueueData>(
  (ref) async {
    final variant = ref.watch(appVariantProvider);
    final access = await ref.watch(accessContextProvider.future);
    if (access == null ||
        !variant.allows(access) ||
        (!access.modules.contains(variant.code) &&
            !access.modules.contains('PLATFORM'))) {
      return (
        requests: const <PreviewLabRequest>[],
        pairLookupFailed: false,
        vigourLookupFailed: false,
      );
    }
    final rows = await supabase
        .schema(AppConfig.isolatedApiSchema)
        .rpc<List<dynamic>>(
          'list_lab_requests',
          params: {'p_module': variant.code, 'p_limit': 50},
        );
    final requests = rows.cast<Map<String, dynamic>>();
    if (requests.isEmpty) {
      return (
        requests: const <PreviewLabRequest>[],
        pairLookupFailed: false,
        vigourLookupFailed: false,
      );
    }
    final params = {
      'p_module': variant.code,
      'p_request_ids': requests.map((row) => row['request_id']).toList(),
    };
    final pendingPairs = _loadLotPairs(params);
    final pendingVigour = _loadVigour(params);
    final handoffs = <String, Map<String, dynamic>>{};
    final germination = <String, Map<String, dynamic>>{};
    if (AppConfig.canonicalWritesEnabled) {
      final api = supabase.schema(AppConfig.isolatedApiSchema);
      final details = await Future.wait([
        api.rpc<List<dynamic>>('list_sample_handoffs', params: params),
        api.rpc<List<dynamic>>(
          AppConfig.hostedPilot
              ? 'list_germination_runs_v2'
              : 'list_germination_runs',
          params: params,
        ),
      ]);
      for (final row in details[0].cast<Map<String, dynamic>>()) {
        handoffs[row['request_id'] as String] = row;
      }
      for (final row in details[1].cast<Map<String, dynamic>>()) {
        germination[row['request_id'] as String] = row;
      }
    }
    final lotPairs = await pendingPairs;
    final vigour = await pendingVigour;
    return (
      requests: requests.map((row) {
        return PreviewLabRequest.fromJson(
          row,
          lotPair: lotPairs?[row['request_id']],
          handoff: handoffs[row['request_id']],
          germination: germination[row['request_id']],
          vigour:
              vigour
                  ?.where((run) => run['request_id'] == row['request_id'])
                  .toList() ??
              const [],
        );
      }).toList(),
      pairLookupFailed: lotPairs == null,
      vigourLookupFailed: vigour == null,
    );
  },
);

class PreviewLabRequest {
  const PreviewLabRequest({
    required this.requestId,
    required this.requestCode,
    required this.lotCode,
    required this.testCodes,
    required this.status,
    required this.requestedAt,
    required this.instruction,
    this.lotId,
    this.lotPair,
    this.handoff,
    this.germination,
    this.vigour = const [],
  });

  factory PreviewLabRequest.fromJson(
    Map<String, dynamic> json, {
    PreviewLotPair? lotPair,
    Map<String, dynamic>? handoff,
    Map<String, dynamic>? germination,
    List<Map<String, dynamic>> vigour = const [],
  }) {
    return PreviewLabRequest(
      requestId: json['request_id'] as String,
      requestCode: json['request_code'] as String,
      lotId: json['lot_id'] as String?,
      lotCode: json['lot_code'] as String?,
      testCodes: List<String>.from(json['test_codes'] as List),
      status: json['status'] as String,
      requestedAt: json['requested_at'] as String?,
      instruction: json['sampling_instruction'] as String?,
      lotPair: lotPair,
      handoff: handoff,
      germination: germination,
      vigour: vigour,
    );
  }

  final String requestId;
  final String requestCode;
  final String? lotId;
  final String? lotCode;
  final List<String> testCodes;
  final String status;
  final String? requestedAt;
  final String? instruction;
  final PreviewLotPair? lotPair;
  final Map<String, dynamic>? handoff;
  final Map<String, dynamic>? germination;
  final List<Map<String, dynamic>> vigour;

  SampleHandoffAction? actionFor(AppVariant variant) {
    if (!AppConfig.canonicalWritesEnabled) return null;
    if (variant.isPlant && status == 'ACCEPTED') {
      return SampleHandoffAction.prepare;
    }
    if (variant.isPlant && status == 'PREPARED' && handoff != null) {
      return SampleHandoffAction.send;
    }
    if (variant.isLab && status == 'SENT' && handoff != null) {
      return SampleHandoffAction.receive;
    }
    return null;
  }
}

class StandaloneQueueScreen extends ConsumerStatefulWidget {
  const StandaloneQueueScreen({super.key});
  @override
  ConsumerState<StandaloneQueueScreen> createState() =>
      _StandaloneQueueScreenState();
}

class _StandaloneQueueScreenState extends ConsumerState<StandaloneQueueScreen> {
  final search = TextEditingController();
  String filter = 'all';
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  List<Widget> _sampleWidgets(
    BuildContext context,
    WidgetRef ref,
    PreviewLabRequest request,
    AppVariant variant,
  ) {
    final action = request.actionFor(variant);
    final sampleCode = request.handoff?['sample_code'] as String?;
    final dispatch = request.handoff?['dispatch_code'];
    final sent = request.handoff?['sent_grams'];
    final dispatchCondition = request.handoff?['dispatch_condition'];
    final receipt = request.handoff?['receipt_code'];
    final received = request.handoff?['received_grams'];
    final receiptCondition = request.handoff?['receipt_condition'];
    return [
      if (sampleCode != null)
        ExpansionTile(
          title: const Text('Serah terima sampel · berat & label'),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText('Sampel: $sampleCode'),
            Text('Pengiriman: $dispatch'),
            Text('Berat dari Plant: $sent g · $dispatchCondition'),
            if (receipt != null)
              Text('Penerimaan: $receipt · $received g · $receiptCondition'),
          ],
        ),
      if (action != null)
        TextButton(
          onPressed: () async {
            final saved = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (_) => StandaloneHandoffDialog(
                requestId: request.requestId,
                action: action,
                sampleCode: sampleCode,
              ),
            );
            if (saved == true && context.mounted) {
              ref.invalidate(standaloneQueueProvider);
            }
          },
          child: Text(action.label),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final variant = ref.watch(appVariantProvider);
    final access = ref.watch(accessContextProvider).valueOrNull;
    final roles =
        access?.roles
            .where((r) => r.moduleCode == variant.code)
            .map((r) => r.roleCode)
            .toList() ??
        <String>[];
    final analyst = variant.isLab && roles.contains('LAB_ANALYST');
    final reviewer = variant.isLab && roles.contains('LAB_QA_APPROVER');
    final canAccept =
        AppConfig.canonicalWritesEnabled && variant.isLab && roles.isNotEmpty;
    final sites = access?.sites
        .where((s) => s.siteType == variant.code)
        .map((s) => s.siteName)
        .join(', ');
    final guide = workflowRoleGuide(variant.isPlant, roles);
    void history() {
      final requests =
          ref.read(standaloneQueueProvider).valueOrNull?.requests ?? [];
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => HistoricalQualityScreen(
            module: variant.code,
            requestLots: [
              for (final r in requests)
                if (r.lotId != null && r.lotCode != null)
                  {'id': r.lotId, 'lot_code': r.lotCode},
            ],
          ),
        ),
      );
    }

    Future<void> submitRequest() async {
      final code = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const StandaloneSubmitDialog(),
      );
      if (code != null && context.mounted) {
        ref.invalidate(standaloneQueueProvider);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Permintaan diajukan: $code')));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(variant.appName),
        actions: [
          IconButton(
            tooltip: 'Panduan uji',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SoftLaunchGuideScreen(
                  plant: variant.isPlant,
                  roles: roles,
                  sites: sites ?? 'Belum tersedia',
                ),
              ),
            ),
            icon: const Icon(Icons.help_outline),
          ),
          PopupMenuButton<String>(
            tooltip: 'Menu akun',
            onSelected: (value) {
              if (value == 'refresh') ref.invalidate(standaloneQueueProvider);
              if (value == 'logout') {
                ref.read(authNotifierProvider.notifier).signOut();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'refresh',
                child: Text('Muat ulang antrean'),
              ),
              PopupMenuItem(value: 'logout', child: Text('Keluar')),
            ],
          ),
        ],
      ),
      bottomNavigationBar: AppConfig.hostedPilot && access != null
          ? NavigationBar(
              selectedIndex: 0,
              onDestinationSelected: (index) {
                if (index == 1) {
                  if (variant.isPlant) {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PlantOperationsScreen(
                          userId: access.userId,
                          reviewer: roles.contains('PLANT_SPV'),
                        ),
                      ),
                    );
                  } else {
                    history();
                  }
                }
                if (index == 2) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PiQualityScreen(isPlant: variant.isPlant),
                    ),
                  );
                }
              },
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.science_outlined),
                  selectedIcon: Icon(Icons.science),
                  label: 'Permintaan',
                ),
                NavigationDestination(
                  icon: Icon(variant.isPlant ? Icons.edit_note : Icons.history),
                  label: variant.isPlant ? 'Input harian' : 'Histori Excel',
                ),
                NavigationDestination(
                  icon: const Icon(Icons.fact_check_outlined),
                  label: variant.isPlant ? 'Mutu PI' : 'Sumber Plant',
                ),
              ],
            )
          : null,
      body: ref
          .watch(standaloneQueueProvider)
          .when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Memuat antrean',
              ),
            ),
            error: (_, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 40),
                    const SizedBox(height: 16),
                    const Text(
                      'Antrean belum dapat dimuat. Periksa koneksi; data tidak dianggap kosong.',
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: () => ref.invalidate(standaloneQueueProvider),
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
            ),
            data: (queue) {
              final visible = queue.requests.where((r) {
                final codes = [
                  r.lotCode,
                  r.requestCode,
                  r.lotPair?.dssCode,
                  r.lotPair?.dcsCode,
                  ...r.testCodes.map(workflowTest),
                ].whereType<String>().join(' ').toLowerCase();
                return (filter == 'all' || workflowGroup(r.status) == filter) &&
                    codes.contains(search.text.trim().toLowerCase());
              }).toList();
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(standaloneQueueProvider);
                  await ref.read(standaloneQueueProvider.future);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      [
                        access?.primaryRoleName ?? 'Role belum tersedia',
                        if (sites?.isNotEmpty ?? false) sites!,
                      ].join(' · '),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      variant.isPlant
                          ? 'Permintaan & hasil Lab'
                          : 'Antrean pengujian Lab',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppConfig.hostedPilot
                          ? 'Pilot operasional · Online · Data asli'
                          : 'Preview lokal',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    WorkflowNote(
                      title: guide.title,
                      text: guide.text,
                      compact: true,
                    ),
                    if (AppConfig.canonicalWritesEnabled && variant.isPlant)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: FilledButton.icon(
                          onPressed: submitRequest,
                          icon: const Icon(Icons.add),
                          label: const Text('Ajukan Permintaan Uji'),
                        ),
                      ),
                    if (AppConfig.hostedPilot &&
                        variant.isLab &&
                        (analyst || reviewer))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const RoutineLabScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.edit_note),
                          label: const Text('Catatan uji rutin & QA'),
                        ),
                      ),
                    if (AppConfig.hostedPilot &&
                        variant.isLab &&
                        (analyst || reviewer))
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const MoistureLabScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.water_drop_outlined),
                        label: const Text('MC Lab · catatan draft'),
                      ),
                    if (AppConfig.hostedPilot &&
                        variant.isLab &&
                        (analyst || reviewer))
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const LabLogbookScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.menu_book_outlined),
                        label: const Text('Buku pengujian Lab'),
                      ),
                    if (AppConfig.hostedPilot &&
                        variant.isLab &&
                        (analyst || reviewer))
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const LabMonitoringScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.query_stats),
                        label: const Text('Pemantauan kerja Lab'),
                      ),
                    const SizedBox(height: 12),
                    if (AppConfig.plantSampleRequestsEnabled &&
                        (analyst ||
                            reviewer ||
                            (variant.isPlant &&
                                roles.any(
                                  (role) =>
                                      role == 'PLANT_OPERATOR' ||
                                      role == 'PLANT_SPV',
                                ))))
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                PlantSampleRequestScreen(module: variant.code),
                          ),
                        ),
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: Text(
                          variant.isLab
                              ? 'Permintaan sampel ke Plant'
                              : 'Permintaan sampel dari Lab',
                        ),
                      ),
                    if (AppConfig.hostedPilot && variant.isPlant)
                      const ApprovedRoutineResultsPanel(module: 'PLANT'),
                    TextField(
                      controller: search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Cari permintaan',
                        hintText: 'Kode lot atau nomor permintaan',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Hapus pencarian',
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(search.clear),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final entry in const {
                          'all': 'Semua',
                          'active': 'Dalam proses',
                          'review': 'Menunggu QA',
                          'approved': 'Disetujui',
                          'closed': 'Ditutup',
                        }.entries)
                          ChoiceChip(
                            label: Text(
                              '${entry.value} (${entry.key == 'all' ? queue.requests.length : queue.requests.where((r) => workflowGroup(r.status) == entry.key).length})',
                            ),
                            selected: filter == entry.key,
                            onSelected: (_) =>
                                setState(() => filter = entry.key),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        '${visible.length} dari ${queue.requests.length} permintaan · maksimal 50 terbaru',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    if (queue.pairLookupFailed)
                      const WorkflowNote(
                        title: 'Rujukan belum tersedia',
                        text:
                            'Rujukan DSS–DCS gagal dimuat. Muat ulang sebelum memeriksa pasangan lot.',
                      ),
                    if (queue.vigourLookupFailed)
                      const WorkflowNote(
                        title: 'Detail Vigor belum dimuat',
                        text: 'Muat ulang; hasil tidak dianggap kosong.',
                      ),
                    if (visible.isEmpty)
                      WorkflowNote(
                        title: queue.requests.isEmpty
                            ? 'Belum ada permintaan'
                            : 'Tidak ada hasil yang cocok',
                        text: queue.requests.isEmpty
                            ? 'Permintaan sesuai site dan role Anda akan tampil di sini. Tidak perlu membuat permintaan ulang hanya untuk mengisi antrean.'
                            : 'Periksa kode lot atau ubah filter status.',
                      ),
                    for (final request in visible)
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            StandaloneRequestHeading(
                              requestCode: request.requestCode,
                              status: request.status,
                              lotCode: request.lotCode,
                              pair: request.lotPair,
                              details: [
                                'Uji: ${request.testCodes.toSet().map(workflowTest).join(' · ')}',
                                if (request.requestedAt != null)
                                  'Tanggal: ${request.requestedAt!.split('T').first}',
                                if (request.instruction?.isNotEmpty ?? false)
                                  'Instruksi: ${request.instruction}',
                              ].join('\n'),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: WorkflowNote(
                                title: 'Langkah berikutnya',
                                text: workflowNextStep(
                                  request.status,
                                  variant.isPlant,
                                  reviewer: reviewer,
                                ),
                                compact: true,
                              ),
                            ),
                            if (canAccept && request.status == 'REQUESTED')
                              StandaloneAcceptButton(
                                key: ValueKey(request.requestId),
                                requestId: request.requestId,
                                onAccepted: () =>
                                    ref.invalidate(standaloneQueueProvider),
                              ),
                            ..._sampleWidgets(context, ref, request, variant),
                            if (request.testCodes.length == 1 &&
                                request.testCodes.single == 'GERMINATION')
                              StandaloneGermination(
                                requestId: request.requestId,
                                requestStatus: request.status,
                                run: request.germination,
                                analyst: analyst,
                                reviewer: reviewer,
                                onSaved: () =>
                                    ref.invalidate(standaloneQueueProvider),
                              ),
                            for (final run in request.vigour)
                              StandaloneVigour(
                                key: ValueKey(
                                  '${run['item_id']}:${run['run_id']}',
                                ),
                                run: run,
                                requestStatus: request.status,
                                analyst: analyst,
                                reviewer: reviewer,
                                onSaved: () =>
                                    ref.invalidate(standaloneQueueProvider),
                              ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Referensi & histori',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Acuan metode dan arsip Excel terpisah dari pekerjaan aktif.',
                    ),
                    if (AppConfig.hostedPilot && variant.isPlant)
                      OutlinedButton.icon(
                        onPressed: history,
                        icon: const Icon(Icons.history),
                        label: const Text('Histori Excel · baca-saja'),
                      ),
                    if (AppConfig.hostedPilot)
                      ref
                          .watch(standaloneQualityReferenceProvider)
                          .when(
                            data: (catalog) => catalog.isEmpty
                                ? const SizedBox.shrink()
                                : ProvisionalQualityReference(
                                    retEnabled: catalog['ret_enabled'] == true,
                                    rules: (catalog['rules'] as List)
                                        .cast<Map<String, dynamic>>(),
                                    methods: (catalog['methods'] as List)
                                        .cast<Map<String, dynamic>>(),
                                    vigourEnabled: (catalog['methods'] as List)
                                        .any(
                                          (m) =>
                                              m['method_code'] != 'SAND_25C' &&
                                              m['operational_workflow_enabled'] ==
                                                  true,
                                        ),
                                  ),
                            loading: () => const LinearProgressIndicator(),
                            error: (_, _) => const Text(
                              'Acuan belum bisa dimuat. Tidak menggunakan nilai tebakan.',
                            ),
                          ),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
    );
  }
}
