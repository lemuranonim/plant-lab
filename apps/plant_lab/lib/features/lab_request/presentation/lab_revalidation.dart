import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/config/app_config.dart';
import '../../../core/database/supabase_client.dart';
import 'lab_workspace_widgets.dart';
import 'workflow_presentation.dart';

typedef RevalidationCommand =
    Future<Map<String, dynamic>> Function(
      String name,
      Map<String, dynamic> args,
    );
Future<Map<String, dynamic>> revalidationCommand(
  String name,
  Map<String, dynamic> args,
) async => supabase
    .schema(AppConfig.isolatedApiSchema)
    .rpc<Map<String, dynamic>>(name, params: args);

String revalidationSamplePlan(dynamic value) =>
    value == 'RETAINED_LAB' ? 'Sampel simpanan Lab' : 'Sampel baru';
String revalidationPurpose(Map record) {
  final v = record['revalidation'] as Map?;
  return v == null
      ? (record['retest_of_run_id'] == null ? 'Pengujian awal' : 'Uji ulang QA')
      : 'Revalidation ${v['stage']}${v['is_qa_retest'] == true ? ' · uji ulang QA' : ''}';
}

String revalidationWib(dynamic value) => value == null
    ? 'belum dicatat'
    : '${DateTime.parse(value as String).toUtc().add(const Duration(hours: 7)).toIso8601String().substring(0, 16).replaceFirst('T', ' ')} WIB';

class _RevalidationStageTrack extends StatelessWidget {
  const _RevalidationStageTrack(this.stage);

  final int? stage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      container: true,
      label: 'Tahap Revalidation',
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var n = 1; n <= 3; n++)
            Semantics(
              selected: n == stage,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: n == stage ? colors.primaryContainer : colors.surface,
                  border: Border.all(
                    color: n == stage ? colors.primary : colors.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Text(
                    'Tahap $n',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: n == stage
                          ? colors.onPrimaryContainer
                          : colors.onSurfaceVariant,
                      fontWeight: n == stage ? FontWeight.w700 : null,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class RevalidationContextCard extends StatelessWidget {
  const RevalidationContextCard({super.key, required this.record});
  final Map record;
  @override
  Widget build(BuildContext context) {
    final v = record['revalidation'] as Map?;
    if (v == null) return const SizedBox.shrink();
    return Card(
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.fact_check_outlined),
        title: Text(revalidationPurpose(record)),
        subtitle: Text("Rujukan uji: ${v['source_run_code']}"),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          LabFieldGrid(
            fields: [
              LabRecordValue(
                'Persetujuan',
                "${v['authorizer_name']} · ${revalidationWib(v['authorized_at'])}",
              ),
              LabRecordValue(
                'Label sumber',
                v['source_sample_reference']?.toString(),
              ),
              LabRecordValue('Alasan', v['reason']?.toString()),
              LabRecordValue(
                revalidationSamplePlan(v['sample_plan']),
                v['sample_evidence']?.toString(),
              ),
            ],
          ),
          if (v['is_qa_retest'] == true) ...[
            const SizedBox(height: 12),
            const Text(
              'Uji ulang QA tetap pada tahap ini, bukan Revalidation berikutnya.',
            ),
          ],
        ],
      ),
    );
  }
}

class LabRevalidationPanel extends StatefulWidget {
  const LabRevalidationPanel({
    super.key,
    required this.labSiteId,
    required this.onCreated,
    this.command = revalidationCommand,
  });
  final String labSiteId;
  final VoidCallback onCreated;
  final RevalidationCommand command;
  @override
  State<LabRevalidationPanel> createState() => _LabRevalidationPanelState();
}

