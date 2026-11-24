import 'package:flutter/material.dart';
import '../../lab_request/presentation/workflow_presentation.dart';
import 'package:uuid/uuid.dart';
import '../../../core/config/app_config.dart';
import '../../../core/database/supabase_client.dart';

Map<String, dynamic> operationPayload({
  required String id,
  required String siteId,
  required int productId,
  required String processCode,
  required DateTime startedAt,
  DateTime? finishedAt,
  String? lotId,
  String? revisionOf,
  int expectedVersion = 0,
  bool submit = false,
  required Map<String, dynamic> values,
  required List<Map<String, dynamic>> materials,
  required List<Map<String, dynamic>> consumptions,
}) => {
  'id': id,
  'site_id': siteId,
  'product_id': productId,
  'lot_id': lotId,
  'process_code': processCode,
  'started_at': startedAt.toUtc().toIso8601String(),
  'finished_at': finishedAt?.toUtc().toIso8601String(),
  'revision_of_id': revisionOf,
  'expected_version': expectedVersion,
  'submit': submit,
  'values': values,
  'materials': materials
      .map(
        (m) => Map.fromEntries(
          m.entries.where(
            (e) => [
              'direction',
              'lot_id',
              'reference_code',
              'component',
              'quantity_kg',
            ].contains(e.key),
          ),
        ),
      )
      .toList(),
  'consumptions': consumptions
      .map(
        (c) => Map.fromEntries(
          c.entries.where(
            (e) => ['material_name', 'unit_code', 'quantity'].contains(e.key),
          ),
        ),
      )
      .toList(),
};

class PlantOperationsScreen extends StatefulWidget {
  const PlantOperationsScreen({
    super.key,
    required this.userId,
    required this.reviewer,
  });
  final String userId;
  final bool reviewer;
  @override
  State<PlantOperationsScreen> createState() => _PlantOperationsState();
}

