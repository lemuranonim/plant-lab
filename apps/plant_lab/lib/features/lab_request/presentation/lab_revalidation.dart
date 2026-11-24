import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/config/app_config.dart';
import '../../../core/database/supabase_client.dart';

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

class RevalidationContextCard extends StatelessWidget {
  const RevalidationContextCard({super.key, required this.record});
  final Map record;
  @override
  Widget build(BuildContext context) {
    final v = record['revalidation'] as Map?;
    if (v == null) return const SizedBox.shrink();
    return ExpansionTile(
      title: Text(revalidationPurpose(record)),
      tilePadding: EdgeInsets.zero,
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sumber: ${v['source_run_code']}'),
        Text(
          'Persetujuan: ${v['authorizer_name']} · ${revalidationWib(v['authorized_at'])}',
        ),
        Text('Alasan: ${v['reason']}'),
        Text(
          '${revalidationSamplePlan(v['sample_plan'])} · ${v['sample_evidence']}',
        ),
        Text('Label sumber: ${v['source_sample_reference']}'),
        if (v['is_qa_retest'] == true)
          const Text(
            'Uji ulang QA tetap pada tahap ini, bukan Revalidation berikutnya.',
          ),
      ],
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

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      title: const Text('Revalidation 1–3'),
      subtitle: const Text('Persetujuan manual Admin Lab'),
      childrenPadding: const EdgeInsets.all(16),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Pilih sumber yang sudah disetujui QA. Admin menentukan alasan dan rencana sampel per kasus. Bukan jadwal otomatis atau pelepasan lot. Uji ulang QA tetap pada tahap yang sama.',
        ),
        const Text(
          'Sampel simpanan harus cocok dengan label sumber. Sampel baru perlu dicocokkan fisiknya. Tidak membuat pengiriman Plant atau menyalin angka lama.',
        ),
        TextField(
          controller: search,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'Cari lot, hybrid atau nomor uji sumber',
          ),
          onSubmitted: busy ? null : (_) => load(term: search.text.trim()),
        ),
        OutlinedButton(
          onPressed: busy ? null : () => load(term: search.text.trim()),
          child: const Text('Muat Revalidation'),
        ),
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (message != null) Text(message!),
        if (options != null) ...[
          if (options!['can_authorize'] != true)
            const Text(
              'Persetujuan hanya untuk petugas dengan wewenang Admin Revalidation. QA biasa atau Analis tidak otomatis menjadi Admin.',
            ),
          Text('Sumber analisis yang disetujui QA · ${options!['total']}'),
          for (final source
              in (options!['candidates'] as List).cast<Map<String, dynamic>>())
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${source['lot_code']} · ${source['hybrid']}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${source['run_code']} · ${source['method_name']}\nSampel: ${source['sample_reference']}',
                    ),
                    Text(
                      (source['next_stage'] as int) <= 3
                          ? 'Tahap berikutnya: Revalidation ${source['next_stage']}'
                          : 'Sudah mencapai Revalidation 3',
                    ),
                    if (source['blocked_reason'] != null)
                      Text(source['blocked_reason'] as String)
                    else if (options!['can_authorize'] == true &&
                        AppConfig.canonicalWritesEnabled)
                      OutlinedButton(
                        onPressed: busy
                            ? null
                            : () => open('AUTHORIZE', source),
                        child: Text(
                          'Beri persetujuan Revalidation ${source['next_stage']}',
                        ),
                      ),
                  ],
                ),
              ),
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
        if (page != null) ...[
          Text('Persetujuan Revalidation · ${page!['total']}'),
          for (final item
              in (page!['authorizations'] as List).cast<Map<String, dynamic>>())
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${item['lot_code']} · Revalidation ${item['stage']}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('${item['source_run_code']} · ${item['method_name']}'),
                    Text(
                      '${revalidationSamplePlan(item['sample_plan'])} · label sumber: ${item['sample_reference']}',
                    ),
                    Text(
                      'Disetujui ${item['authorizer_name']} · ${revalidationWib(item['authorized_at'])}',
                    ),
                    Text(
                      'Alasan: ${item['reason']}\nRujukan sampel: ${item['sample_evidence']}',
                    ),
                    Text(
                      item['status'] == 'CANCELLED'
                          ? 'Dibatalkan: ${item['cancellation_reason']}'
                          : item['status'] == 'DRAFT_CREATED'
                          ? 'Catatan sudah disiapkan. Buka dari Catatan tersimpan.'
                          : 'Menunggu Analis mencocokkan sampel.',
                    ),
                    if (item['can_start'] == true &&
                        AppConfig.canonicalWritesEnabled)
                      OutlinedButton(
                        onPressed: busy ? null : () => open('START', item),
                        child: Text(
                          'Siapkan catatan Revalidation ${item['stage']}',
                        ),
                      ),
                    if (item['can_cancel'] == true &&
                        AppConfig.canonicalWritesEnabled)
                      TextButton(
                        onPressed: busy ? null : () => open('CANCEL', item),
                        child: const Text(
                          'Batalkan persetujuan yang belum dimulai',
                        ),
                      ),
                  ],
                ),
              ),
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
      title: Text(
        '${authorize
            ? 'Persetujuan'
            : start
            ? 'Siapkan catatan'
            : 'Batalkan'} Revalidation',
      ),
    ),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${widget.item['lot_code']} · Revalidation ${widget.item[authorize ? 'next_stage' : 'stage']}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            '${widget.item['source_run_code'] ?? widget.item['run_code']} · ${widget.item['method_name']}',
          ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
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
              decoration: const InputDecoration(labelText: 'Rencana sampel'),
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
              validator: (v) => v == null ? 'Pilih rencana sampel.' : null,
              onChanged: busy
                  ? null
                  : (v) => setState(() {
                      plan = v;
                      confirmed = false;
                    }),
            ),
          ],
          if (!start)
            TextFormField(
              controller: reason,
              enabled: !busy,
              maxLength: 1000,
              minLines: 2,
              maxLines: 6,
              validator: (v) =>
                  (v?.trim().length ?? 0) < 3 ? 'Isi alasan yang jelas.' : null,
              decoration: InputDecoration(
                labelText: authorize
                    ? 'Alasan Revalidation'
                    : 'Alasan pembatalan',
              ),
            ),
          if (authorize)
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
          if (start) ...[
            Text(
              '${revalidationSamplePlan(widget.item['sample_plan'])} · ${widget.item['sample_evidence']}',
            ),
            TextFormField(
              controller: reference,
              enabled: !busy,
              readOnly: widget.item['sample_plan'] == 'RETAINED_LAB',
              maxLength: 120,
              validator: requiredText,
              decoration: const InputDecoration(
                labelText: 'Label sampel fisik',
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sampel tersedia untuk Revalidation (WIB)'),
              subtitle: Text(
                available == null
                    ? 'Belum diisi'
                    : '${available!.toIso8601String().substring(0, 16).replaceFirst('T', ' ')} WIB',
              ),
              trailing: IconButton(
                tooltip: 'Pilih waktu sampel tersedia',
                onPressed: busy ? null : pickTime,
                icon: const Icon(Icons.calendar_month),
              ),
            ),
            DropdownButtonFormField<int>(
              initialValue: reps,
              decoration: const InputDecoration(labelText: 'Jumlah ulangan'),
              items:
                  (widget.item['method_code'] == 'SAND_25C' ? [2, 4] : [reps])
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
          const SizedBox(height: 12),
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
            onPressed: busy || !confirmed ? null : save,
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
        ],
      ),
    ),
  );
}