class _LabRevalidationPanelState extends State<LabRevalidationPanel> {
  final search = TextEditingController();
  Map<String, dynamic>? options, page;
  bool busy = false;
  String? error, message;
  String applied = '';
  bool? showSources;
  bool get lookingAtSources =>
      showSources ?? (options?['can_authorize'] == true);
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load({
    int sourceOffset = 0,
    int planOffset = 0,
    String? term,
  }) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final query = term ?? applied;
      final result = await Future.wait([
        widget.command('get_lab_revalidation_options', {
          'p_lab_site_id': widget.labSiteId,
          'p_search': query,
          'p_offset': sourceOffset,
        }),
        widget.command('list_lab_revalidations', {
          'p_lab_site_id': widget.labSiteId,
          'p_offset': planOffset,
        }),
      ]);
      if (mounted) {
        setState(() {
          options = result[0];
          page = result[1];
          applied = query;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Revalidation belum dimuat. Periksa akses/koneksi lalu coba lagi. Ini bukan berarti daftar kosong.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> open(String mode, Map<String, dynamic> item) async {
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RevalidationActionScreen(
          mode: mode,
          item: item,
          labSiteId: widget.labSiteId,
          command: widget.command,
        ),
      ),
    );
    if (!mounted || completed != true) return;
    setState(
      () => message = mode == 'START'
          ? 'Catatan Revalidation disiapkan dengan hitungan kosong. Lanjut isi dari Catatan tersimpan.'
          : mode == 'AUTHORIZE'
          ? 'Persetujuan tersimpan. Analis perlu mencocokkan sampel fisik sebelum mulai.'
          : 'Persetujuan dibatalkan. Alasan tetap tersimpan.',
    );
    if (mode == 'START') widget.onCreated();
    await load();
  }

  void loadFromSearch() {
    final term = search.text.trim();
    if (term.isNotEmpty) setState(() => showSources = true);
    FocusScope.of(context).unfocus();
    load(term: term);
  }

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      leading: const Icon(Icons.fact_check_outlined),
      title: const Text('Revalidation 1–3'),
      subtitle: const Text('Persetujuan Admin Lab · cek sampel oleh Analis'),
      childrenPadding: const EdgeInsets.all(16),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ExpansionTile(
          shape: Border(),
          collapsedShape: Border(),
          tilePadding: EdgeInsets.zero,
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          title: Text('Cara kerja Revalidation'),
          children: [
            Text('Tahap berikutnya menunggu persetujuan QA pada hasil sumber.'),
            SizedBox(height: 8),
            Text(
              'Admin Lab memberi persetujuan manual per kasus, dengan alasan dan rencana sampel. Ini bukan jadwal otomatis atau pelepasan lot.',
            ),
            SizedBox(height: 8),
            Text(
              'Analis mencocokkan sampel fisik. Sampel simpanan harus memakai label sumber; sampel baru dicatat dengan label fisiknya. Tidak membuat pengiriman Plant atau menyalin angka lama.',
            ),
            SizedBox(height: 8),
            Text('Uji ulang QA tetap pada tahap yang sama.'),
            SizedBox(height: 12),
          ],
        ),
        TextField(
          controller: search,
          maxLength: 120,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            labelText: 'Cari lot, hybrid atau nomor uji sumber',
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: busy ? null : (_) => loadFromSearch(),
        ),
        OutlinedButton(
          onPressed: busy ? null : loadFromSearch,
          child: const Text('Muat Revalidation'),
        ),
        if (busy)
          const LinearProgressIndicator(semanticsLabel: 'Memuat Revalidation'),
        if (error != null)
          Semantics(
            liveRegion: true,
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (error != null && options != null)
          const Text('Daftar di bawah masih dari pemuatan terakhir.'),
        if (message != null) Semantics(liveRegion: true, child: Text(message!)),
        if (options != null && page != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Hasil sumber'),
                  selected: lookingAtSources,
                  onSelected: (_) => setState(() => showSources = true),
                ),
                ChoiceChip(
                  label: const Text('Persetujuan'),
                  selected: !lookingAtSources,
                  onSelected: (_) => setState(() => showSources = false),
                ),
              ],
            ),
          ),
        if (options != null && lookingAtSources) ...[
          if (options!['can_authorize'] != true)
            const Text(
              'Persetujuan hanya untuk petugas dengan wewenang Admin Revalidation. QA biasa atau Analis tidak otomatis menjadi Admin.',
            ),
          Text(
            'Sumber analisis yang disetujui QA · ${options!['total']}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if ((options!['candidates'] as List).isEmpty)
            const Text('Tidak ada hasil sumber pada halaman ini.'),
          const SizedBox(height: 10),
          for (final source
              in (options!['candidates'] as List).cast<Map<String, dynamic>>())
            _RevalidationSourceCard(
              source: source,
              canAuthorize:
                  options!['can_authorize'] == true &&
                  AppConfig.canonicalWritesEnabled,
              onAuthorize: busy ? null : () => open('AUTHORIZE', source),
            ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: busy || options!['offset'] == 0
                    ? null
                    : () => load(
                        sourceOffset: (options!['offset'] as int) - 50,
                        planOffset: page?['offset'] ?? 0,
                      ),
                child: const Text('Sumber sebelumnya'),
              ),
              TextButton(
                onPressed: busy || options!['has_more'] != true
                    ? null
                    : () => load(
                        sourceOffset: (options!['offset'] as int) + 50,
                        planOffset: page?['offset'] ?? 0,
                      ),
                child: const Text('Sumber berikutnya'),
              ),
            ],
          ),
        ],
        if (page != null && !lookingAtSources) ...[
          Text(
            'Persetujuan Revalidation · ${page!['total']}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if ((page!['authorizations'] as List).isEmpty)
            const Text('Belum ada persetujuan pada halaman ini.'),
          const SizedBox(height: 10),
          for (final item
              in (page!['authorizations'] as List).cast<Map<String, dynamic>>())
            _RevalidationPlanCard(
              item: item,
              onStart: busy ? null : () => open('START', item),
              onCancel: busy ? null : () => open('CANCEL', item),
            ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: busy || page!['offset'] == 0
                    ? null
                    : () => load(
                        sourceOffset: options?['offset'] ?? 0,
                        planOffset: (page!['offset'] as int) - 50,
                      ),
                child: const Text('Persetujuan sebelumnya'),
              ),
              TextButton(
                onPressed: busy || page!['has_more'] != true
                    ? null
                    : () => load(
                        sourceOffset: options?['offset'] ?? 0,
                        planOffset: (page!['offset'] as int) + 50,
                      ),
                child: const Text('Persetujuan berikutnya'),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _RevalidationSourceCard extends StatelessWidget {
  const _RevalidationSourceCard({
    required this.source,
    required this.canAuthorize,
    this.onAuthorize,
  });

  final Map<String, dynamic> source;
  final bool canAuthorize;
  final VoidCallback? onAuthorize;

  @override
  Widget build(BuildContext context) {
    final next = source['next_stage'] as int;
    final blocked = source['blocked_reason'] as String?;
    return LabFormCard(
      title: "${source['lot_code']} · ${source['hybrid']}",
      icon: Icons.inventory_2_outlined,
      hint: source['method_name']?.toString(),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            const WorkflowStatusBadge(
              status: 'APPROVED',
              label: 'Hasil sumber disetujui QA',
            ),
            LabLabel(
              next <= 3
                  ? 'Tahap berikutnya: Revalidation $next'
                  : 'Sudah mencapai Revalidation 3',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _RevalidationStageTrack(next),
        const SizedBox(height: 12),
        LabFieldGrid(
          fields: [
            LabRecordValue('Nomor uji sumber', source['run_code']?.toString()),
            LabRecordValue(
              'Label sampel',
              source['sample_reference']?.toString(),
            ),
          ],
        ),
        if (blocked != null) ...[
          const SizedBox(height: 12),
          LabRecordValue('Belum bisa diberi persetujuan', blocked),
        ] else if (canAuthorize) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onAuthorize,
            child: Text('Beri persetujuan Revalidation $next'),
          ),
        ],
      ],
    );
  }
}

class _RevalidationPlanCard extends StatelessWidget {
  const _RevalidationPlanCard({
    required this.item,
    this.onStart,
    this.onCancel,
  });

  final Map<String, dynamic> item;
  final VoidCallback? onStart, onCancel;

  @override
  Widget build(BuildContext context) {
    final (tone, label, note) = switch (item['status']) {
      'CANCELLED' => (
        'CANCELLED',
        'Dibatalkan',
        "Alasan pembatalan: ${item['cancellation_reason']}",
      ),
      'DRAFT_CREATED' => (
        'DRAFT',
        'Catatan sudah dibuat',
        'Buka catatan uji di Catatan tersimpan.',
      ),
      _ => ('IN_REVIEW', 'Menunggu cek sampel', null),
    };
    return LabFormCard(
      title: "${item['lot_code']} · Revalidation ${item['stage']}",
      icon: Icons.fact_check_outlined,
      hint: item['method_name']?.toString(),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: WorkflowStatusBadge(status: tone, label: label),
        ),
        if (note != null) ...[const SizedBox(height: 8), Text(note)],
        const SizedBox(height: 12),
        _RevalidationStageTrack(item['stage'] as int?),
        const SizedBox(height: 12),
        LabFieldGrid(
          fields: [
            LabRecordValue(
              'Nomor uji sumber',
              item['source_run_code']?.toString(),
            ),
            LabRecordValue(
              'Label sumber',
              item['sample_reference']?.toString(),
            ),
            LabRecordValue(
              revalidationSamplePlan(item['sample_plan']),
              item['sample_evidence']?.toString(),
            ),
          ],
        ),
        ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: EdgeInsets.zero,
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          title: const Text('Rincian persetujuan'),
          children: [
            LabFieldGrid(
              fields: [
                LabRecordValue(
                  'Disetujui oleh',
                  "${item['authorizer_name']} · ${revalidationWib(item['authorized_at'])}",
                ),
                LabRecordValue(
                  'Alasan Revalidation',
                  item['reason']?.toString(),
                ),
              ],
            ),
          ],
        ),
        if (item['can_start'] == true && AppConfig.canonicalWritesEnabled) ...[
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onStart,
            child: Text("Siapkan catatan Revalidation ${item['stage']}"),
          ),
        ],
        if (item['can_cancel'] == true && AppConfig.canonicalWritesEnabled)
          TextButton(
            onPressed: onCancel,
            child: const Text('Batalkan persetujuan yang belum dimulai'),
          ),
      ],
    );
  }
}