class _PlantOperationsState extends State<PlantOperationsScreen> {
  Map<String, dynamic>? options;
  List<Map<String, dynamic>> records = [];
  String? error;
  bool loading = true;
  int offset = 0, total = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final api = supabase.schema(AppConfig.isolatedApiSchema);
      final results = await Future.wait([
        api.rpc<Map<String, dynamic>>('get_plant_operation_options'),
        api.rpc<Map<String, dynamic>>(
          'list_plant_operations',
          params: {'p_limit': 20, 'p_offset': offset},
        ),
      ]);
      if (!mounted) return;
      setState(() {
        options = results[0];
        records = List<Map<String, dynamic>>.from(results[1]['records']);
        total = results[1]['total'] as int;
      });
    } on Exception {
      if (mounted) {
        setState(
          () => error =
              'Input Plant belum bisa dimuat. Periksa koneksi; antrean Lab tetap tersedia.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> edit([
    Map<String, dynamic>? record,
    bool revision = false,
  ]) async {
    if (options == null) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PlantOperationForm(
          options: options!,
          record: record,
          revision: revision,
        ),
      ),
    );
    if (saved == true) await load();
  }

  Future<void> review(Map<String, dynamic> run) async {
    final reason = TextEditingController();
    var decision = 'APPROVED', busy = false;
    String? reviewError;
    var token = const Uuid().v4();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, update) => AlertDialog(
          title: const Text('Review pencatatan Plant'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${run['process_code']} · ${run['lot_code'] ?? 'Receiving'}',
                ),
                DropdownButtonFormField<String>(
                  initialValue: decision,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: 'APPROVED',
                      child: Text('Setujui pencatatan'),
                    ),
                    DropdownMenuItem(
                      value: 'NEED_REVISION',
                      child: Text('Kembalikan untuk revisi'),
                    ),
                    DropdownMenuItem(
                      value: 'VOIDED',
                      child: Text('Batalkan pencatatan'),
                    ),
                  ],
                  onChanged: busy
                      ? null
                      : (v) => update(() {
                          decision = v!;
                          token = const Uuid().v4();
                        }),
                ),
                TextField(
                  controller: reason,
                  maxLength: 500,
                  maxLines: 3,
                  enabled: !busy,
                  decoration: const InputDecoration(
                    labelText: 'Alasan dan rujukan bukti',
                  ),
                  onChanged: (_) {
                    token = const Uuid().v4();
                  },
                ),
                const Text('Bukan approval mutu Lab atau release lot.'),
                if (reviewError != null)
                  Text(
                    reviewError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (reason.text.trim().length < 5) {
                        update(
                          () => reviewError = 'Isi alasan minimal 5 karakter.',
                        );
                        return;
                      }
                      update(() {
                        busy = true;
                        reviewError = null;
                      });
                      try {
                        await supabase
                            .schema(AppConfig.isolatedApiSchema)
                            .rpc(
                              'review_plant_operation',
                              params: {
                                'p_run_id': run['id'],
                                'p_expected_version': run['row_version'],
                                'p_decision': decision,
                                'p_reason': reason.text,
                                'p_action_id': token,
                              },
                            );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } on Exception {
                        update(() {
                          busy = false;
                          reviewError =
                              'Belum terkonfirmasi. Periksa role, status terbaru, dan koneksi.';
                        });
                      }
                    },
              child: Text(busy ? 'Memproses…' : 'Simpan keputusan'),
            ),
          ],
        ),
      ),
    );
    reason.dispose();
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Input Harian Plant'),
      actions: [
        IconButton(
          tooltip: 'Muat ulang',
          onPressed: loading ? null : load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton:
        options != null &&
            AppConfig.canonicalWritesEnabled &&
            List<Map<String, dynamic>>.from(
              options!['sites'],
            ).any((s) => s['can_write'] == true)
        ? FloatingActionButton.extended(
            onPressed: () => edit(),
            icon: const Icon(Icons.add),
            label: const Text('Catat pekerjaan'),
          )
        : null,
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                WorkflowNote(
                  title: widget.reviewer
                      ? 'Tugas Supervisor Plant'
                      : 'Tugas Operator Plant',
                  text: widget.reviewer
                      ? 'Periksa rekaman tim di bawah. Persetujuan pencatatan tidak menggantikan review mutu Lab atau pelepasan lot.'
                      : 'Ketuk Catat pekerjaan, pilih proses, lalu isi kejadian nyata. Simpan draft untuk dilanjutkan, atau kirim ke SPV jika lengkap.',
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                if (records.isEmpty && error == null)
                  const Text(
                    'Belum ada pencatatan operasional pada site Anda.',
                  ),
                for (final run in records)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              Text(
                                '${List<Map<String, dynamic>>.from(options!['forms']).where((f) => f['process_code'] == run['process_code']).firstOrNull?['title'] ?? run['process_code']}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Chip(
                                label: Text(
                                  run['status'] == 'APPROVED'
                                      ? 'Pencatatan disetujui SPV'
                                      : workflowStatus('${run['status']}'),
                                ),
                              ),
                            ],
                          ),
                          SelectableText(
                            '${run['lot_code'] ?? 'Receiving sebelum lot'}',
                          ),
                          Text(
                            '${run['site_code']} · ${run['product_name']} · revisi ${run['revision_no']}',
                          ),
                          Text(
                            'Mulai: ${DateTime.parse(run['started_at']).toLocal()}',
                          ),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const Text('Input dan material'),
                            children: [
                              for (final entry in Map<String, dynamic>.from(
                                run['values'],
                              ).entries)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(entry.key),
                                  subtitle: Text('${entry.value}'),
                                ),
                              for (final m in List<Map<String, dynamic>>.from(
                                run['materials'],
                              ))
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    '${m['direction']} · ${m['quantity_kg']} kg',
                                  ),
                                  subtitle: Text(
                                    '${m['reference_code'] ?? '—'} · ${m['component'] ?? '—'}',
                                  ),
                                ),
                              for (final c in List<Map<String, dynamic>>.from(
                                run['consumptions'],
                              ))
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('${c['material_name']}'),
                                  subtitle: Text(
                                    '${c['quantity']} ${c['unit_code']}',
                                  ),
                                ),
                            ],
                          ),
                          if (run['review_reason'] != null)
                            Text('Review: ${run['review_reason']}'),
                          if (run['created_by'] == widget.userId &&
                              run['status'] == 'DRAFT')
                            TextButton(
                              onPressed: () => edit(run),
                              child: const Text('Lanjutkan draft'),
                            ),
                          if (run['created_by'] == widget.userId &&
                              [
                                'APPROVED',
                                'NEED_REVISION',
                              ].contains(run['status']))
                            TextButton(
                              onPressed: () => edit(run, true),
                              child: const Text('Buat revisi'),
                            ),
                          if (widget.reviewer &&
                              run['created_by'] != widget.userId &&
                              run['status'] == 'SUBMITTED')
                            TextButton(
                              onPressed: () => review(run),
                              child: const Text('Review pencatatan'),
                            ),
                        ],
                      ),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: offset == 0
                          ? null
                          : () {
                              offset = (offset - 20).clamp(0, total);
                              load();
                            },
                      child: const Text('Sebelumnya'),
                    ),
                    Text(
                      '${offset + (total == 0 ? 0 : 1)}–${(offset + 20).clamp(0, total)} / $total',
                    ),
                    TextButton(
                      onPressed: offset + 20 >= total
                          ? null
                          : () {
                              offset += 20;
                              load();
                            },
                      child: const Text('Berikutnya'),
                    ),
                  ],
                ),
                const Text(
                  'Laporan harian dan unduhan CSV tersedia pada web Plant → Input Harian Plant.',
                ),
              ],
            ),
          ),
  );
}

