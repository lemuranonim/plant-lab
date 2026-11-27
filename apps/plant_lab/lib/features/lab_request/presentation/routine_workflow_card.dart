import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'lab_revalidation.dart';
import 'lab_workspace_widgets.dart';
import 'workflow_presentation.dart';

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
    return LabFormCard(
      title: 'Ringkasan hasil',
      icon: Icons.summarize_outlined,
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
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: WorkflowStatusBadge(
              status: summary['within_tolerance'] == true
                  ? 'IN_PROGRESS'
                  : 'IN_REVIEW',
              label: summary['within_tolerance'] == true
                  ? 'Dalam toleransi'
                  : summary['within_tolerance'] == false
                  ? 'Di luar toleransi; approval ditahan'
                  : 'Aturan toleransi belum tersedia; approval ditahan',
            ),
          ),
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
                  ? 'Ulangan ${entry.key + 1}: radikula minimal 2 mm · ${entry.value['radicle_at_least_2mm']}/100'
                  : 'Ulangan ${entry.key + 1}: Normal ${entry.value['normal']}, abnormal ${entry.value['abnormal']}, fresh ${entry.value['fresh']}, hard ${entry.value['hard']}, mati ${entry.value['dead']}',
            ),
          ),
        if (summary['elapsed_hours'] != null)
          Text(
            'RET: ${summary['elapsed_hours']} jam sejak penempatan pada 16 °C.',
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
    );
  }
}

String _toleranceLabel(dynamic within) => within == true
    ? 'Dalam toleransi'
    : within == false
    ? 'Di luar toleransi'
    : 'Batas toleransi belum tersedia';

class _RoutineReviewSummary extends StatelessWidget {
  const _RoutineReviewSummary(this.summary);

  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    final value = summary['germination_percent'] ?? summary['vigour_percent'];
    final reference =
        (summary['uac_quality_reference'] as Map?)?['minimum_percent'];
    final replicates = (summary['replicates'] as List).cast<Map>();
    final within = summary['within_tolerance'];
    final gap = summary['gap_pp'];
    final limit = summary['limit_pp'];
    return LabFormCard(
      title: 'Ringkasan hasil',
      icon: Icons.analytics_outlined,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: WorkflowStatusBadge(
            status: within == true ? 'IN_PROGRESS' : 'IN_REVIEW',
            label: _toleranceLabel(within),
          ),
        ),
        const SizedBox(height: 14),
        LabFieldGrid(
          maxColumns: 3,
          minFieldWidth: 132,
          fields: [
            LabRecordValue('Hasil analisis', value == null ? null : '$value%'),
            LabRecordValue(
              'Selisih ulangan',
              gap == null ? null : '$gap poin persentase',
            ),
            LabRecordValue(
              'Batas toleransi',
              limit == null ? 'Belum tersedia' : '$limit poin persentase',
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          '${replicates.length} × 100 benih · '
          '${reference is num ? 'Acuan minimum $reference%' : 'Acuan mutu belum lengkap'}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (summary['elapsed_hours'] != null)
          Text(
            'RET: ${summary['elapsed_hours']} jam sejak penempatan pada 16 °C.',
          ),
        const SizedBox(height: 8),
        for (final entry in replicates.asMap().entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Ulangan ${entry.key + 1}'),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  if (entry.value.containsKey('radicle_at_least_2mm'))
                    LabRecordValue(
                      'Radikula ≥2 mm',
                      entry.value['radicle_at_least_2mm'] == null
                          ? null
                          : "${entry.value['radicle_at_least_2mm']}/100",
                    )
                  else
                    for (final field in {
                      'normal': 'Normal',
                      'abnormal': 'Abnormal',
                      'fresh': 'Fresh',
                      'hard': 'Hard',
                      'dead': 'Mati',
                    }.entries)
                      LabRecordValue(
                        field.value,
                        entry.value[field.key]?.toString(),
                      ),
                ],
              ),
            ),
          ),
        ExpansionTile(
          title: const Text('Rujukan hitungan'),
          tilePadding: EdgeInsets.zero,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (summary['unrounded_percent'] != null)
              Text('Sebelum pembulatan: ${summary['unrounded_percent']}%'),
            Text(
              '${summary['calculation_code']} · versi ${summary['calculation_version']}. Final kumulatif, tidak ditambah first count.',
            ),
          ],
        ),
      ],
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
    this.reviewEvidence,
  });
  final Map<String, dynamic> record;
  final bool canWrite;
  final Future<Map<String, dynamic>> Function() checkDraft;
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
  sendCommand;
  final Future<void> Function(Map<String, dynamic>) onChanged;
  final Widget? reviewEvidence;
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
    final canApprove = summary?['within_tolerance'] == true;
    final canDecide =
        !busy &&
        confirmed &&
        reason.text.trim().length >= 3 &&
        (!formReview || reviewerName.text.trim().length >= 2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: WorkflowStatusBadge(
            status: record['status'] as String,
            label: routineWorkflowStatus(record['status'] as String),
          ),
        ),
        const SizedBox(height: 8),
        if (workflow != null)
          Text(
            '${workflow!['run_code']} · percobaan ${workflow!['attempt_no']}',
          ),
        if (summary != null)
          if (canReview)
            _RoutineReviewSummary(summary)
          else
            RoutineSummaryCard(summary: summary),
        if (canReview && widget.reviewEvidence != null) widget.reviewEvidence!,
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
        if (error != null && !canReview)
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
        if (canReview)
          LabFormCard(
            title: 'Pemeriksaan QA independen',
            icon: Icons.fact_check_outlined,
            children: [
              if (!canApprove)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    "${_toleranceLabel(summary?['within_tolerance'])}. Persetujuan ditahan; QA masih bisa meminta uji ulang.",
                  ),
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
              Text(
                'Keputusan ini untuk hasil analisis, bukan pelepasan lot.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: !canDecide || !canApprove
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
                onPressed: !canDecide
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
              if (error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        if (widget.canWrite && workflow?['can_retest'] == true)
          OutlinedButton(
            onPressed: busy
                ? null
                : () => command('create_routine_retest_draft', {
                    'p_run_id': workflow!['run_id'],
                  }),
            child: const Text('Buat catatan uji ulang'),
          ),
        if (!canReview)
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