class RevalidationActionScreen extends StatefulWidget {
  const RevalidationActionScreen({
    super.key,
    required this.mode,
    required this.item,
    required this.labSiteId,
    this.command = revalidationCommand,
  });
  final String mode, labSiteId;
  final Map<String, dynamic> item;
  final RevalidationCommand command;
  @override
  State<RevalidationActionScreen> createState() =>
      _RevalidationActionScreenState();
}

class _RevalidationActionScreenState extends State<RevalidationActionScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      reason = TextEditingController(),
      evidence = TextEditingController(),
      reference = TextEditingController();
  String? plan, error, previous, action;
  DateTime? available;
  bool busy = false, confirmed = false;
  late int reps;
  bool get authorize => widget.mode == 'AUTHORIZE';
  bool get start => widget.mode == 'START';
  @override
  void initState() {
    super.initState();
    reps = widget.item['method_code'] == 'RET_16C_72H' ? 4 : 2;
    if (start && widget.item['sample_plan'] == 'RETAINED_LAB') {
      reference.text = widget.item['sample_reference'] as String;
    }
  }

  @override
  void dispose() {
    name.dispose();
    reason.dispose();
    evidence.dispose();
    reference.dispose();
    super.dispose();
  }

  Future<void> pickTime() async {
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    final day = await showDatePicker(
      context: context,
      initialDate: available ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(available ?? now),
    );
    if (time != null && mounted) {
      setState(
        () => available = DateTime.utc(
          day.year,
          day.month,
          day.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  String? requiredText(String? value) => (value?.trim().length ?? 0) < 2
      ? 'Isi sesuai petugas atau label yang nyata.'
      : null;

  int? get stage => widget.item[authorize ? 'next_stage' : 'stage'] as int?;
  bool get retained => widget.item['sample_plan'] == 'RETAINED_LAB';

  Future<void> save() async {
    if (busy ||
        !confirmed ||
        !AppConfig.canonicalWritesEnabled ||
        !form.currentState!.validate()) {
      return;
    }
    if (start && available == null) {
      setState(
        () =>
            error = 'Isi waktu sampel benar-benar tersedia untuk Revalidation.',
      );
      return;
    }
    final command = authorize
        ? 'authorize_lab_revalidation'
        : start
        ? 'start_lab_revalidation'
        : 'cancel_lab_revalidation';
    final args = <String, dynamic>{
      if (authorize) ...{
        'p_lab_site_id': widget.labSiteId,
        'p_source_run_id': widget.item['run_id'],
        'p_authorizer_name': name.text.trim(),
        'p_reason': reason.text.trim(),
        'p_sample_plan': plan,
        'p_sample_evidence': evidence.text.trim(),
      } else ...{
        'p_authorization_id': widget.item['id'],
        if (start) ...{
          'p_sample_reference': reference.text.trim(),
          'p_available_at': available!
              .subtract(const Duration(hours: 7))
              .toIso8601String(),
          'p_replicate_count': reps,
          'p_sample_confirmed': true,
        } else
          'p_reason': reason.text.trim(),
      },
    };
    final payload = jsonEncode({'command': command, ...args});
    if (previous != payload) {
      previous = payload;
      action = const Uuid().v4();
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.command(command, {...args, 'p_action_id': action});
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Belum terkonfirmasi. Cek akses, tahap, label dan waktu. Jika koneksi terputus, ulangi isian sama. Jika status sudah berubah, kembali lalu muat ulang daftar; jangan membuat catatan kedua.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: LabLotTitle.toolbarHeight(context),
      title: LabLotTitle(
        lot: widget.item['lot_code'].toString(),
        reference:
            'Revalidation $stage · ${authorize
                ? 'Persetujuan'
                : start
                ? 'Cek sampel'
                : 'Pembatalan'}',
      ),
    ),
    body: Form(
      key: form,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LabFormCard(
              title: 'Hasil sumber',
              icon: Icons.inventory_2_outlined,
              hint: widget.item['method_name']?.toString(),
              children: [
                _RevalidationStageTrack(stage),
                const SizedBox(height: 12),
                LabFieldGrid(
                  fields: [
                    LabRecordValue(
                      'Nomor uji sumber',
                      (widget.item['source_run_code'] ??
                              widget.item['run_code'])
                          ?.toString(),
                    ),
                    if (authorize)
                      LabRecordValue(
                        'Label sumber',
                        widget.item['sample_reference']?.toString(),
                      ),
                  ],
                ),
              ],
            ),
            if (!start)
              LabFormCard(
                title: authorize
                    ? 'Rencana Revalidation'
                    : 'Batalkan persetujuan',
                icon: authorize
                    ? Icons.assignment_outlined
                    : Icons.cancel_outlined,
                hint: authorize
                    ? 'Tentukan sumber sampel dan catat lokasi atau rujukannya. Analis akan mencocokkan sampel secara fisik.'
                    : 'Hanya persetujuan yang belum dimulai yang dapat dibatalkan.',
                children: [
                  if (authorize) ...[
                    TextFormField(
                      controller: name,
                      enabled: !busy,
                      maxLength: 120,
                      validator: requiredText,
                      decoration: const InputDecoration(
                        labelText: 'Nama pemberi persetujuan',
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: plan,
                      isExpanded: true,
                      itemHeight: null,
                      decoration: const InputDecoration(
                        labelText: 'Rencana sampel',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'RETAINED_LAB',
                          child: Text('Sampel simpanan Lab'),
                        ),
                        DropdownMenuItem(
                          value: 'NEW_SAMPLE',
                          child: Text('Sampel baru'),
                        ),
                      ],
                      validator: (v) =>
                          v == null ? 'Pilih rencana sampel.' : null,
                      onChanged: busy
                          ? null
                          : (v) => setState(() {
                              plan = v;
                              confirmed = false;
                            }),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: reason,
                    enabled: !busy,
                    maxLength: 1000,
                    minLines: 2,
                    maxLines: 6,
                    validator: (v) => (v?.trim().length ?? 0) < 3
                        ? 'Isi alasan yang jelas.'
                        : null,
                    decoration: InputDecoration(
                      labelText: authorize
                          ? 'Alasan Revalidation'
                          : 'Alasan pembatalan',
                    ),
                  ),
                  if (authorize) ...[
                    TextFormField(
                      controller: evidence,
                      enabled: !busy,
                      maxLength: 1000,
                      minLines: 2,
                      maxLines: 6,
                      validator: (v) => (v?.trim().length ?? 0) < 3
                          ? 'Isi rujukan sampel yang diperiksa.'
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Rujukan / lokasi / catatan sampel',
                      ),
                    ),
                  ],
                ],
              ),
            if (start)
              LabFormCard(
                title: 'Cocokkan sampel fisik',
                icon: Icons.qr_code_outlined,
                children: [
                  LabRecordValue(
                    revalidationSamplePlan(widget.item['sample_plan']),
                    widget.item['sample_evidence']?.toString(),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: reference,
                    enabled: !busy,
                    readOnly: retained,
                    maxLength: 120,
                    validator: requiredText,
                    decoration: InputDecoration(
                      labelText: 'Label sampel fisik',
                      prefixIcon: retained
                          ? const Icon(Icons.lock_outline)
                          : null,
                      hintText: retained
                          ? null
                          : 'Label pada kemasan sampel baru',
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Sampel tersedia untuk Revalidation (WIB)',
                    ),
                    subtitle: Text(
                      available == null
                          ? 'Belum diisi'
                          : '${available!.toIso8601String().substring(0, 16).replaceFirst('T', ' ')} WIB',
                    ),
                  ),
                  Tooltip(
                    message: 'Pilih waktu sampel tersedia',
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : pickTime,
                      icon: const Icon(Icons.calendar_month),
                      label: const Text('Pilih tanggal / jam'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: reps,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Jumlah ulangan',
                    ),
                    items:
                        (widget.item['method_code'] == 'SAND_25C'
                                ? [2, 4]
                                : [reps])
                            .map(
                              (n) => DropdownMenuItem(
                                value: n,
                                child: Text('$n × 100 benih'),
                              ),
                            )
                            .toList(),
                    onChanged: busy ? null : (v) => setState(() => reps = v!),
                  ),
                ],
              ),
            LabFormCard(
              title: 'Konfirmasi',
              icon: Icons.verified_outlined,
              children: [
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: confirmed,
                  onChanged: busy
                      ? null
                      : (v) => setState(() => confirmed = v ?? false),
                  title: Text(
                    authorize
                        ? 'Saya sudah memeriksa hasil sumber dan rencana sampel. Ini persetujuan pekerjaan baru, bukan hasil mutu.'
                        : start
                        ? 'Label dan sampel fisik sudah cocok. Hitungan dan waktu uji baru belum diisi.'
                        : 'Persetujuan belum dimulai. Alasan pembatalan tetap disimpan.',
                  ),
                ),
                FilledButton(
                  onPressed: busy || !confirmed
                      ? null
                      : () {
                          FocusScope.of(context).unfocus();
                          save();
                        },
                  child: Text(
                    busy
                        ? 'Menyimpan…'
                        : authorize
                        ? 'Simpan persetujuan'
                        : start
                        ? 'Siapkan catatan kosong'
                        : 'Simpan pembatalan',
                  ),
                ),
                if (error != null)
                  Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
