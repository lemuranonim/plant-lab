import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/config/app_config.dart';
import '../../../core/database/supabase_client.dart';
import 'lab_workspace_widgets.dart';

String moistureStatus(dynamic status) =>
    const {
      'DRAFT': 'Draft',
      'IN_REVIEW': 'Menunggu verifikasi QA',
      'RETURNED': 'Dikembalikan untuk diperbaiki',
      'VERIFIED_RECORD': 'Catatan diverifikasi QA',
    }[status] ??
    'Status belum dimuat';

Future<void> moistureRecordCommand(
  String name,
  Map<String, dynamic> args,
) async {
  await supabase.schema(AppConfig.isolatedApiSchema).rpc(name, params: args);
}

class MoistureRecordWorkflow extends StatefulWidget {
  const MoistureRecordWorkflow({
    super.key,
    required this.record,
    required this.onChanged,
    this.command = moistureRecordCommand,
    this.evidence,
  });
  final Map<String, dynamic> record;
  final VoidCallback onChanged;
  final Widget? evidence;
  final Future<void> Function(String, Map<String, dynamic>) command;
  @override
  State<MoistureRecordWorkflow> createState() => _MoistureRecordWorkflowState();
}

class _MoistureRecordWorkflowState extends State<MoistureRecordWorkflow> {
  final name = TextEditingController(), note = TextEditingController();
  bool open = false, busy = false, confirmed = false;
  String decision = 'VERIFY_RECORD';
  String? error, message, previous, action;
  bool get submit => widget.record['can_submit'] == true;
  @override
  void dispose() {
    name.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> execute() async {
    if (busy ||
        !confirmed ||
        (!submit &&
            (name.text.trim().isEmpty ||
                (decision == 'RETURN' && note.text.trim().isEmpty)))) {
      return;
    }
    final args = <String, dynamic>{
      'p_draft_id': widget.record['id'],
      'p_expected_revision': widget.record['revision'],
      if (!submit) ...{
        'p_submission_id': widget.record['submission_id'],
        'p_decision': decision,
        'p_reviewer_name': name.text.trim(),
        'p_note': note.text.trim().isEmpty ? null : note.text.trim(),
      },
    };
    final payload = jsonEncode(args);
    if (previous != payload) {
      previous = payload;
      action = const Uuid().v4();
    }
    args['p_action_id'] = action;
    setState(() {
      busy = true;
      error = null;
      message = null;
    });
    try {
      await widget.command(
        submit ? 'submit_lab_moisture_record' : 'review_lab_moisture_record',
        args,
      );
      if (!mounted) return;
      setState(() {
        open = false;
        confirmed = false;
        action = null;
        previous = null;
        message = submit
            ? 'Catatan dikirim ke QA. Revisi ini dikunci.'
            : decision == 'RETURN'
            ? 'Catatan dikembalikan ke Analis. Alasan tersimpan.'
            : 'Catatan diverifikasi QA; bukan keputusan lulus/gagal.';
      });
      widget.onChanged();
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Belum berhasil. Jika koneksi terputus, coba lagi dengan isian sama. '
              'Jika revisi/status sudah berubah, muat ulang daftar. Jangan membuat catatan kedua.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.canonicalWritesEnabled ||
        (!submit && widget.record['can_review'] != true)) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (message != null) Semantics(liveRegion: true, child: Text(message!)),
        if (!open)
          OutlinedButton(
            onPressed: busy
                ? null
                : () => setState(() {
                    open = true;
                    error = null;
                    message = null;
                  }),
            child: Text(
              submit ? 'Kirim catatan MC ke QA' : 'Verifikasi catatan MC',
            ),
          ),
        if (open)
          LabFormCard(
            title: [
              submit
                  ? 'Kirim catatan MC tersimpan'
                  : 'Pemeriksaan catatan MC oleh QA',
              if (widget.record['lot_code'] case final String lot) lot,
              'revisi ${widget.record['revision']}',
            ].join(' · '),
            icon: submit ? Icons.outgoing_mail : Icons.fact_check_outlined,
            children: [
              if (widget.evidence != null) ...[
                widget.evidence!,
                const SizedBox(height: 12),
              ],
              if (!submit) ...[
                TextField(
                  controller: name,
                  enabled: !busy,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Nama petugas QA yang memeriksa',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                DropdownButtonFormField<String>(
                  initialValue: decision,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: const InputDecoration(
                    labelText: 'Keputusan catatan',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'VERIFY_RECORD',
                      child: Text('Verifikasi catatan'),
                    ),
                    DropdownMenuItem(
                      value: 'RETURN',
                      child: Text('Kembalikan untuk diperbaiki'),
                    ),
                  ],
                  onChanged: busy ? null : (v) => setState(() => decision = v!),
                ),
                TextField(
                  controller: note,
                  enabled: !busy,
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: decision == 'RETURN'
                        ? 'Alasan perbaikan (wajib)'
                        : 'Catatan QA (boleh kosong)',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: confirmed,
                onChanged: busy
                    ? null
                    : (v) => setState(() => confirmed = v == true),
                title: Text(
                  submit
                      ? 'Saya sudah memeriksa revisi tersimpan. Setelah dikirim, isian dikunci.'
                      : 'Saya sudah memeriksa catatan ini. Ini bukan keputusan mutu lulus/gagal.',
                ),
              ),
              if (!submit)
                const Text('Verifikasi catatan bukan pelepasan lot.'),
              FilledButton(
                onPressed:
                    busy ||
                        !confirmed ||
                        (!submit &&
                            (name.text.trim().isEmpty ||
                                (decision == 'RETURN' &&
                                    note.text.trim().isEmpty)))
                    ? null
                    : execute,
                child: Text(
                  busy
                      ? 'Menyimpan…'
                      : submit
                      ? 'Ya, kirim revisi ini'
                      : decision == 'RETURN'
                      ? 'Kembalikan ke Analis'
                      : 'Simpan verifikasi catatan',
                ),
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
              TextButton(
                onPressed: busy ? null : () => setState(() => open = false),
                child: const Text('Batal'),
              ),
            ],
          ),
      ],
    );
  }
}
