import 'dart:convert';
import 'package:flutter/material.dart';
import 'lab_workspace_widgets.dart';
import 'workflow_presentation.dart';
import 'package:uuid/uuid.dart';
import '../../../core/config/app_config.dart';
import '../../../core/database/supabase_client.dart';
import 'provisional_quality_reference.dart';
import 'request_ret_form_download.dart';
import 'request_seedling_form_download.dart';
import 'request_germination_detail_screen.dart';

List<Map<String, int>>? confirmedVigourCounts(List<String> values) {
  if (values.length != 6) return null;
  final numbers = values
      .map(
        (v) => RegExp(r'^\d{1,3}$').hasMatch(v.trim())
            ? int.tryParse(v.trim())
            : null,
      )
      .toList();
  if (numbers.any((v) => v == null || v < 0 || v > 100)) return null;
  final rows = [
    for (var i = 0; i < 2; i++)
      <String, int>{
        'normal': numbers[i * 3]!,
        'abnormal': numbers[i * 3 + 1]!,
        'dead': numbers[i * 3 + 2]!,
      },
  ];
  return rows.every((r) => r.values.reduce((a, b) => a + b) == 100)
      ? rows
      : null;
}

List<Map<String, int>>? confirmedRetCounts(List<String> values) {
  if (values.length != 4) return null;
  final counts = values
      .map(
        (v) => RegExp(r'^\d{1,3}$').hasMatch(v.trim())
            ? int.tryParse(v.trim())
            : null,
      )
      .toList();
  if (counts.any((v) => v == null || v < 0 || v > 100)) return null;
  return [
    for (final value in counts) {'tested': 100, 'radicle_at_least_2mm': value!},
  ];
}

class StandaloneVigour extends StatelessWidget {
  const StandaloneVigour({
    super.key,
    required this.run,
    required this.requestStatus,
    required this.analyst,
    required this.reviewer,
    required this.onSaved,
  });
  final Map<String, dynamic> run;
  final String requestStatus;
  final bool analyst, reviewer;
  final VoidCallback onSaved;

