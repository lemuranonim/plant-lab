import 'package:flutter/material.dart';
import 'workflow_presentation.dart';

import '../../../core/config/app_config.dart';
import '../../../core/database/supabase_client.dart';
import 'provisional_quality_reference.dart';
import 'germination_request_forms.dart';
import 'request_germination_detail_screen.dart';

Future<void> saveGerminationCommand(
  String name,
  Map<String, dynamic> params,
) async {
  await supabase.schema(AppConfig.isolatedApiSchema).rpc(name, params: params);
}

class StandaloneGermination extends StatelessWidget {
  const StandaloneGermination({
    super.key,
    required this.requestId,
    required this.requestStatus,
    required this.run,
    required this.analyst,
    required this.reviewer,
    required this.onSaved,
    this.command = saveGerminationCommand,
    this.detailCommand = requestGerminationDetailCommand,
  });

  final String requestId;
  final String requestStatus;
  final Map<String, dynamic>? run;
  final bool analyst;
  final bool reviewer;
  final VoidCallback onSaved;
  final Future<void> Function(String, Map<String, dynamic>) command;
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
  detailCommand;

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.canonicalWritesEnabled) return const SizedBox.shrink();
    final start = analyst && requestStatus == 'RECEIVED' && run == null;
    if (run == null && !start) return const SizedBox.shrink();
    final summary = run?['summary'] as Map<String, dynamic>?;
    final within = summary?['within_tolerance'];
    final runCode = run?['run_code'];
    final status = run?['status'];
    final result = summary?['germination_percent'];
    final richDetail = summary?['request_detail_version'] == 1;
    final gap = summary?['gap_pp'];
    final limit = summary?['limit_pp'] ?? 'belum tersedia';
    final reason = run?['decision_reason'];
    final retest = analyst && requestStatus == 'RETEST' && status == 'RETEST';
    final assigned =
        !AppConfig.hostedPilot || run?['is_assigned_analyst'] == true;
    final submit = analyst && status == 'IN_PROGRESS' && assigned;
    final review =
        reviewer &&
        status == 'IN_REVIEW' &&
        summary != null &&
        run?['is_assigned_analyst'] != true;
    final action = start
        ? 'start'
        : retest
        ? 'retest'
        : submit
        ? 'submit'
        : review
        ? 'review'
        : null;
    return ExpansionTile(
      title: const Text('Germinasi · Pasir 25 °C'),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      expandedAlignment: Alignment.centerLeft,
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        if (runCode != null)
          Text(
            '$runCode · Percobaan ${run?['attempt_no'] ?? 1} · ${workflowStatus('$status')}',
          ),
        if (runCode != null && status != null && (analyst || reviewer))
          GerminationRequestForms(
            key: ValueKey('$requestId:$runCode'),
            requestId: requestId,
            runCode: runCode as String,
            status: status as String,
          ),
        if (summary != null) ...[
          Text('Hasil Germinasi: $result%'),
          if (AppConfig.hostedPilot)
            ProvisionalResultSnapshot(
              snapshot:
                  summary['uac_quality_reference'] as Map<String, dynamic>?,
            ),
          Text('Selisih: $gap poin persentase · batas: $limit'),
          Text(
            within == true
                ? 'Dalam toleransi'
                : within == false
                ? 'Di luar toleransi'
                : 'Aturan toleransi belum tersedia',
          ),
          const Text(
            'Toleransi membandingkan ulangan, bukan batas spesifikasi mutu atau pelepasan lot.',
          ),
          for (final (index, row) in (summary['replicates'] as List).indexed)
            Text(
              [
                'Ulangan ${index + 1}: Normal',
                row['normal'],
                '· Abnormal',
                row['abnormal'],
                if (row['fresh'] != null) ...['· Fresh', row['fresh']],
                if (row['hard'] != null) ...['· Hard', row['hard']],
                '· Mati',
                row['dead'],
                if (row['first_normal'] != null) ...[
                  '· First count (terpisah)',
                  row['first_normal'],
                ],
              ].join(' '),
            ),
          if (reason != null) Text('Catatan QA: $reason'),
        ],
        if (analyst && status == 'IN_PROGRESS' && !assigned)
          const Text(
            'Pengamatan diisi oleh Analis yang memulai percobaan ini.',
          ),
        if (AppConfig.hostedPilot &&
            runCode != null &&
            (analyst || reviewer) &&
            !(submit || (review && richDetail)))
          TextButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<bool>(
                  builder: (_) => RequestGerminationDetailScreen(
                    requestId: requestId,
                    runCode: runCode as String,
                    canApprove: within == true,
                    command: detailCommand,
                  ),
                ),
              );
              if (context.mounted) onSaved();
            },
            child: const Text('Buka rincian pengamatan & petugas'),
          ),
        if (action != null)
          TextButton(
            onPressed: () async {
              if (AppConfig.hostedPilot && (submit || (review && richDetail))) {
                await Navigator.of(context).push(
                  MaterialPageRoute<bool>(
                    builder: (_) => RequestGerminationDetailScreen(
                      requestId: requestId,
                      runCode: runCode as String,
                      canApprove: within == true,
                      command: detailCommand,
                    ),
                  ),
                );
                if (context.mounted) onSaved();
                return;
              }
              final saved = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) => _GerminationDialog(
                  requestId,
                  action,
                  within == true,
                  runCode as String?,
                  command,
                ),
              );
              if (saved == true && context.mounted) onSaved();
            },
            child: Text(
              start
                  ? 'Mulai uji Germinasi'
                  : retest
                  ? 'Mulai uji ulang Germinasi'
                  : submit
                  ? 'Isi pengamatan final'
                  : 'Review hasil',
            ),
          ),
      ],
    );
  }
}

