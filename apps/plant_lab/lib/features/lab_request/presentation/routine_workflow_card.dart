import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'lab_revalidation.dart';

String routineWorkflowStatus(String code) =>
    const {
      'DRAFT': 'Draft',
      'IN_REVIEW': 'Menunggu QA',
      'APPROVED': 'Analisis disetujui',
      'RETEST': 'QA meminta uji ulang',
    }[code] ??
    code;

class RoutineSummaryCard extends StatelessWidget {
  const RoutineSummaryCard({super.key, required this.summary});
  final Map<String, dynamic> summary;
  @override
  Widget build(BuildContext context) {
    final value = summary['germination_percent'] ?? summary['vigour_percent'];
    final reference = summary['uac_quality_reference'] as Map?;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hasil analisis: $value%',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text('Sebelum pembulatan: ${summary['unrounded_percent']}%'),
            Text(
              '${(summary['replicates'] as List).length} × 100 benih · toleransi ${(summary['replicates'] as List).length} ulangan',
            ),
            Text(
              'Selisih: ${summary['gap_pp']} poin persentase · batas: ${summary['limit_pp'] ?? 'belum tersedia'}',
            ),
            Text(
              summary['within_tolerance'] == true
                  ? 'Dalam toleransi'
                  : summary['within_tolerance'] == false
                  ? 'Di luar toleransi; approval ditahan'
                  : 'Aturan toleransi belum tersedia; approval ditahan',
            ),
            if (reference?['minimum_percent'] != null)
              Text(
                'Acuan minimum ${reference!['minimum_percent']}%. Persetujuan analisis bukan pelepasan lot.',
              )
            else
              const Text(
                'Klasifikasi programme/acuan belum lengkap. Tidak menerbitkan lulus spesifikasi atau pelepasan lot.',
              ),
            const SizedBox(height: 12),
            for (final entry in (summary['replicates'] as List).asMap().entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  (entry.value as Map).containsKey('radicle_at_least_2mm')
                      ? 'Ulangan ${entry.key + 1}: radikula minimal2mm ${entry.value['radicle_at_least_2mm']}/100'
                      : 'Ulangan ${entry.key + 1}: Normal ${entry.value['normal']}, abnormal ${entry.value['abnormal']}, fresh ${entry.value['fresh']}, hard ${entry.value['hard']}, mati ${entry.value['dead']}',
                ),
              ),
            if (summary['elapsed_hours'] != null)
              Text(
                'RET: ${summary['elapsed_hours']} jam sejak penempatan pada16°C.',
              ),
            ExpansionTile(
              title: const Text('Rujukan hitungan'),
              tilePadding: EdgeInsets.zero,
              children: [
                Text(
                  '${summary['calculation_code']} · versi ${summary['calculation_version']}. Final kumulatif, tidak ditambah first count.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RoutineWorkflowCard extends StatefulWidget {
  const RoutineWorkflowCard({
    super.key,
    required this.record,
    required this.canWrite,
    required this.checkDraft,
    required this.sendCommand,
    required this.onChanged,
  });
  final Map<String, dynamic> record;
  final bool canWrite;
  final Future<Map<String, dynamic>> Function() checkDraft;
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
  sendCommand;
  final Future<void> Function(Map<String, dynamic>) onChanged;
  @override
  State<RoutineWorkflowCard> createState() => _RoutineWorkflowCardState();
}

class _RoutineWorkflowCardState extends State<RoutineWorkflowCard> {
  Map<String, dynamic>? readiness;
  final reason = TextEditingController();
  final reviewerName = TextEditingController();
  bool get formReview =>
      (widget.record['content'] as Map?)?['form']?['version'] == 1;
  bool busy = false;
  bool confirmed = false;
  String? error;
  String? action;
  String? previousPayload;
  Map<String, dynamic>? get workflow =>
      widget.record['workflow'] as Map<String, dynamic>?;
  @override
  void dispose() {
    reason.dispose();
    reviewerName.dispose();
    super.dispose();
  }

  Future<void> inspect() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      confirmed = false;
    });
    try {
      final result = await widget.checkDraft();
      if (mounted) setState(() => readiness = result);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Pemeriksaan belum dimuat. Muat ulang revisi tersimpan dan cek koneksi.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> command(String name, Map<String, dynamic> args) async {
    if (busy || !widget.canWrite) return;
    final payload = jsonEncode({'name': name, 'args': args});
    if (previousPayload != payload) {
      previousPayload = payload;
      action = const Uuid().v4();
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.sendCommand(name, {
        ...args,
        'p_action_id': action,
      });
      if (!mounted) return;
      action = null;
      previousPayload = null;
      readiness = null;
      confirmed = false;
      reason.clear();
      await widget.onChanged(result);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Aksi belum terkonfirmasi. Periksa revisi, status, role, waktu dan toleransi. Ulangi aksi yang sama untuk memastikan; jangan membuat catatan ganda.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final summary = workflow?['summary'] as Map<String, dynamic>?;
    final canReview = widget.canWrite && workflow?['can_review'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          routineWorkflowStatus(record['status'] as String),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (workflow != null)
          Text(
            '${workflow!['run_code']} · percobaan ${workflow!['attempt_no']}',
          ),
        if (summary != null) RoutineSummaryCard(summary: summary),
        RevalidationContextCard(record: record),
        if (workflow?['review_reason'] != null)
          Text('Catatan QA: ${workflow!['review_reason']}'),
        if (workflow != null)
          ExpansionTile(
            title: const Text('Jejak pencatatan'),
            tilePadding: EdgeInsets.zero,
            children: [
              SelectableText(
                'ID Analis: ${workflow!['analyst_id']}\nID QA: ${workflow!['reviewer_id'] ?? 'belum ada'}\nRun sebelumnya: ${workflow!['parent_run_id'] ?? 'pengujian awal'}',
              ),
            ],
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (workflow == null &&
            record['can_edit'] == true &&
            widget.canWrite) ...[
          Text(
            'Pemeriksaan memakai revisi ${record['revision']} yang sudah tersimpan, bukan perubahan yang belum disimpan.',
          ),
          OutlinedButton(
            onPressed: busy ? null : inspect,
            child: const Text('Periksa sebelum kirim ke QA'),
          ),
        ],
        if (readiness != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    readiness!['ready'] == true
                        ? 'Lengkap untuk dikirim'
                        : 'Masih perlu dilengkapi',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final b in readiness!['blockers'] as List)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text((b as Map)['message'] as String),
                    ),
                  for (final w in readiness!['warnings'] as List)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(w as String),
                    ),
                  if (readiness!['summary'] != null)
                    RoutineSummaryCard(
                      summary: readiness!['summary'] as Map<String, dynamic>,
                    ),
                  const Text(
                    'Setelah dikirim, revisi dikunci. Koreksi dan uji ulang mengikuti keputusan QA, tidak menimpa angka lama.',
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: confirmed,
                    onChanged: busy
                        ? null
                        : (v) => setState(() => confirmed = v ?? false),
                    title: const Text(
                      'Saya memastikan sampel tersedia di Lab dan pengamatan ini nyata, bukan latihan.',
                    ),
                  ),
                  FilledButton(
                    onPressed: busy || !confirmed || readiness!['ready'] != true
                        ? null
                        : () => command('submit_routine_lab_draft', {
                            'p_draft_id': record['id'],
                            'p_expected_revision': readiness!['revision'],
                            'p_actual_work_confirmed': confirmed,
                          }),
                    child: const Text('Kirim revisi ini ke QA'),
                  ),
                ],
              ),
            ),
          ),
        if (canReview) ...[
          const SizedBox(height: 16),
          Text(
            'Pemeriksaan QA independen',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          TextField(
            controller: reason,
            enabled: !busy,
            maxLength: 1000,
            minLines: 2,
            maxLines: 5,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Catatan pemeriksaan / alasan uji ulang',
            ),
          ),
          if (formReview)
            TextField(
              controller: reviewerName,
              enabled: !busy,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Nama pemeriksa pada form',
              ),
              onChanged: (_) => setState(() {}),
            ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: confirmed,
            onChanged: busy
                ? null
                : (v) => setState(() => confirmed = v ?? false),
            title: const Text(
              'Saya sudah memeriksa identitas sampel, hitungan, kondisi, waktu nyata, dan toleransi.',
            ),
          ),
          FilledButton(
            onPressed:
                busy ||
                    !confirmed ||
                    reason.text.trim().length < 3 ||
                    (formReview && reviewerName.text.trim().length < 2) ||
                    summary?['within_tolerance'] != true
                ? null
                : () => command(
                    formReview
                        ? 'review_routine_lab_form_result'
                        : 'review_routine_lab_result',
                    {
                      'p_run_id': workflow!['run_id'],
                      'p_decision': 'APPROVE',
                      'p_reason': reason.text,
                      'p_protocol_checked': confirmed,
                      if (formReview)
                        'p_reviewer_name': reviewerName.text.trim(),
                    },
                  ),
            child: const Text('Setujui analisis'),
          ),
          OutlinedButton(
            onPressed:
                busy ||
                    !confirmed ||
                    reason.text.trim().length < 3 ||
                    (formReview && reviewerName.text.trim().length < 2)
                ? null
                : () => command(
                    formReview
                        ? 'review_routine_lab_form_result'
                        : 'review_routine_lab_result',
                    {
                      'p_run_id': workflow!['run_id'],
                      'p_decision': 'RETEST',
                      'p_reason': reason.text,
                      'p_protocol_checked': confirmed,
                      if (formReview)
                        'p_reviewer_name': reviewerName.text.trim(),
                    },
                  ),
            child: const Text('Minta uji ulang'),
          ),
        ],
        if (widget.canWrite && workflow?['can_retest'] == true)
          OutlinedButton(
            onPressed: busy
                ? null
                : () => command('create_routine_retest_draft', {
                    'p_run_id': workflow!['run_id'],
                  }),
            child: const Text('Buat catatan uji ulang'),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Persetujuan berlaku untuk analisis ini, bukan pelepasan lot. Unduhan memakai revisi yang sudah tersimpan.',
          ),
        ),
      ],
    );
  }
}
