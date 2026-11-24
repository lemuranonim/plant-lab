import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../lab_request/presentation/workflow_presentation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show FileOptions, StorageException;
import 'package:uuid/uuid.dart';
import '../../../core/config/app_config.dart';
import '../../../core/database/supabase_client.dart';
import 'pi_tsw_weights.dart';
import 'pi_tsw_form_download.dart';

const piComponentLabels = {
  'WORKING_SAMPLE_GRAM': 'Sampel kerja',
  'PURE_SEED_GRAM': 'Pure seed',
  'INERT_MATTER_GRAM': 'Inert matter',
  'FUNGI_GRAM': 'Fungi',
  'DAMAGE_GRAM': 'Damage',
  'PREGERM_GRAM': 'Pregerm',
  'SMALL_SEED_GRAM': 'Small seed',
  'OTHER_SEED_GRAM': 'Other seed',
  'TOTAL_COMPONENT_GRAM': 'Total komponen terukur',
};
({String mime, String extension}) piImageKind(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 255 &&
      bytes[1] == 216 &&
      bytes[2] == 255) {
    return (mime: 'image/jpeg', extension: 'jpg');
  }
  const png = [137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length >= 8 &&
      List.generate(8, (i) => bytes[i] == png[i]).every((x) => x)) {
    return (mime: 'image/png', extension: 'png');
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
      String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP') {
    return (mime: 'image/webp', extension: 'webp');
  }
  throw const FormatException('Gunakan foto JPEG, PNG atau WebP asli.');
}

class PiQualityScreen extends StatefulWidget {
  const PiQualityScreen({super.key, required this.isPlant});
  final bool isPlant;
  @override
  State<PiQualityScreen> createState() => _PiQualityState();
}