class _GerminationDialog extends StatefulWidget {
  const _GerminationDialog(
    this.requestId,
    this.action,
    this.canApprove,
    this.runCode,
    this.command,
  );
  final String requestId;
  final String action;
  final bool canApprove;
  final String? runCode;
  final Future<void> Function(String, Map<String, dynamic>) command;

  @override
  State<_GerminationDialog> createState() => _GerminationDialogState();
}

class _GerminationDialogState extends State<_GerminationDialog> {
  static const _keys = ['normal', 'abnormal', 'dead'];
  static const _labels = ['Normal', 'Abnormal', 'Mati'];
  final _counts = List.generate(12, (_) => TextEditingController());
  final _reason = TextEditingController();
  int _replicates = 2;
  bool _busy = false;
  String? _error;
  bool _sampleAvailable = false;

  int? _totalFor(int replicate) {
    var total = 0;
    for (var column = 0; column < 3; column++) {
      final count = int.tryParse(_counts[replicate * 3 + column].text.trim());
      if (count == null || count < 0 || count > 9999) return null;
      total += count;
    }
    return total;
  }

  bool get _countsValid {
    final total = _totalFor(0);
    if (total == null || total <= 0) return false;
    if (AppConfig.hostedPilot && (_replicates != 2 || total != 100)) {
      return false;
    }
    return List.generate(
      _replicates,
      _totalFor,
    ).every((value) => value == total);
  }

