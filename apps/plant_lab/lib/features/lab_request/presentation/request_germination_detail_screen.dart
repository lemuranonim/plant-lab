import 'dart:convert';
import 'package:flutter/material.dart';
import 'lab_workspace_widgets.dart';
import 'package:uuid/uuid.dart';
import '../../../core/config/app_config.dart';
import '../../../core/database/supabase_client.dart';
import 'routine_lab_screen.dart';
import 'workflow_presentation.dart';

Map<String, dynamic> emptyRequestGerminationDetail() => {
  'version': 1,
  'available_at': null,
  'planted_at': null,
  'first_count_at': null,
  'final_at': null,
  'crop_species': null,
  'analyst_name': null,
  'temperature_text': '25',
  'note': null,
  'observations': List.generate(
    2,
    (_) => <String, dynamic>{
      'first_normal': null,
      'normal': null,
      'abnormal': null,
      'fresh': null,
      'hard': null,
      'dead': null,
      'abnormal_kind': null,
      'remarks': null,
    },
  ),
};
Future<Map<String, dynamic>> requestGerminationDetailCommand(
  String name,
  Map<String, dynamic> args,
) => supabase
    .schema(AppConfig.isolatedApiSchema)
    .rpc<Map<String, dynamic>>(name, params: args);

class RequestGerminationDetailScreen extends StatefulWidget {
  const RequestGerminationDetailScreen({
    super.key,
    required this.requestId,
    required this.runCode,
    required this.canApprove,
    this.vigour = false,
    this.command = requestGerminationDetailCommand,
  });
  final String requestId, runCode;
  final bool canApprove;
  final bool vigour;
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
  command;
  @override
  State<RequestGerminationDetailScreen> createState() =>
      _RequestGerminationDetailScreenState();
}