  @override
  Widget build(BuildContext context) {
    final status = run['status'];
    final ret = run['method_code'] == 'RET_16C_72H';
    final readyAt = ret && run['actual_started_at'] != null
        ? DateTime.parse(
            run['actual_started_at'] as String,
          ).add(const Duration(hours: 72)).toLocal()
        : null;
    final summary = run['summary'] as Map<String, dynamic>?;
    final start =
        analyst &&
        ((run['run_id'] == null &&
                ['RECEIVED', 'TESTING'].contains(requestStatus)) ||
            status == 'RETEST');
    final submit =
        analyst &&
        status == 'IN_PROGRESS' &&
        run['is_assigned_analyst'] == true;
    final review =
        reviewer && status == 'IN_REVIEW' && run['is_assigned_analyst'] != true;
    final action = start
        ? 'start'
        : submit
        ? 'submit'
        : review
        ? 'review'
        : null;
    final prior = (run['prior_attempts'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    return ExpansionTile(
      title: Text('Vigor · ${run['method_name']}'),
      subtitle: Text(
        '${workflowStatus('${status ?? run['item_status']}')}${run['attempt_no'] == null ? '' : ' · Percobaan ${run['attempt_no']}'}',
      ),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        if (run['run_code'] != null) Text('${run['run_code']}'),
        if (run['actual_started_at'] != null)
          Text(
            'Mulai nyata: ${DateTime.parse(run['actual_started_at'] as String).toLocal()}',
          ),
        if (run['conditions_note'] != null)
          Text('Kondisi/metode: ${run['conditions_note']}'),
        if (readyAt != null)
          Text(
            'RET · radikula ≥2 mm · 4×100. Pengamatan paling cepat $readyAt (72 jam sejak penempatan pada 16°C).',
          ),
        if (summary != null) ...[
          const SizedBox(height: 10),
          Text(
            ret
                ? 'Hasil RET: ${summary['vigour_percent']}%'
                : 'Hasil Vigor: ${summary['vigour_percent']}% · sebelum pembulatan ${summary['unrounded_percent']}%',
          ),
          Text(
            ret
                ? 'Jumlah radikula memenuhi kriteria / 400 × 100. Toleransi 4 Reps memakai lookup ${summary['tolerance_lookup_percent']}%; nilai RET tetap presisi.'
                : 'Rata-rata normal per ulangan 100 benih, dibulatkan ke persen utuh mengikuti Excel.',
          ),
          Text(
            'Selisih ${summary['gap_pp']} poin persentase · batas ${summary['limit_pp'] ?? 'belum tersedia'}',
          ),
          Text(
            summary['within_tolerance'] == true
                ? 'Dalam toleransi'
                : summary['within_tolerance'] == false
                ? 'Di luar toleransi'
                : 'Belum dapat dinilai; approval diblokir',
          ),
          for (final (index, row) in (summary['replicates'] as List).indexed)
            Text(
              ret
                  ? 'Ulangan ${index + 1}: Radikula ≥2 mm ${row['radicle_at_least_2mm']} / ${row['tested']} benih'
                  : 'Ulangan ${index + 1}: Normal ${row['normal']} · Abnormal ${row['abnormal']}'
                        '${row['fresh'] == null ? '' : ' · Fresh ${row['fresh']}'}'
                        '${row['hard'] == null ? '' : ' · Hard ${row['hard']}'} · Mati ${row['dead']}',
            ),
          Text(
            'Pengamatan nyata: ${DateTime.parse(summary['observed_at'] as String).toLocal()}',
          ),
          Text('${summary['observation_note']}'),
          ProvisionalResultSnapshot(
            snapshot: summary['uac_quality_reference'] as Map<String, dynamic>?,
          ),
        ],
        if (run['decision_reason'] != null)
          Text('Catatan QA: ${run['decision_reason']}'),
        if (ret &&
            run['run_code'] != null &&
            status != null &&
            (analyst || reviewer))
          RequestRetFormDownload(
            runCode: run['run_code'] as String,
            status: status as String,
          ),
        if (!ret &&
            run['run_code'] != null &&
            status != null &&
            (analyst || reviewer))
          RequestSeedlingFormDownload(
            runCode: run['run_code'] as String,
            status: status as String,
            kind: 'Vigor',
          ),
        if (!ret &&
            AppConfig.hostedPilot &&
            run['run_code'] != null &&
            (analyst || reviewer))
          TextButton(
            onPressed: () async {
              try {
                // A legacy QA action is offered only after a successful scoped read.
                // A failed read never falls back to the lossy old writer.
                final detail = await requestGerminationDetailCommand(
                  'get_request_vigour_detail',
                  {
                    'p_request_id': run['request_id'],
                    'p_run_code': run['run_code'],
                  },
                );
                if (!context.mounted) return;
                final bool? saved;
                if (review && detail['has_detail'] == false) {
                  saved = await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) =>
                        VigourActionDialog(run: run, action: 'review'),
                  );
                } else {
                  saved = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => RequestGerminationDetailScreen(
                        requestId: run['request_id'] as String,
                        runCode: run['run_code'] as String,
                        vigour: true,
                        canApprove: summary?['within_tolerance'] == true,
                      ),
                    ),
                  );
                }
                if (saved == true) onSaved();
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Rincian belum dimuat. Periksa koneksi dan coba lagi.',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Buka pengamatan & petugas Vigor'),
          ),
        if (action != null &&
            AppConfig.canonicalWritesEnabled &&
            (start || ret || !AppConfig.hostedPilot))
          TextButton(
            onPressed: () async {
              final saved = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) => VigourActionDialog(run: run, action: action),
              );
              if (saved == true) onSaved();
            },
            child: Text(
              start
                  ? (status == 'RETEST'
                        ? 'Mulai uji ulang Vigor'
                        : 'Mulai Vigor')
                  : submit
                  ? 'Isi pengamatan Vigor'
                  : 'Review hasil Vigor',
            ),
          ),
        if (prior.isNotEmpty)
          ExpansionTile(
            title: Text('Riwayat percobaan sebelumnya (${prior.length})'),
            children: [
              for (final old in prior)
                ListTile(
                  title: Text(
                    '${old['run_code']} · ${workflowStatus('${old['status']}')}',
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Percobaan ${old['attempt_no']} · ${(old['summary'] as Map?)?['vigour_percent'] ?? '—'}%',
                      ),
                      if (ret && (analyst || reviewer))
                        RequestRetFormDownload(
                          runCode: old['run_code'] as String,
                          status: old['status'] as String,
                        ),
                      if (!ret && (analyst || reviewer))
                        RequestSeedlingFormDownload(
                          runCode: old['run_code'] as String,
                          status: old['status'] as String,
                          kind: 'Vigor',
                        ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class VigourActionDialog extends StatefulWidget {
  const VigourActionDialog({
    super.key,
    required this.run,
    required this.action,
    this.execute,
  });
  final Map<String, dynamic> run;
  final String action;
  // UI tests may inject a memory-only command. Production uses the scoped RPC.
  final Future<void> Function(String, Map<String, dynamic>)? execute;
  @override
  State<VigourActionDialog> createState() => _VigourActionDialogState();
}

class _VigourActionDialogState extends State<VigourActionDialog> {
  late final _counts = List.generate(
    _isRet ? 4 : 6,
    (_) => TextEditingController(),
  );
  final _note = TextEditingController();
  DateTime? _actualTime;
  String? _decision, _error, _lastPayload, _actionId;
  bool _busy = false;
  bool get _isFinal => widget.action == 'submit';
  bool get _isReview => widget.action == 'review';
  bool get _isRet => widget.run['method_code'] == 'RET_16C_72H';
  DateTime? get _readyAt => _isRet && widget.run['actual_started_at'] != null
      ? DateTime.parse(
          widget.run['actual_started_at'] as String,
        ).add(const Duration(hours: 72))
      : null;
  List<Map<String, int>>? get _rows => _isRet
      ? confirmedRetCounts(_counts.map((c) => c.text).toList())
      : confirmedVigourCounts(_counts.map((c) => c.text).toList());

  @override
  void dispose() {
    for (final c in _counts) {
      c.dispose();
    }
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _actualTime ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_actualTime ?? now),
    );
    if (time != null && mounted) {
      setState(
        () => _actualTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  Future<void> _save() async {
    if (_busy ||
        (!AppConfig.canonicalWritesEnabled && widget.execute == null)) {
      return;
    }
    final note = _note.text.trim();
    if (note.length < 3) {
      setState(() => _error = 'Catatan minimal 3 karakter wajib diisi.');
      return;
    }
    if (!_isReview &&
        (_actualTime == null || _actualTime!.isAfter(DateTime.now()))) {
      setState(
        () => _error =
            'Pilih waktu kejadian nyata, bukan rencana atau masa depan.',
      );
      return;
    }
    if (_isFinal && _rows == null) {
      setState(
        () => _error = _isRet
            ? 'Isi empat hitungan radikula ≥2 mm, masing-masing 0–100 dari 100 benih.'
            : 'Gunakan 2 ulangan, masing-masing tepat 100 benih; isi 0 bila tidak ada.',
      );
      return;
    }
    if (_isFinal && _readyAt != null && _actualTime!.isBefore(_readyAt!)) {
      setState(
        () => _error =
            'Pengamatan RET paling cepat ${_readyAt!.toLocal()} (72 jam sejak penempatan pada 16°C).',
      );
      return;
    }
    if (_isReview && _decision == null) {
      setState(() => _error = 'Pilih keputusan QA.');
      return;
    }
    final rpc = _isReview
        ? 'review_vigour'
        : _isFinal
        ? 'submit_vigour'
        : 'start_vigour';
    final params = <String, dynamic>{
      if (widget.action == 'start') ...{
        'p_item_id': widget.run['item_id'],
        'p_started_at': _actualTime!.toUtc().toIso8601String(),
        'p_conditions_note': note,
      } else if (_isFinal) ...{
        'p_run_id': widget.run['run_id'],
        'p_observed_at': _actualTime!.toUtc().toIso8601String(),
        'p_replicates': _rows,
        'p_observation_note': note,
      } else ...{
        'p_run_id': widget.run['run_id'],
        'p_decision': _decision,
        'p_reason': note,
      },
    };
    final payload = jsonEncode(params);
    if (_lastPayload != payload) {
      _lastPayload = payload;
      _actionId = const Uuid().v4();
    }
    params['p_action_id'] = _actionId;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.execute != null) {
        await widget.execute!(rpc, params);
      } else {
        await supabase
            .schema(AppConfig.isolatedApiSchema)
            .rpc(rpc, params: params);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Tidak tersimpan. Periksa hitungan, waktu nyata, status, toleransi dan penugasan. Ulangi dengan data yang sama jika koneksi terputus.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(
        _isReview
            ? 'Review QA Vigor'
            : _isFinal
            ? 'Pengamatan final Vigor'
            : 'Mulai Vigor nyata',
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${widget.run['method_name']}'),
              if (_isRet)
                Text(
                  'RET: radikula ≥2 mm, 4×100 benih. Toleransi 4 Reps. Minimal 72 jam sejak penempatan pada 16°C.${_readyAt == null ? '' : ' Pengamatan paling cepat ${_readyAt!.toLocal()}.'}',
                ),
              if (!_isReview) ...[
                const SizedBox(height: 12),
                const Text(
                  'Isi waktu kejadian fisik. Tanggal rencana Excel bukan bukti pelaksanaan.',
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickTime,
                  icon: const Icon(Icons.event),
                  label: Text(
                    _actualTime == null
                        ? (_isFinal
                              ? 'Pilih waktu pengamatan nyata'
                              : _isRet
                              ? 'Pilih waktu penempatan pada 16°C'
                              : 'Pilih waktu mulai nyata')
                        : '$_actualTime',
                  ),
                ),
              ],
              if (_isFinal) ...[
                Text(
                  _isRet
                      ? 'Isi jumlah benih dengan radikula ≥2 mm pada masing-masing ulangan 100 benih. Isi 0 bila tidak ada; jangan memakai hitungan normal Germinasi.'
                      : '2 ulangan × 100 benih. Normal + abnormal + mati =100/ulangan. Isi 0 untuk kategori tanpa benih.',
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < (_isRet ? 4 : 2); i++)
                  LabFormCard(
                    title: 'Ulangan ${i + 1}',
                    icon: Icons.grass_outlined,
                    children: [
                      LabFieldGrid(
                        minFieldWidth: 190,
                        fields: [
                          for (var j = 0; j < (_isRet ? 1 : 3); j++)
                            TextField(
                              controller: _counts[i * (_isRet ? 1 : 3) + j],
                              enabled: !_busy,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() => _error = null),
                              decoration: InputDecoration(
                                labelText:
                                    '${_isRet ? 'Radikula ≥2 mm' : ['Normal', 'Abnormal', 'Mati'][j]} ulangan ${i + 1}',
                                suffixText: _isRet ? '/ 100 benih' : 'benih',
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.always,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
              ],
              if (_isReview) ...[
                const SizedBox(height: 12),
                const Text(
                  'Periksa hitungan, waktu nyata dan kondisi metode. Persetujuan hasil analisis bukan izin pelepasan lot.',
                ),
                DropdownButtonFormField<String>(
                  initialValue: _decision,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Keputusan QA'),
                  items: [
                    DropdownMenuItem(
                      value: 'APPROVE',
                      enabled:
                          (widget.run['summary']
                              as Map?)?['within_tolerance'] ==
                          true,
                      child: const Text('Setujui hasil analisis'),
                    ),
                    const DropdownMenuItem(
                      value: 'RETEST',
                      child: Text('Minta uji ulang'),
                    ),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _decision = v),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _note,
                enabled: !_busy,
                maxLength: 1000,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: _isReview
                      ? 'Hasil pemeriksaan dan alasan keputusan'
                      : _isFinal
                      ? 'Catatan pengamatan nyata'
                      : 'Kondisi, alat, dan rujukan metode aktual',
                ),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _busy || (_isFinal && _rows == null) ? null : _save,
          child: Text(
            _busy
                ? 'Menyimpan…'
                : _isReview
                ? 'Simpan keputusan QA'
                : _isFinal
                ? 'Kirim hasil Vigor ke QA'
                : 'Mulai Vigor',
          ),
        ),
      ],
    ),
  );
}