  @override
  void dispose() {
    for (final controller in _counts) {
      controller.dispose();
    }
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save({String? decision}) async {
    if (!AppConfig.canonicalWritesEnabled || _busy) return;
    final params = <String, dynamic>{'p_request_id': widget.requestId};
    final rpc = switch (widget.action) {
      'start' => 'start_germination',
      'retest' => 'start_germination_retest',
      'submit' =>
        AppConfig.hostedPilot
            ? 'submit_germination_attempt'
            : 'submit_germination',
      _ =>
        AppConfig.hostedPilot
            ? 'review_germination_attempt'
            : 'review_germination',
    };
    if (widget.action == 'retest') {
      if (!_sampleAvailable || widget.runCode == null) return;
      params['p_prior_run_code'] = widget.runCode;
      params['p_sample_available'] = true;
    } else if (AppConfig.hostedPilot && widget.action != 'start') {
      params['p_run_code'] = widget.runCode;
    }
    if (widget.action == 'submit') {
      final rows = <Map<String, int>>[];
      int? expectedTotal;
      for (var i = 0; i < _replicates; i++) {
        final row = <String, int>{};
        var total = 0;
        for (var j = 0; j < 3; j++) {
          final count = int.tryParse(_counts[i * 3 + j].text.trim());
          if (count == null || count < 0 || count > 9999) {
            setState(
              () => _error = 'Isi semua hitungan dengan bilangan bulat 0–9999.',
            );
            return;
          }
          row[_keys[j]] = count;
          total += count;
        }
        if (total == 0 ||
            (AppConfig.hostedPilot && total != 100) ||
            (expectedTotal != null && total != expectedTotal)) {
          setState(
            () => _error = AppConfig.hostedPilot
                ? 'Gunakan 2 ulangan, masing-masing tepat 100 benih.'
                : 'Total benih setiap ulangan harus sama dan lebih dari nol.',
          );
          return;
        }
        expectedTotal = total;
        rows.add(row);
      }
      params['p_replicates'] = rows;
    } else if (widget.action == 'review') {
      final reason = _reason.text.trim();
      if (decision == 'RETEST' && reason.isEmpty) {
        setState(() => _error = 'Alasan uji ulang wajib diisi.');
        return;
      }
      params['p_decision'] = decision;
      if (decision == 'RETEST') params['p_reason'] = reason;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.command(rpc, params);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Tidak dapat menyimpan. Periksa data, status, dan hak akses.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.action == 'review';
    final submit = widget.action == 'submit';
    final retest = widget.action == 'retest';
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(
          review
              ? 'Review hasil Germinasi'
              : submit
              ? 'Pengamatan final'
              : retest
              ? 'Mulai uji ulang Germinasi'
              : 'Mulai uji Germinasi',
        ),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!review && !submit && !retest)
                  const Text(
                    'Konfirmasi bahwa pengujian dengan metode pasir 25 °C dimulai.',
                  ),
                if (retest) ...[
                  const Text(
                    'QA meminta uji ulang. Percobaan baru memakai sampel yang sama dan hitungan baru 2×100; hasil lama tetap tersimpan. Ini bukan permintaan pengiriman sampel baru. Waktu mulai adalah waktu tindakan tercatat di aplikasi, bukan tanggal tanam fisik yang diisi terpisah.',
                  ),
                  CheckboxListTile(
                    value: _sampleAvailable,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _sampleAvailable = v == true),
                    title: const Text(
                      'Sampel yang sama masih tersedia di Lab dan uji ulang akan dimulai.',
                    ),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
                if (submit) ...[
                  const Text(
                    AppConfig.hostedPilot
                        ? '2 ulangan × 100 benih. Normal + abnormal + mati = 100 per ulangan. Isi hitungan final nyata, bukan persen; isi 0 bila tidak ada.'
                        : 'Isi jumlah benih dari pengamatan final yang sudah dilakukan, bukan persentase. Isi 0 jika tidak ada. Total setiap ulangan harus sama.',
                  ),
                  const SizedBox(height: 12),
                  DropdownButton<int>(
                    value: _replicates,
                    items: const [
                      DropdownMenuItem(value: 2, child: Text('2 ulangan')),
                      if (!AppConfig.hostedPilot)
                        DropdownMenuItem(value: 4, child: Text('4 ulangan')),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _replicates = value!),
                  ),
                  for (var i = 0; i < _replicates; i++) ...[
                    Text('Ulangan ${i + 1}'),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final fieldWidth = constraints.maxWidth >= 340
                            ? (constraints.maxWidth - 24) / 3
                            : constraints.maxWidth;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (var j = 0; j < 3; j++)
                              SizedBox(
                                width: fieldWidth,
                                child: TextField(
                                  controller: _counts[i * 3 + j],
                                  enabled: !_busy,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) =>
                                      setState(() => _error = null),
                                  decoration: InputDecoration(
                                    labelText: _labels[j],
                                    floatingLabelBehavior:
                                        FloatingLabelBehavior.always,
                                    suffixText: 'benih',
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Total ulangan ${i + 1}: ${_totalFor(i) ?? '—'} benih',
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
                if (review) ...[
                  if (!widget.canApprove)
                    const Text(
                      'Tidak dapat disetujui karena aturan toleransi tidak terpenuhi atau belum tersedia.',
                    ),
                  TextField(
                    controller: _reason,
                    enabled: !_busy,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Alasan jika minta uji ulang',
                    ),
                  ),
                ],
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          if (review)
            TextButton(
              onPressed: _busy ? null : () => _save(decision: 'RETEST'),
              child: const Text('Minta uji ulang'),
            ),
          FilledButton(
            onPressed:
                _busy ||
                    (review && !widget.canApprove) ||
                    (retest && !_sampleAvailable) ||
                    (submit && !_countsValid)
                ? null
                : () => _save(decision: review ? 'APPROVE' : null),
            child: Text(
              _busy
                  ? 'Menyimpan…'
                  : review
                  ? 'Setujui hasil'
                  : submit
                  ? 'Kirim ke QA'
                  : retest
                  ? 'Mulai uji ulang'
                  : 'Mulai uji',
            ),
          ),
        ],
      ),
    );
  }
}