class _PiQualityState extends State<PiQualityScreen> {
  Map<String, dynamic>? options;
  List<Map<String, dynamic>> records = [];
  bool loading = true;
  int offset = 0, total = 0;
  String? error;
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
      final values = await Future.wait([
        api.rpc<Map<String, dynamic>>('get_pi_test_options'),
        api.rpc<Map<String, dynamic>>(
          'list_pi_tests',
          params: {'p_limit': 20, 'p_offset': offset},
        ),
      ]);
      if (!mounted) return;
      setState(() {
        options = values[0];
        records = List<Map<String, dynamic>>.from(values[1]['records']);
        total = values[1]['total'] as int;
      });
    } on Exception {
      if (mounted) {
        setState(
          () => error =
              'Sumber PI belum dapat dimuat. Periksa koneksi dan penugasan akun.',
        );
      }
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> edit([
    Map<String, dynamic>? record,
    bool revision = false,
  ]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PiTestForm(options: options!, record: record, revision: revision),
      ),
    );
    if (mounted) await load();
  }

  Future<void> photo(String path) async {
    try {
      final url = await supabase.storage
          .from('plantlab-pi-evidence')
          .createSignedUrl(path, 60);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Evidence privat'),
          content: SizedBox(
            width: 600,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Text(
                'Foto tidak dapat ditampilkan atau tautan sudah kedaluwarsa.',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto tidak tersedia dalam cakupan akses Anda.'),
          ),
        );
      }
    }
  }

  Future<void> review(Map<String, dynamic> record, [String? requestId]) async {
    final reason = TextEditingController();
    var decision = requestId == null ? 'VERIFIED' : 'ACKNOWLEDGED';
    var action = const Uuid().v4();
    var busy = false;
    String? failure;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          title: Text(
            requestId == null
                ? 'Verifikasi sumber PI'
                : 'Review sumber oleh Lab',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${record['test_code']}. Tidak mengubah nilai PI, hasil Lab, atau release lot.',
                ),
                DropdownButtonFormField<String>(
                  initialValue: decision,
                  isExpanded: true,
                  items:
                      (requestId == null
                              ? {
                                  'VERIFIED': 'Sumber terverifikasi',
                                  'REVISION_REQUIRED': 'Perlu attempt revisi',
                                }
                              : {
                                  'ACKNOWLEDGED': 'Sumber sudah diperiksa',
                                  'CLARIFICATION_REQUIRED':
                                      'Minta klarifikasi Plant',
                                })
                          .entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                  onChanged: busy
                      ? null
                      : (v) {
                          update(() {
                            decision = v!;
                            action = const Uuid().v4();
                          });
                        },
                ),
                TextField(
                  controller: reason,
                  enabled: !busy,
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Alasan dan rujukan bukti',
                  ),
                  onChanged: (_) => action = const Uuid().v4(),
                ),
                if (failure != null)
                  Text(
                    failure!,
                    style: TextStyle(color: Theme.of(c).colorScheme.error),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(c),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (reason.text.trim().length < 3) {
                        update(
                          () => failure = 'Isi alasan minimal 3 karakter.',
                        );
                        return;
                      }
                      update(() {
                        busy = true;
                        failure = null;
                      });
                      try {
                        await supabase
                            .schema(AppConfig.isolatedApiSchema)
                            .rpc(
                              requestId == null
                                  ? 'review_pi_test'
                                  : 'review_pi_source',
                              params: {
                                'p_test_id': record['id'],
                                if (requestId == null)
                                  'p_expected_version': record['row_version']
                                else
                                  'p_request_id': requestId,
                                'p_decision': decision,
                                'p_reason': reason.text,
                                'p_action_id': action,
                              },
                            );
                        if (c.mounted) Navigator.pop(c);
                      } on Exception {
                        update(() {
                          busy = false;
                          failure =
                              'Review belum terkonfirmasi. Periksa status, versi, role dan koneksi.';
                        });
                      }
                    },
              child: Text(busy ? 'Memproses…' : 'Simpan review'),
            ),
          ],
        ),
      ),
    );
    reason.dispose();
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) {
    final canWrite =
        widget.isPlant &&
        AppConfig.canonicalWritesEnabled &&
        options != null &&
        List<Map<String, dynamic>>.from(
          options!['lots'],
        ).any((l) => l['can_write'] == true);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isPlant ? 'Mutu PI · PP / MC / TSW' : 'Sumber Mutu Plant',
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: loading ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: () => edit(),
              icon: const Icon(Icons.add),
              label: const Text('Catat pengukuran'),
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
                  const WorkflowNote(
                    title: 'Pengukuran mutu PI',
                    text:
                        'PP = kemurnian fisik · MC = kadar air · TSW = berat 1.000 benih. PI mencatat bukti, SPV memverifikasi sumber, dan Lab membaca tanpa mengetik ulang nilai Plant. Bukan pelepasan lot.',
                  ),
                  if (!canWrite)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        widget.isPlant
                            ? 'Input memerlukan penugasan PLANT_PI terpisah. Operator/SPV tidak otomatis PI.'
                            : 'Hanya sumber terkait permintaan dalam cakupan Lab Anda yang ditampilkan.',
                      ),
                    ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (records.isEmpty && error == null)
                    const Text('Belum ada sumber PI dalam cakupan akun Anda.'),
                  for (final r in records)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${r['test_code']} · ${r['test_type']}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Chip(
                                label: Text(
                                  workflowStatus('${r['source_status']}'),
                                ),
                              ),
                            ),
                            SelectableText(
                              '${r['lot_code']} · ${r['site_code']} · attempt ${r['attempt_no']}',
                            ),
                            Text(
                              'Nilai: ${r['numeric_value'] ?? 'Belum diisi'} ${r['unit_code'] == 'PERCENT' ? '%' : 'g'} · ${r['material_form']}',
                            ),
                            Text(
                              'Waktu: ${DateTime.parse(r['tested_at']).toLocal()}',
                            ),
                            Text(
                              'Metode: ${r['method_reference']}\nAlat: ${r['equipment_reference']}\n${r['crop_kind']} / ${r['programme']}',
                            ),
                            Text('${r['notes']}'),
                            if (r['test_type'] == 'TSW')
                              PiTswFormDownload(
                                record: r,
                                isPlant: widget.isPlant,
                              ),
                            if (r['tsw_raw'] != null)
                              TswWeightSummary(
                                raw: Map<String, dynamic>.from(r['tsw_raw']),
                              ),
                            if (Map<String, dynamic>.from(
                              r['assessment'],
                            ).isNotEmpty)
                              Text(
                                'Acuan internal: ${r['assessment']['assessment']}. Bukan sertifikasi SOP/regulasi.',
                              ),
                            if (Map<String, dynamic>.from(
                              r['components'],
                            ).isNotEmpty)
                              ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: const Text('Komponen gram sumber'),
                                children: [
                                  for (final e in Map<String, dynamic>.from(
                                    r['components'],
                                  ).entries)
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        piComponentLabels[e.key] ?? e.key,
                                      ),
                                      trailing: Text('${e.value} g'),
                                    ),
                                ],
                              ),
                            for (final e in List<Map<String, dynamic>>.from(
                              r['evidence'],
                            ))
                              TextButton.icon(
                                onPressed: () => photo(e['path']),
                                icon: const Icon(Icons.lock_outline),
                                label: Text('Foto · ${e['filename']}'),
                              ),
                            if (r['review_reason'] != null)
                              Text('SPV: ${r['review_reason']}'),
                            for (final v in List<Map<String, dynamic>>.from(
                              r['lab_reviews'],
                            ))
                              Text('Lab · ${v['decision']}: ${v['reason']}'),
                            if (canWrite && r['can_write'] == true)
                              TextButton(
                                onPressed: () => edit(r),
                                child: const Text('Lanjutkan draft'),
                              ),
                            if (canWrite && r['can_revise'] == true)
                              TextButton(
                                onPressed: () => edit(r, true),
                                child: const Text('Attempt revisi baru'),
                              ),
                            if (AppConfig.canonicalWritesEnabled &&
                                r['can_review'] == true)
                              TextButton(
                                onPressed: () => review(r),
                                child: const Text('Review sumber PI'),
                              ),
                            if (AppConfig.canonicalWritesEnabled &&
                                !widget.isPlant)
                              for (final q in List<Map<String, dynamic>>.from(
                                r['lab_requests'],
                              ).where((q) => q['can_review'] == true))
                                TextButton(
                                  onPressed: () => review(r, q['id']),
                                  child: Text(
                                    'Review sumber · ${q['request_code']}',
                                  ),
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
                        '${total == 0 ? 0 : offset + 1}–${(offset + 20).clamp(0, total)} / $total',
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
                ],
              ),
            ),
    );
  }
}