class _RequestGerminationDetailScreenState
    extends State<RequestGerminationDetailScreen> {
  static const countLabels = {
    'first_normal': 'Normal first count',
    'normal': 'Normal final',
    'abnormal': 'Abnormal',
    'fresh': 'Fresh',
    'hard': 'Hard',
    'dead': 'Mati',
  };
  static const textLabels = {
    'crop_species': 'Tanaman / spesies',
    'analyst_name': 'Nama Analis yang mengerjakan',
    'temperature_text': 'Suhu uji aktual (°C)',
    'note': 'Catatan kondisi / alat',
  };
  static const dateLabels = {
    'available_at': 'Sampel tersedia di Lab (WIB)',
    'planted_at': 'Mulai tanam aktual (WIB)',
    'first_count_at': 'Pengamatan first count (WIB)',
    'final_at': 'Pengamatan final aktual (WIB)',
  };
  Map<String, dynamic>? record, content;
  final fields = <String, TextEditingController>{},
      rows = <Map<String, TextEditingController>>[];
  final reviewer = TextEditingController(), reason = TextEditingController();
  final reviewSection = GlobalKey();
  final identitySection = GlobalKey(),
      timeSection = GlobalKey(),
      countsSection = GlobalKey(),
      saveSection = GlobalKey();
  bool busy = false, dirty = false, confirmed = false, changed = false;
  String decision = 'APPROVE';
  String? error, message, action, previous;
  String? feedbackAction;
  bool get editable =>
      record?['can_edit'] == true && AppConfig.canonicalWritesEnabled;
  bool get canReview =>
      record?['can_review'] == true && AppConfig.canonicalWritesEnabled;
  @override
  void initState() {
    super.initState();
    load();
  }

  void clearControllers() {
    for (final c in fields.values) {
      c.dispose();
    }
    fields.clear();
    for (final row in rows) {
      for (final c in row.values) {
        c.dispose();
      }
    }
    rows.clear();
  }

  @override
  void dispose() {
    clearControllers();
    reviewer.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> read() async {
    final r = await widget.command(
      'get_request_${widget.vigour ? 'vigour' : 'germination'}_detail',
      {'p_request_id': widget.requestId, 'p_run_code': widget.runCode},
    );
    if (!mounted) return;
    clearControllers();
    record = r;
    content = r['content'] == null
        ? (r['can_edit'] == true
              ? {
                  ...emptyRequestGerminationDetail(),
                  'temperature_text': widget.vigour ? null : '25',
                }
              : null)
        : Map<String, dynamic>.from(
            jsonDecode(jsonEncode(r['content'])) as Map,
          );
    if (content != null) {
      for (final k in textLabels.keys) {
        fields[k] = TextEditingController(text: content![k] as String?);
      }
      for (final raw in content!['observations'] as List) {
        final row = raw as Map;
        rows.add({
          for (final k in [...countLabels.keys, 'abnormal_kind', 'remarks'])
            k: TextEditingController(text: row[k]?.toString() ?? ''),
        });
      }
    }
    setState(() {});
  }

  Future<void> load() async {
    if (busy) return;
    if (dirty) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Muat ulang rincian?'),
          content: const Text('Perubahan yang belum disimpan akan hilang.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Muat ulang'),
            ),
          ],
        ),
      );
      if (yes != true) return;
    }
    if (!mounted) return;
    setState(() {
      busy = true;
      error = null;
      feedbackAction = null;
    });
    try {
      await read();
      if (mounted) {
        setState(() {
          dirty = false;
          confirmed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Rincian belum dimuat. Periksa koneksi dan akses, lalu coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void touch() => setState(() {
    dirty = true;
    confirmed = false;
    message = null;
  });
  Map<String, dynamic> collect() {
    final c = Map<String, dynamic>.from(content!);
    for (final e in fields.entries) {
      c[e.key] = e.value.text.trim().isEmpty ? null : e.value.text.trim();
    }
    c['observations'] = [
      for (final row in rows)
        {
          for (final e in row.entries)
            e.key: countLabels.containsKey(e.key)
                ? parseCount(e.value.text)
                : e.value.text.trim().isEmpty
                ? null
                : e.value.text.trim(),
        },
    ];
    return c;
  }

  int? parseCount(String value) {
    if (value.trim().isEmpty) return null;
    if (!RegExp(r'^\d{1,3}$').hasMatch(value.trim()) ||
        int.parse(value.trim()) > 100) {
      throw const FormatException(
        'Isi hitungan0–100; kosong hanya jika belum diamati.',
      );
    }
    return int.parse(value.trim());
  }

  Future<void> invoke(String operation) async {
    if (busy ||
        record == null ||
        content == null ||
        !AppConfig.canonicalWritesEnabled) {
      return;
    }
    if (operation == 'SAVE' && !editable ||
        operation == 'SUBMIT' &&
            (!editable ||
                dirty ||
                !confirmed ||
                record!['readiness']['ready'] != true) ||
        operation == 'REVIEW' &&
            (!canReview ||
                !confirmed ||
                reviewer.text.trim().isEmpty ||
                (widget.vigour && reason.text.trim().length < 3) ||
                (decision == 'RETEST' && reason.text.trim().isEmpty))) {
      return;
    }
    Map<String, dynamic> args;
    try {
      args = {
        'p_request_id': widget.requestId,
        'p_run_code': widget.runCode,
        'p_expected_revision': record!['revision'],
        if (operation == 'SAVE') 'p_content': collect(),
        if (operation == 'SUBMIT') 'p_confirmed': true,
        if (operation == 'REVIEW') ...{
          'p_decision': decision,
          'p_reviewer_name': reviewer.text.trim(),
          'p_reason': reason.text.trim().isEmpty ? null : reason.text.trim(),
        },
      };
    } on FormatException catch (e) {
      setState(() {
        feedbackAction = operation;
        error = e.message;
      });
      return;
    }
    final payload = jsonEncode({'operation': operation, ...args});
    if (previous != payload) {
      previous = payload;
      action = const Uuid().v4();
    }
    args['p_action_id'] = action;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      feedbackAction = operation;
      error = null;
      message = null;
    });
    try {
      await widget.command(
        operation == 'SAVE'
            ? 'save_request_${widget.vigour ? 'vigour' : 'germination'}_detail'
            : operation == 'SUBMIT'
            ? 'submit_request_${widget.vigour ? 'vigour' : 'germination'}_detail'
            : 'review_request_${widget.vigour ? 'vigour' : 'germination'}_detail',
        args,
      );
      await read();
      if (!mounted) return;
      setState(() {
        action = null;
        previous = null;
        dirty = false;
        confirmed = false;
        changed = true;
        message = operation == 'SAVE'
            ? 'Rincian tersimpan · revisi ${record!['revision']}.'
            : operation == 'SUBMIT'
            ? 'Revisi dikirim ke QA dan dikunci.'
            : decision == 'RETEST'
            ? 'QA meminta uji ulang. Percobaan ini tetap tersimpan.'
            : 'Analisis disetujui QA; bukan pelepasan lot.';
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Belum berhasil dikonfirmasi. Jika koneksi terputus, coba lagi dengan isian sama. '
              'Jika revisi, status atau percobaan berubah, muat ulang. Jangan membuat catatan kedua.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // If a successful action removes its own button, keep the result visible at the top.
  bool get feedbackAtTop => switch (feedbackAction) {
    'SAVE' || 'SUBMIT' => !editable,
    'REVIEW' => !canReview,
    _ => true,
  };

  Widget feedback() {
    if (error == null && message == null) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (message != null) Text(message!),
          ],
        ),
      ),
    );
  }

  Widget observationField({
    Key? key,
    required TextEditingController? controller,
    required String label,
    int? maxLength,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    if (!editable) return LabRecordValue(label, controller?.text, key: key);
    return TextField(
      key: key,
      controller: controller,
      enabled: !busy,
      maxLength: maxLength,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => touch(),
    );
  }

  Future<void> pick(String key) async {
    if (busy || !editable) return;
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
    content![key] = DateTime.utc(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    ).subtract(const Duration(hours: 7)).toIso8601String();
    touch();
  }

  AppBar _observationAppBar(BuildContext context) {
    final lot = record?['lot_code'] as String?;
    final title = 'Pengamatan ${widget.vigour ? 'Vigor' : 'Germinasi'}';
    return AppBar(
      toolbarHeight: lot == null ? null : LabLotTitle.toolbarHeight(context),
      title: lot == null
          ? Text(title)
          : LabLotTitle(lot: lot, reference: title),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !dirty && !busy,
    onPopInvokedWithResult: (popped, result) async {
      if (popped) return;
      if (busy) return;
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Tutup rincian?'),
          content: const Text('Perubahan yang belum disimpan akan hilang.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
      if (yes == true && context.mounted) {
        setState(() => dirty = false);
        Navigator.pop(context, changed);
      }
    },
    child: Scaffold(
      appBar: _observationAppBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.runCode),
            if (record != null)
              Text(
                'Sampel: ${record!['sample_reference']}\n${record!['request_code']} · ${record!['lab_name']}',
              ),
            if (widget.vigour && record != null)
              Text(
                'Mulai perlakuan: ${routineWib(record!["treatment_started_at"] as String?)}',
              ),
            if (busy) const LinearProgressIndicator(),
            if (feedbackAtTop) feedback(),
            TextButton(
              onPressed: busy ? null : load,
              child: const Text('Muat ulang rincian pengamatan'),
            ),
            if (record != null && content == null)
              const Text(
                'Catatan lama belum memiliki rincian aktual. '
                'Tanggal tanam, fresh/hard dan nama yang belum dicatat tidak dibuat otomatis; hasil lama tetap dipertahankan.',
              ),
            if (content != null) ...[
              Text(
                'Revisi tersimpan ${record!['revision']}${dirty ? ' · ada perubahan belum disimpan' : ''}',
              ),
              if (!editable)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    const LabLabel('Pengamatan · Baca saja'),
                    if (canReview)
                      const WorkflowStatusBadge(status: 'IN_REVIEW'),
                  ],
                ),
              LabFormSections(
                sections: [
                  'Identitas',
                  'Waktu (WIB)',
                  'Ulangan',
                  if (editable) 'Ke tombol simpan',
                  if (canReview) 'Ke keputusan QA',
                ],
                targets: [
                  identitySection,
                  timeSection,
                  countsSection,
                  if (editable) saveSection,
                  if (canReview) reviewSection,
                ],
              ),
              if (editable)
                LabHelp(
                  text:
                      'Isi waktu kejadian aktual. Normal + abnormal + fresh + hard + mati = 100 tiap ulangan.'
                      '${widget.vigour ? ' Tanggal tanam berbeda dari mulai perlakuan. Isi suhu aktual, bukan otomatis 25 °C.' : ''}',
                ),
              LabFormCard(
                key: identitySection,
                title: 'Identitas pengujian',
                icon: Icons.badge_outlined,
                children: [
                  for (final e in textLabels.entries)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: observationField(
                        controller: fields[e.key],
                        maxLength: e.key == 'note' ? 1000 : 120,
                        maxLines: e.key == 'note' ? 3 : 1,
                        label: e.value,
                      ),
                    ),
                ],
              ),
              LabFormCard(
                key: timeSection,
                title: 'Waktu pengujian (WIB)',
                icon: Icons.schedule_outlined,
                children: [
                  for (final e in dateLabels.entries)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LabRecordValue(
                            e.value,
                            routineWib(content![e.key] as String?),
                          ),
                          if (editable)
                            Wrap(
                              children: [
                                TextButton.icon(
                                  onPressed: busy ? null : () => pick(e.key),
                                  icon: const Icon(Icons.calendar_month),
                                  label: const Text('Pilih tanggal / jam'),
                                ),
                                if (content![e.key] != null)
                                  TextButton(
                                    onPressed: busy
                                        ? null
                                        : () {
                                            content![e.key] = null;
                                            touch();
                                          },
                                    child: const Text('Hapus waktu'),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                ],
              ),
              for (final (i, row) in rows.indexed)
                LabFormCard(
                  key: i == 0 ? countsSection : null,
                  title: 'Ulangan ${i + 1} · 100 benih',
                  icon: Icons.grass_outlined,
                  hint: i == 0
                      ? 'Kosong bukan nol. First count tidak ditambah ke final.'
                      : null,
                  children: [
                    LabFieldGrid(
                      fields: [
                        for (final e in countLabels.entries)
                          observationField(
                            key: ValueKey('request-count-$i-${e.key}'),
                            controller: row[e.key],
                            keyboardType: TextInputType.number,
                            label: e.value,
                          ),
                      ],
                    ),
                    for (final k in ['abnormal_kind', 'remarks'])
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: observationField(
                          controller: row[k],
                          maxLength: 500,
                          maxLines: 2,
                          label: k == 'remarks'
                              ? 'Catatan ulangan'
                              : editable
                              ? 'Jenis abnormal (wajib bila abnormal > 0)'
                              : 'Jenis abnormal',
                        ),
                      ),
                  ],
                ),
              if (editable)
                FilledButton(
                  key: saveSection,
                  onPressed: busy ? null : () => invoke('SAVE'),
                  child: const Text('Simpan rincian pengamatan'),
                ),
              if (editable && feedbackAction == 'SAVE') feedback(),
              if (record!['reviewer_name'] != null)
                Text('Nama pemeriksa QA: ${record!['reviewer_name']}'),
              if (editable) ...[
                const Text('Kirim ke QA dari revisi tersimpan.'),
                for (final b in record!['readiness']['blockers'] as List)
                  Text('$b'),
                for (final w in record!['readiness']['warnings'] as List)
                  Text('$w'),
                if (dirty)
                  const Text('Simpan perubahan dahulu sebelum mengirim.'),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: confirmed,
                  onChanged:
                      busy ||
                          dirty ||
                          record!['revision'] == 0 ||
                          record!['readiness']['ready'] != true
                      ? null
                      : (v) => setState(() => confirmed = v == true),
                  title: const Text(
                    'Saya sudah memeriksa revisi tersimpan dan pengamatan ini benar-benar dilakukan.',
                  ),
                ),
                FilledButton(
                  onPressed:
                      busy ||
                          dirty ||
                          !confirmed ||
                          record!['readiness']['ready'] != true
                      ? null
                      : () => invoke('SUBMIT'),
                  child: const Text('Kirim revisi ini ke QA'),
                ),
                if (feedbackAction == 'SUBMIT') feedback(),
              ],
              if (canReview)
                LabFormCard(
                  key: reviewSection,
                  title: 'Pemeriksaan QA · revisi ${record!['revision']}',
                  icon: Icons.fact_check_outlined,
                  hint:
                      'Persetujuan ini untuk hasil analisis, bukan pelepasan lot.',
                  children: [
                    TextField(
                      controller: reviewer,
                      enabled: !busy,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'Nama pemeriksa QA',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: decision,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Keputusan QA',
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'APPROVE',
                          enabled: widget.canApprove,
                          child: const Text('Setujui analisis'),
                        ),
                        const DropdownMenuItem(
                          value: 'RETEST',
                          child: Text('Minta uji ulang'),
                        ),
                      ],
                      onChanged: busy
                          ? null
                          : (v) => setState(() {
                              decision = v!;
                              confirmed = false;
                            }),
                    ),
                    TextField(
                      controller: reason,
                      enabled: !busy,
                      maxLength: 500,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Catatan QA / alasan uji ulang',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (!widget.canApprove)
                      const Text(
                        'Approval ditahan karena toleransi tidak tersedia atau terlampaui. Pilih uji ulang dengan alasan.',
                      ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: confirmed,
                      onChanged: busy
                          ? null
                          : (v) => setState(() => confirmed = v == true),
                      title: const Text(
                        'Saya sudah memeriksa identitas, waktu aktual dan seluruh pengamatan. Persetujuan analisis bukan pelepasan lot.',
                      ),
                    ),
                    FilledButton(
                      onPressed:
                          busy ||
                              !confirmed ||
                              reviewer.text.trim().isEmpty ||
                              (widget.vigour &&
                                  reason.text.trim().length < 3) ||
                              (decision == 'RETEST'
                                  ? reason.text.trim().isEmpty
                                  : !widget.canApprove)
                          ? null
                          : () => invoke('REVIEW'),
                      child: const Text('Simpan keputusan QA'),
                    ),
                    if (feedbackAction == 'REVIEW') feedback(),
                  ],
                ),
            ],
          ],
        ),
      ),
    ),
  );
}