class PlantOperationForm extends StatefulWidget {
  const PlantOperationForm({
    super.key,
    required this.options,
    this.record,
    this.revision = false,
  });
  final Map<String, dynamic> options;
  final Map<String, dynamic>? record;
  final bool revision;
  @override
  State<PlantOperationForm> createState() => _PlantOperationFormState();
}

class _PlantOperationFormState extends State<PlantOperationForm> {
  final controllers = <String, TextEditingController>{};
  final dates = <String, DateTime>{};
  final selections = <String, String>{};
  final search = TextEditingController();
  late String id, process;
  String? site, lot;
  int? product;
  int version = 0;
  bool busy = false;
  String? error;
  List<Map<String, dynamic>> materials = [], consumptions = [];
  List<Map<String, dynamic>> get forms =>
      List<Map<String, dynamic>>.from(widget.options['forms']);
  List<Map<String, dynamic>> get fields => List<Map<String, dynamic>>.from(
    forms.firstWhere((f) => f['process_code'] == process)['fields'],
  );
  @override
  void initState() {
    super.initState();
    final r = widget.record;
    id = r != null && !widget.revision ? r['id'] : const Uuid().v4();
    version = r != null && !widget.revision ? r['row_version'] : 0;
    process = r?['process_code'] ?? 'RECEIVING';
    site = r?['site_id'];
    lot = r?['lot_id'];
    product = r?['product_id'];
    final sites = List<Map<String, dynamic>>.from(
      widget.options['sites'],
    ).where((s) => s['can_write'] == true).toList();
    site ??= sites.isEmpty ? null : sites.first['id'];
    if (r != null) {
      dates['started_at'] = DateTime.parse(r['started_at']).toLocal();
      if (r['finished_at'] != null) {
        dates['finished_at'] = DateTime.parse(r['finished_at']).toLocal();
      }
      for (final field in fields) {
        final key = field['key'] as String, value = r['values'][field['key']];
        if (value == null) continue;
        if (field['type'] == 'timestamp' || field['type'] == 'date') {
          dates[key] = DateTime.parse('$value').toLocal();
        } else if (field['type'] == 'select') {
          selections[key] = '$value';
        } else {
          controllers[key] = TextEditingController(text: '$value');
        }
      }
      materials = List<Map<String, dynamic>>.from(
        r['materials'],
      ).map((m) => {...m, '_key': const Uuid().v4()}).toList();
      consumptions = List<Map<String, dynamic>>.from(
        r['consumptions'],
      ).map((c) => {...c, '_key': const Uuid().v4()}).toList();
    }
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    search.dispose();
    super.dispose();
  }