class PiTestForm extends StatefulWidget {
  const PiTestForm({
    super.key,
    required this.options,
    this.record,
    this.revision = false,
    this.saveAction,
  });
  final Map<String, dynamic> options;
  final Map<String, dynamic>? record;
  final bool revision;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)? saveAction;
  @override
  State<PiTestForm> createState() => _PiTestFormState();
}

class _PhotoTask {
  _PhotoTask(this.bytes, this.name, this.path, this.mime);
  final Uint8List bytes;
  final String name, path, mime;
  bool registered = false;
}

class _PiTestFormState extends State<PiTestForm> {
  late String id, type, form, crop, programme;
  String? lot, parent, failure, notice;
  late TextEditingController value, method, equipment, notes;
  final components = <String, TextEditingController>{};
  DateTime? testedAt, capturedAt;
  int version = 0;
  Map<String, dynamic>? saved;
  String? fingerprint, action;
  bool busy = false;
  final photos = <_PhotoTask>[];
  bool rawTsw = false;
  late List<TextEditingController> weights;
  @override
  void initState() {
    super.initState();
    final r = widget.record;
    id = r == null || widget.revision ? const Uuid().v4() : r['id'];
    lot = r?['lot_id'];
    type = r?['test_type'] ?? 'PP';
    form = r?['material_form'] ?? 'SEED';
    crop = r?['crop_kind'] ?? 'UNKNOWN';
    programme = r?['programme'] ?? 'UNKNOWN';
    parent = widget.revision ? r!['id'] : r?['revision_of_id'];
    rawTsw = r?['tsw_raw'] != null;
    weights = List.generate(
      8,
      (i) => TextEditingController(
        text: widget.revision ? '' : '${r?['tsw_raw']?['weights_g']?[i] ?? ''}',
      ),
    );
    if (r != null && !widget.revision) {
      saved = r;
      version = r['row_version'];
      testedAt = DateTime.parse(r['tested_at']).toLocal();
    }
    value = TextEditingController(
      text: widget.revision ? '' : '${r?['numeric_value'] ?? ''}',
    );
    method = TextEditingController(text: r?['method_reference'] ?? '');
    equipment = TextEditingController(text: r?['equipment_reference'] ?? '');
    notes = TextEditingController(
      text: widget.revision ? '' : r?['notes'] ?? '',
    );
    for (final k in List<String>.from(widget.options['pp_components'])) {
      components[k] = TextEditingController(
        text: widget.revision ? '' : '${r?['components']?[k] ?? ''}',
      );
    }
  }

  @override
  void dispose() {
    for (final c in [
      value,
      method,
      equipment,
      notes,
      ...weights,
      ...components.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<DateTime?> pickTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted || date == null) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> save(bool submit) async {
    setState(() {
      busy = true;
      failure = null;
      notice = null;
    });
    try {
      if (lot == null || testedAt == null) {
        throw const FormatException('Pilih lot dan waktu pengukuran nyata.');
      }
      final measurement = rawTsw || value.text.trim().isEmpty
          ? null
          : num.tryParse(value.text.trim());
      if (!rawTsw &&
          value.text.trim().isNotEmpty &&
          (measurement == null ||
              !measurement.isFinite ||
              measurement < 0 ||
              measurement > (type == 'TSW' ? 1000000 : 100))) {
        throw const FormatException('Periksa angka dan satuan hasil ukur.');
      }
      final detail = <String, num>{};
      if (type == 'PP') {
        for (final e in components.entries.where(
          (e) => e.value.text.trim().isNotEmpty,
        )) {
          final n = num.tryParse(e.value.text.trim());
          if (n == null || !n.isFinite || n < 0 || n > 1000000) {
            throw const FormatException(
              'Komponen PP harus angka gram, bukan jumlah kernel.',
            );
          }
          detail[e.key] = n;
        }
      }
      final readings = <num?>[];
      if (type == 'TSW' && rawTsw) {
        for (final c in weights) {
          final text = c.text.trim(), n = num.tryParse(c.text.trim());
          if (text.isNotEmpty &&
              (n == null || !n.isFinite || n < 0 || n > 100000)) {
            throw const FormatException(
              'Periksa timbangan per 100 benih, dalam gram.',
            );
          }
          readings.add(text.isEmpty ? null : n);
        }
      }
      final payload = <String, dynamic>{
        'id': id,
        'lot_id': lot,
        'test_type': type,
        'material_form': form,
        'crop_kind': crop,
        'programme': programme,
        'numeric_value': measurement,
        if (type == 'TSW' && rawTsw) 'tsw_weights': readings,
        'tested_at': testedAt!.toUtc().toIso8601String(),
        'method_reference': method.text,
        'equipment_reference': equipment.text,
        'notes': notes.text,
        'seed_count': type == 'TSW' ? 1000 : null,
        'components': detail,
        'expected_version': version,
        'revision_of_id': parent,
        'submit': submit,
      };
      final text = jsonEncode(payload);
      if (text != fingerprint) {
        fingerprint = text;
        action = const Uuid().v4();
      }
      payload['action_id'] = action;
      final r = widget.saveAction != null
          ? await widget.saveAction!(payload)
          : await supabase
                .schema(AppConfig.isolatedApiSchema)
                .rpc<Map<String, dynamic>>(
                  'save_pi_test',
                  params: {'p_document': payload},
                );
      if (!mounted) return;
      setState(() {
        saved = r;
        version = r['row_version'];
        fingerprint = null;
        action = null;
        notice = submit
            ? 'Sumber terkunci dan dikirim ke SPV. Bukan approval Lab atau release lot.'
            : 'Draft tersimpan di server. Unggah foto sebelum submit.';
      });
    } on FormatException catch (e) {
      if (mounted) setState(() => failure = e.message);
    } on Exception {
      if (mounted) {
        setState(
          () => failure =
              'Belum terkonfirmasi. Periksa role/versi, nilai, metode/alat dan foto: PP minimal 1, MC minimal 3. Input dipertahankan untuk retry.',
        );
      }
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> choosePhotos() async {
    try {
      final files = await ImagePicker().pickMultiImage();
      final selected = <_PhotoTask>[];
      for (final f in files) {
        if (f.name.length > 150 ||
            await f.length() > 8388608 ||
            await f.length() == 0) {
          throw const FormatException(
            'Foto maksimal 8 MB dan nama 150 karakter.',
          );
        }
        final bytes = await f.readAsBytes();
        final kind = piImageKind(bytes);
        selected.add(
          _PhotoTask(
            bytes,
            f.name,
            '$id/${const Uuid().v4()}.${kind.extension}',
            kind.mime,
          ),
        );
      }
      if ((saved?['evidence'] as List? ?? []).length + selected.length > 12) {
        throw const FormatException('Maksimal 12 foto per hasil PI.');
      }
      if (mounted) {
        setState(() {
          photos.clear();
          photos.addAll(selected);
          failure = null;
        });
      }
    } on FormatException catch (e) {
      if (mounted) setState(() => failure = e.message);
    } on Exception {
      if (mounted) {
        setState(() => failure = 'Foto belum dipilih. Periksa izin galeri.');
      }
    }
  }

  Future<void> upload() async {
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      if (capturedAt == null || photos.isEmpty) {
        throw const FormatException(
          'Pilih foto dan waktu pengambilan foto nyata.',
        );
      }
      for (final p in photos.where((p) => !p.registered)) {
        try {
          await supabase.storage
              .from('plantlab-pi-evidence')
              .uploadBinary(
                p.path,
                p.bytes,
                fileOptions: FileOptions(contentType: p.mime, upsert: false),
              );
        } on StorageException catch (e) {
          if (e.statusCode != '409') rethrow;
        }
        final r = await supabase
            .schema(AppConfig.isolatedApiSchema)
            .rpc<Map<String, dynamic>>(
              'register_pi_evidence',
              params: {
                'p_test_id': id,
                'p_path': p.path,
                'p_filename': p.name,
                'p_captured_at': capturedAt!.toUtc().toIso8601String(),
              },
            );
        p.registered = true;
        if (!mounted) return;
        setState(() {
          saved = r;
          version = r['row_version'];
        });
      }
      if (mounted) {
        setState(() {
          photos.clear();
          notice =
              'Foto tersimpan privat. Objek diverifikasi; waktu foto adalah pernyataan pengguna.';
        });
      }
    } on FormatException catch (e) {
      if (mounted) setState(() => failure = e.message);
    } on Exception {
      if (mounted) {
        setState(
          () => failure =
              'Upload/registrasi belum terkonfirmasi. File dan path dipertahankan; coba lagi dengan waktu foto yang sama.',
        );
      }
    }
    if (mounted) setState(() => busy = false);
  }

  Widget input(
    String label,
    TextEditingController controller, {
    bool number = false,
    int? maxLength,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextField(
      controller: controller,
      enabled: !busy,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final locked = saved != null && saved!['can_write'] != true;
    final lots = List<Map<String, dynamic>>.from(
      widget.options['lots'],
    ).where((l) => l['can_write'] == true).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.revision ? 'Attempt revisi PI' : 'Pengukuran PI'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Pengukuran nyata, online. PP tidak dihitung dengan mengurangi semua defect. Gram tidak sama dengan jumlah kernel.',
          ),
          if (failure != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                failure!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (notice != null)
            Padding(padding: const EdgeInsets.all(12), child: Text(notice!)),
          if (!locked) ...[
            DropdownButtonFormField<String>(
              initialValue: lot,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Lot / Hybrid / Site',
              ),
              items: lots
                  .map(
                    (l) => DropdownMenuItem<String>(
                      value: l['id'],
                      child: Text(
                        '${l['lot_code']} · ${l['product_name']} · ${l['site_code']}',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: busy || version > 0 || parent != null
                  ? null
                  : (v) {
                      final l = lots.firstWhere((l) => l['id'] == v);
                      setState(() {
                        lot = v;
                        crop = ['FC', 'SWC'].contains(l['crop_category_code'])
                            ? l['crop_category_code']
                            : 'UNKNOWN';
                      });
                    },
            ),
            DropdownButtonFormField<String>(
              initialValue: type,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Jenis pengukuran'),
              items: [
                'PP',
                'MC',
                'TSW',
              ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: busy || version > 0 || parent != null
                  ? null
                  : (v) => setState(() {
                      type = v!;
                      form = 'SEED';
                      value.clear();
                      rawTsw = false;
                      for (final c in weights) {
                        c.clear();
                      }
                    }),
            ),
            DropdownButtonFormField<String>(
              key: ValueKey(type),
              initialValue: form,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Bentuk sampel'),
              items:
                  {
                        'SEED': 'Pipil / seed',
                        if (type == 'MC')
                          'GLEONDONG': 'Gleondong · acuan MC 32% saja',
                      }.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
              onChanged: busy ? null : (v) => setState(() => form = v!),
            ),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      final v = await pickTime();
                      if (v != null && mounted) setState(() => testedAt = v);
                    },
              icon: const Icon(Icons.calendar_month),
              label: Text(
                testedAt == null
                    ? 'Pilih waktu pengukuran nyata'
                    : 'Waktu: $testedAt',
              ),
            ),
            if (type == 'TSW')
              DropdownButtonFormField<bool>(
                key: ValueKey('tsw-basis-$rawTsw'),
                initialValue: rawTsw,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Dasar penimbangan TSW',
                ),
                items: const [
                  DropdownMenuItem(
                    value: false,
                    child: Text(
                      'Timbang langsung 1.000 benih',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: true,
                    child: Text(
                      '8 ulangan × 100 benih',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                onChanged: busy || version > 0 || parent != null
                    ? null
                    : (v) => setState(() {
                        rawTsw = v!;
                        value.clear();
                        for (final c in weights) {
                          c.clear();
                        }
                      }),
              ),
            if (!rawTsw)
              input(
                'Nilai terukur (${type == 'TSW' ? 'g per 1.000 benih' : '%'})',
                value,
                number: true,
              ),
            if (type == 'TSW' && rawTsw)
              TswWeightInputs(
                controllers: weights,
                enabled: !busy,
                onChanged: () => setState(() {}),
              ),
            if (type == 'TSW' && !rawTsw)
              const Text(
                'Berat harus benar-benar mewakili 1.000 benih, bukan berat 100 benih yang diberi label TSW.',
              ),
            DropdownButtonFormField<String>(
              key: ValueKey('crop-$crop'),
              initialValue: crop,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Jenis jagung · deklarasi pengukuran',
              ),
              items:
                  {
                        'UNKNOWN': 'Belum dikonfirmasi',
                        'FC': 'Field Corn',
                        'SWC': 'Sweet Corn',
                      }.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
              onChanged: busy ? null : (v) => setState(() => crop = v!),
            ),
            DropdownButtonFormField<String>(
              initialValue: programme,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Programme · bukan perubahan master',
              ),
              items:
                  {
                        'UNKNOWN': 'Belum dikonfirmasi',
                        'COMMERCIAL': 'Commercial',
                        'PARENT_SEED': 'Parent Seed',
                      }.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
              onChanged: busy ? null : (v) => setState(() => programme = v!),
            ),
            input('Metode / rujukan prosedur', method, maxLength: 300),
            input(
              'Alat / timbangan / moisture meter',
              equipment,
              maxLength: 300,
            ),
            if (type == 'PP')
              ExpansionTile(
                title: const Text('Komponen opsional · gram'),
                children: [
                  for (final e in components.entries)
                    input(
                      '${piComponentLabels[e.key] ?? e.key} (g)',
                      e.value,
                      number: true,
                    ),
                ],
              ),
            input('Catatan / rujukan sampel', notes, maxLength: 1000),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton(
                  onPressed: busy ? null : () => save(false),
                  child: const Text('Simpan draft PI'),
                ),
                FilledButton(
                  onPressed: busy ? null : () => save(true),
                  child: Text(busy ? 'Memproses…' : 'Kirim sumber ke SPV'),
                ),
              ],
            ),
            if (saved?['can_write'] == true) ...[
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Text(
                  'Foto privat: PP minimal 1, MC minimal 3. Maksimal 8 MB per foto. Foto tidak ditimpa/dihapus.',
                ),
              ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () async {
                        final v = await pickTime();
                        if (v != null && mounted) {
                          setState(() => capturedAt = v);
                        }
                      },
                child: Text(
                  capturedAt == null
                      ? 'Pilih waktu pengambilan foto nyata'
                      : 'Waktu foto: $capturedAt',
                ),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : choosePhotos,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Pilih foto galeri'),
              ),
              for (final p in photos)
                Text(
                  '${p.name} · ${p.registered ? 'Terdaftar' : 'Menunggu upload'}',
                ),
              OutlinedButton(
                onPressed: busy || photos.isEmpty ? null : upload,
                child: const Text('Unggah dan daftarkan foto'),
              ),
              Text(
                '${(saved!['evidence'] as List).length} foto terdaftar di server.',
              ),
            ],
          ] else
            const Text(
              'Sumber sudah dikirim dan terkunci. Koreksi melalui attempt baru, bukan menimpa nilai.',
            ),
          if (saved?['tsw_raw'] != null)
            TswWeightSummary(raw: Map<String, dynamic>.from(saved!['tsw_raw'])),
          if (saved?['test_type'] == 'TSW')
            PiTswFormDownload(record: saved!, isPlant: true),
        ],
      ),
    );
  }
}