  Future<void> pickDate(String key, bool withTime) async {
    final initial = dates[key] ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (date == null || !mounted) return;
    final time = withTime
        ? await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(initial),
          )
        : null;
    if (withTime && time == null || !mounted) return;
    setState(
      () => dates[key] = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 0,
        time?.minute ?? 0,
      ),
    );
  }

  Widget dateField(String key, String label, bool withTime) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              dates[key] == null
                  ? 'Belum diisi'
                  : withTime
                  ? '${dates[key]}'
                  : '${dates[key]}'.split(' ').first,
            ),
          ),
          IconButton(
            tooltip: 'Pilih tanggal${withTime ? ' dan jam' : ''}',
            onPressed: busy ? null : () => pickDate(key, withTime),
            icon: const Icon(Icons.calendar_month),
          ),
        ],
      ),
    ),
  );
  Future<void> save(bool submit) async {
    if (busy) return;
    setState(() => error = null);
    if (site == null ||
        product == null ||
        dates['started_at'] == null ||
        (process != 'RECEIVING' && lot == null) ||
        (submit && dates['finished_at'] == null)) {
      setState(
        () => error =
            'Lengkapi site, produk, waktu nyata, dan lot untuk proses setelah receiving.',
      );
      return;
    }
    final values = <String, dynamic>{};
    for (final field in fields) {
      final key = field['key'] as String, type = field['type'];
      dynamic value;
      if (type == 'timestamp') {
        value = dates[key]?.toUtc().toIso8601String();
      } else if (type == 'date') {
        value = dates[key]?.toIso8601String().split('T').first;
      } else if (type == 'select') {
        value = selections[key];
      } else {
        final text = controllers[key]?.text.trim() ?? '';
        if (text.isNotEmpty) {
          value = ['number', 'integer'].contains(type)
              ? num.tryParse(text.replaceAll(',', '.'))
              : text;
          if (value == null) {
            setState(() => error = 'Angka tidak valid: ${field['label']}');
            return;
          }
        }
      }
      if (submit && field['required'] == true && value == null) {
        setState(() => error = 'Lengkapi ${field['label']}.');
        return;
      }
      if (value != null) values[key] = value;
    }
    if (materials.any((m) => m['quantity_kg'] is! num) ||
        consumptions.any((c) => c['quantity'] is! num)) {
      setState(
        () => error = 'Lengkapi jumlah setiap baris atau hapus baris kosong.',
      );
      return;
    }
    setState(() => busy = true);
    try {
      final result = await supabase
          .schema(AppConfig.isolatedApiSchema)
          .rpc<Map<String, dynamic>>(
            'save_plant_operation',
            params: {
              'p_document': operationPayload(
                id: id,
                siteId: site!,
                productId: product!,
                processCode: process,
                startedAt: dates['started_at']!,
                finishedAt: dates['finished_at'],
                lotId: lot,
                revisionOf: widget.revision
                    ? widget.record!['id']
                    : widget.record?['revision_of_id'],
                expectedVersion: version,
                submit: submit,
                values: values,
                materials: materials,
                consumptions: consumptions,
              ),
            },
          );
      version = result['row_version'];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              submit
                  ? 'SUBMITTED. Menunggu review Plant SPV.'
                  : 'Draft tersimpan di server.',
            ),
          ),
        );
        if (submit) Navigator.pop(context, true);
      }
    } on Exception {
      if (mounted) {
        setState(
          () => error =
              'Belum terkonfirmasi. Periksa isian, role/site, status terbaru dan koneksi. ID transaksi tetap sama saat mencoba kembali.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lots = List<Map<String, dynamic>>.from(widget.options['lots'])
        .where(
          (l) =>
              l['site_id'] == site &&
              (product == null || l['product_id'] == product) &&
              (l['id'] == lot ||
                  '${l['lot_code']}'.toUpperCase().contains(
                    search.text.trim().toUpperCase(),
                  )),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.revision ? 'Revisi pencatatan' : 'Pencatatan Plant'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Input online dan sesuai kejadian nyata. Draft disimpan di server, bukan di penyimpanan HP tanpa enkripsi.',
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: site,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Site'),
            items: List<Map<String, dynamic>>.from(widget.options['sites'])
                .where((s) => s['can_write'] == true)
                .map(
                  (s) => DropdownMenuItem<String>(
                    value: s['id'],
                    child: Text('${s['site_name']}'),
                  ),
                )
                .toList(),
            onChanged: busy || widget.record != null || version > 0
                ? null
                : (v) => setState(() {
                    site = v;
                    lot = null;
                  }),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: process,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Proses'),
            items: forms
                .map(
                  (f) => DropdownMenuItem<String>(
                    value: f['process_code'],
                    child: Text('${f['title']}'),
                  ),
                )
                .toList(),
            onChanged: busy || widget.record != null || version > 0
                ? null
                : (v) => setState(() {
                    process = v!;
                    for (final c in controllers.values) {
                      c.clear();
                    }
                    selections.clear();
                    dates.removeWhere(
                      (k, _) => !['started_at', 'finished_at'].contains(k),
                    );
                    materials.clear();
                    consumptions.clear();
                  }),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: product,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Produk / Hybrid'),
            items: List<Map<String, dynamic>>.from(widget.options['products'])
                .map(
                  (p) => DropdownMenuItem<int>(
                    value: p['id'],
                    child: Text('${p['name']}'),
                  ),
                )
                .toList(),
            onChanged: busy || widget.record != null || version > 0
                ? null
                : (v) => setState(() {
                    product = v;
                    lot = null;
                  }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: search,
            decoration: const InputDecoration(labelText: 'Cari kode lot'),
            onChanged: (_) => setState(() {}),
          ),
          DropdownButtonFormField<String>(
            key: ValueKey('$site-$product-${lots.length}-$lot'),
            initialValue: lot,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: process == 'RECEIVING'
                  ? 'Lot opsional (jika belum terbentuk)'
                  : 'Lot *',
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('Pilih lot'),
              ),
              ...lots.map(
                (l) => DropdownMenuItem<String>(
                  value: l['id'],
                  child: Text(
                    '${l['lot_code']} · ${l['stage_code']}',
                    softWrap: true,
                  ),
                ),
              ),
            ],
            onChanged: busy
                ? null
                : (v) => setState(() {
                    lot = v;
                  }),
          ),
          const SizedBox(height: 18),
          dateField('started_at', 'Mulai nyata *', true),
          dateField('finished_at', 'Selesai nyata (wajib saat submit)', true),
          for (final field in fields)
            if (['timestamp', 'date'].contains(field['type']))
              dateField(
                field['key'],
                '${field['label']}${field['required'] == true ? ' *' : ''}',
                field['type'] == 'timestamp',
              )
            else if (field['type'] == 'select')
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: DropdownButtonFormField<String>(
                  key: ValueKey('$process-${field['key']}'),
                  initialValue: selections[field['key']],
                  isExpanded: true,
                  decoration: InputDecoration(labelText: '${field['label']}'),
                  items: List<String>.from(field['options'])
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: busy ? null : (v) => selections[field['key']] = v!,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextField(
                  controller: controllers.putIfAbsent(
                    field['key'],
                    () => TextEditingController(),
                  ),
                  enabled: !busy,
                  keyboardType: ['number', 'integer'].contains(field['type'])
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.text,
                  decoration: InputDecoration(
                    labelText:
                        '${field['label']}${field['required'] == true ? ' *' : ''}${field['unit'] == null ? '' : ' (${field['unit']})'}',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
          if (process != 'RECEIVING') ...[
            Text(
              'Material masuk / keluar / reject (kg)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text(
              'Rujukan material tidak mengganti pasangan DSS–DCS resmi.',
            ),
            for (final m in materials)
              Card(
                key: ValueKey(m['_key']),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: m['direction'],
                        decoration: const InputDecoration(labelText: 'Arus'),
                        items: ['INPUT', 'OUTPUT', 'REJECT']
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                        onChanged: busy ? null : (v) => m['direction'] = v,
                      ),
                      TextFormField(
                        initialValue: m['reference_code'],
                        maxLength: 100,
                        decoration: const InputDecoration(
                          labelText: 'Kode referensi lot',
                        ),
                        onChanged: (v) => m['reference_code'] = v,
                      ),
                      TextFormField(
                        initialValue: m['component'],
                        maxLength: 100,
                        decoration: const InputDecoration(
                          labelText: 'Komponen / reject',
                        ),
                        onChanged: (v) => m['component'] = v,
                      ),
                      TextFormField(
                        initialValue: m['quantity_kg']?.toString(),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Berat kg',
                        ),
                        onChanged: (v) => m['quantity_kg'] = num.tryParse(
                          v.replaceAll(',', '.'),
                        ),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() => materials.remove(m)),
                        child: const Text('Hapus baris'),
                      ),
                    ],
                  ),
                ),
              ),
            TextButton.icon(
              onPressed: busy
                  ? null
                  : () => setState(
                      () => materials.add({
                        '_key': const Uuid().v4(),
                        'direction': 'INPUT',
                      }),
                    ),
              icon: const Icon(Icons.add),
              label: const Text('Tambah material'),
            ),
          ],
          if (['TREATMENT', 'PACKING'].contains(process)) ...[
            Text(
              'Pemakaian aktual bahan / kemasan',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final c in consumptions)
              Card(
                key: ValueKey(c['_key']),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextFormField(
                        initialValue: c['material_name'],
                        maxLength: 100,
                        decoration: const InputDecoration(
                          labelText: 'Nama bahan',
                        ),
                        onChanged: (v) => c['material_name'] = v,
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: c['unit_code'],
                        decoration: const InputDecoration(labelText: 'Unit'),
                        items: ['GRAM', 'KG', 'ML', 'L', 'PIECE']
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                        onChanged: busy ? null : (v) => c['unit_code'] = v,
                      ),
                      TextFormField(
                        initialValue: c['quantity']?.toString(),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Jumlah aktual',
                        ),
                        onChanged: (v) => c['quantity'] = num.tryParse(
                          v.replaceAll(',', '.'),
                        ),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() => consumptions.remove(c)),
                        child: const Text('Hapus baris'),
                      ),
                    ],
                  ),
                ),
              ),
            TextButton.icon(
              onPressed: busy
                  ? null
                  : () => setState(
                      () => consumptions.add({
                        '_key': const Uuid().v4(),
                        'unit_code': 'PIECE',
                        'material_name': '',
                      }),
                    ),
              icon: const Icon(Icons.add),
              label: const Text('Tambah pemakaian'),
            ),
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: busy ? null : () => save(false),
            child: const Text('Simpan draft'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: busy ? null : () => save(true),
            child: Text(busy ? 'Memproses…' : 'Submit ke Plant SPV'),
          ),
        ],
      ),
    );
  }
}
