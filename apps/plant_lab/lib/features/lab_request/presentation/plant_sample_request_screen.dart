import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/database/supabase_client.dart';
import 'lab_logbook_screen.dart';

typedef PlantSampleRpc =
    Future<Map<String, dynamic>> Function(
      String command,
      Map<String, dynamic> params,
    );

const plantSampleStatuses = {
  'ALL': 'Semua',
  'ACTIVE': 'Belum selesai',
  'REQUESTED': 'Menunggu Plant',
  'SENT': 'Dikirim · menunggu Lab',
  'RECEIVED': 'Diterima Lab',
  'DECLINED': 'Tidak dapat dipenuhi',
  'CANCELLED': 'Dibatalkan',
};
const plantSampleActions = {
  'CREATE': 'Kirim permintaan',
  'SEND': 'Catat sudah dikirim',
  'RECEIVE': 'Konfirmasi sampel diterima',
  'DECLINE': 'Tidak bisa memenuhi',
  'CANCEL': 'Batalkan permintaan',
};

num? plantSampleGrams(String text) {
  final value = text.trim().replaceAll(',', '.');
  if (!RegExp(r'^[0-9]{1,9}(\.[0-9]{1,3})?$').hasMatch(value)) return null;
  final number = num.parse(value);
  return number > 0 ? number : null;
}

class PlantSampleRequestScreen extends StatefulWidget {
  const PlantSampleRequestScreen({
    super.key,
    required this.module,
    this.rpc,
    this.writesEnabled = AppConfig.canonicalWritesEnabled,
  });
  final String module;
  final PlantSampleRpc? rpc;
  final bool writesEnabled;

  @override
  State<PlantSampleRequestScreen> createState() =>
      _PlantSampleRequestScreenState();
}

class _PlantSampleRequestScreenState extends State<PlantSampleRequestScreen> {
  final search = TextEditingController(), lotSearch = TextEditingController();
  final label = TextEditingController(),
      weight = TextEditingController(),
      note = TextEditingController();
  Map<String, dynamic>? page, editingRow, chosenLot, pending;
  List<Map<String, dynamic>> sites = [], lots = [];
  String? site, action, error, editorError, notice;
  String status = 'ACTIVE', appliedSearch = '', appliedLot = '';
  bool busy = false, confirmed = false, moreLots = false;
  int offset = 0, lotOffset = 0;
  bool get lab => widget.module == 'LAB';
  bool get weighing => action == 'SEND' || action == 'RECEIVE';
  bool get canWrite => widget.writesEnabled && page?['can_write'] == true;
  bool get editingLocked => busy || pending != null;
  Future<Map<String, dynamic>> rpc(
    String name,
    Map<String, dynamic> args,
  ) async =>
      widget.rpc?.call(name, args) ??
      supabase
          .schema(AppConfig.isolatedApiSchema)
          .rpc<Map<String, dynamic>>(name, params: args);

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    for (final field in [search, lotSearch, label, weight, note]) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> load([int start = 0]) async {
    if (busy || action != null) return;
    setState(() {
      busy = true;
      page = null;
      error = null;
      offset = start;
    });
    try {
      final value = await rpc('list_plant_sample_requests', {
        'p_module': widget.module,
        'p_site_id': site,
        'p_search': appliedSearch,
        'p_status': status,
        'p_offset': start,
      });
      if (value['version'] != 1 ||
          value['offset'] != start ||
          value['selected_site_id'] is! String ||
          (site != null && value['selected_site_id'] != site)) {
        throw const FormatException('Scope changed');
      }
      final listed = (value['sites'] as List).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        sites = listed;
        site = value['selected_site_id'];
        page = value;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Daftar belum bisa dimuat. Periksa koneksi atau penugasan.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void open(String next, [Map<String, dynamic>? row]) {
    setState(() {
      action = next;
      editingRow = row;
      label.clear();
      weight.clear();
      note.clear();
      lotSearch.clear();
      chosenLot = null;
      lots = [];
      lotOffset = 0;
      moreLots = false;
      pending = null;
      editorError = null;
      confirmed = false;
      notice = null;
    });
    if (next == 'CREATE') findLots('');
  }

  Future<void> findLots(String query, [int start = 0]) async {
    if (editingLocked) return;
    setState(() {
      busy = true;
      editorError = null;
      lots = [];
      moreLots = false;
    });
    try {
      final value = await rpc('get_routine_lab_options', {
        'p_lab_site_id': site,
        'p_search': query,
        'p_offset': start,
      });
      if (value['selected_lab_site_id'] != site || value['can_write'] != true) {
        throw const FormatException('Scope changed');
      }
      final listed = (value['lots'] as List).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        lots = listed;
        lotOffset = start;
        appliedLot = query;
        moreLots = value['has_more'] == true;
      });
    } catch (_) {
      if (mounted) {
        setState(() => editorError = 'Lot belum bisa dimuat. Coba cari lagi.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (busy || !canWrite || action == null) return;
    final grams = weighing ? plantSampleGrams(weight.text) : null;
    if (pending == null &&
        (!confirmed ||
            note.text.trim().isEmpty ||
            (action == 'CREATE' && chosenLot == null) ||
            (weighing && (grams == null || label.text.trim().isEmpty)) ||
            (action == 'RECEIVE' &&
                label.text.trim() != editingRow?['sample_label']))) {
      setState(
        () => editorError =
            'Lengkapi isian dan konfirmasi. Label penerimaan harus sama dengan label pada kiriman.',
      );
      return;
    }
    setState(() {
      busy = true;
      editorError = null;
      pending ??= {
        'p_module': widget.module,
        'p_action': action,
        'p_action_id': const Uuid().v4(),
        'p_request_id': editingRow?['id'],
        'p_lab_site_id': action == 'CREATE' ? site : null,
        'p_lot_id': action == 'CREATE' ? (chosenLot?['id']) : null,
        'p_note': note.text.trim(),
        'p_sample_label': weighing ? label.text.trim() : null,
        'p_grams': grams,
      };
    });
    var completed = false;
    try {
      final result = await rpc('record_plant_sample_request', pending!);
      if (result['id'] is! String) {
        throw const FormatException('Missing confirmation');
      }
      completed = true;
      if (mounted) {
        setState(() {
          action = null;
          pending = null;
          notice = 'Catatan tersimpan.';
        });
      }
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final explanation = switch (e.code) {
        '42501' => 'Akses atau lokasi tidak sesuai.',
        '22023' => 'Periksa isian, termasuk label fisik dan berat.',
        '55000' || '23505' =>
          'Status atau rincian sudah berubah. Tutup isian lalu muat ulang daftar.',
        _ => null,
      };
      setState(() {
        if (explanation != null) pending = null;
        editorError =
            explanation ??
            'Belum ada balasan server. Coba kirim ulang isian yang sama.';
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => editorError =
              'Belum ada balasan server. Coba kirim ulang isian yang sama.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (mounted && completed) await load();
  }

  Widget field(
    String name,
    TextEditingController controller,
    int max, {
    bool decimal = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      enabled: !editingLocked,
      controller: controller,
      keyboardType: decimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      maxLength: max,
      decoration: InputDecoration(labelText: name),
    ),
  );

  Widget editor() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            plantSampleActions[action]!,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (editingRow != null) Text('Lot ${editingRow!['lot_code']}'),
          if (action == 'CREATE') ...[
            field('Cari lot untuk diminta', lotSearch, 100),
            OutlinedButton(
              onPressed: editingLocked
                  ? null
                  : () => findLots(lotSearch.text.trim()),
              child: const Text('Cari lot'),
            ),
            Text(
              chosenLot == null
                  ? 'Pilih lot yang benar. Tujuan mengikuti Plant pemilik lot.'
                  : 'Dipilih: ${chosenLot!['lot_code']} · ${chosenLot!['plant_site']}',
            ),
            if (pending == null) ...[
              for (final lot in lots)
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => setState(() => chosenLot = lot),
                  child: Text(
                    "${lot['lot_code']} · ${lot['hybrid']} · ${lot['stage_code']} · ${lot['plant_site']}",
                  ),
                ),
              if (lotOffset > 0)
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => findLots(appliedLot, lotOffset - 50),
                  child: const Text('Lot sebelumnya'),
                ),
              if (moreLots)
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => findLots(appliedLot, lotOffset + 50),
                  child: const Text('Lot berikutnya'),
                ),
            ],
          ],
          if (action == 'RECEIVE')
            Text(
              'Label kiriman Plant: ${editingRow?['sample_label']}. Jika berbeda, jangan konfirmasi; hubungi Plant.',
            ),
          if (weighing) ...[
            field('Label pada sampel fisik', label, 120),
            field('Berat aktual (gram)', weight, 13, decimal: true),
          ],
          field(
            action == 'CREATE'
                ? 'Keperluan sampel'
                : weighing
                ? 'Kondisi kemasan/sampel'
                : 'Alasan',
            note,
            500,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: confirmed,
            onChanged: editingLocked
                ? null
                : (v) => setState(() => confirmed = v == true),
            title: Text(
              action == 'SEND'
                  ? 'Sampel benar-benar sudah dikirim.'
                  : action == 'RECEIVE'
                  ? 'Sampel fisik sudah diterima dan labelnya cocok.'
                  : 'Lot dan rincian tindakan sudah saya periksa.',
            ),
          ),
          if (editorError != null)
            Text(
              editorError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          FilledButton(
            onPressed: busy ? null : save,
            child: Text(
              pending != null
                  ? 'Coba kirim ulang'
                  : plantSampleActions[action]!,
            ),
          ),
          TextButton(
            onPressed: editingLocked
                ? null
                : () => setState(() => action = null),
            child: const Text('Tutup isian'),
          ),
        ],
      ),
    ),
  );

  Widget row(Map<String, dynamic> value) {
    final state = value['status'];
    final choices = lab
        ? (state == 'SENT'
              ? ['RECEIVE']
              : state == 'REQUESTED'
              ? ['CANCEL']
              : [])
        : (state == 'REQUESTED' ? ['SEND', 'DECLINE'] : []);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${value['lot_code']} · ${value['hybrid']}",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(plantSampleStatuses[state] ?? 'Status tidak diketahui'),
            Text("${value['plant_site']} → ${value['lab_site']}"),
            Text(
              "Keperluan: ${value['purpose']} · ${logbookWib(value['requested_at'])}",
            ),
            if (value['sample_label'] != null)
              Text("Label: ${value['sample_label']}"),
            if (value['sent_at'] != null)
              Text(
                "Dikirim: ${value['sent_grams']} g · ${value['sent_note']} · ${logbookWib(value['sent_at'])}",
              ),
            if (value['received_at'] != null)
              Text(
                "Diterima: ${value['received_grams']} g · ${value['received_note']} · ${logbookWib(value['received_at'])}",
              ),
            if (value['closure_note'] != null)
              Text("Alasan: ${value['closure_note']}"),
            if (canWrite && action == null)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final next in choices)
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => open(next as String, value),
                      child: Text(plantSampleActions[next]!),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        lab ? 'Permintaan sampel ke Plant' : 'Permintaan sampel dari Lab',
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          lab
              ? 'Minta sampel lot yang sudah tercatat. Konfirmasi setelah sampel fisik diterima dan labelnya cocok.'
              : 'Catat pengiriman hanya setelah sampel benar-benar dikirim.',
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Menu ini hanya untuk serah terima. Tidak memulai uji atau melepas lot.',
          ),
        ),
        if (sites.isNotEmpty)
          DropdownButtonFormField<String>(
            initialValue: site,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: lab ? 'Lokasi Lab' : 'Lokasi Plant',
            ),
            items: [
              for (final s in sites)
                DropdownMenuItem<String>(
                  value: s['id'],
                  child: Text(s['site_name'], overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: busy || action != null
                ? null
                : (v) {
                    setState(() => site = v);
                    load();
                  },
          ),
        TextField(
          enabled: !busy && action == null,
          controller: search,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'Cari lot, hybrid, atau label',
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: status,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Status'),
          items: [
            for (final key in plantSampleStatuses.keys)
              DropdownMenuItem(
                value: key,
                child: Text(
                  plantSampleStatuses[key]!,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: busy || action != null
              ? null
              : (v) {
                  setState(() => status = v ?? 'ACTIVE');
                  load();
                },
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: busy || action != null
                  ? null
                  : () {
                      appliedSearch = search.text.trim();
                      load();
                    },
              child: const Text('Tampilkan'),
            ),
            if (lab && canWrite)
              FilledButton(
                onPressed: busy || action != null ? null : () => open('CREATE'),
                child: const Text('Minta sampel'),
              ),
          ],
        ),
        if (busy) const LinearProgressIndicator(),
        if (notice != null) Text(notice!),
        if (error != null) ...[
          Text(error!),
          TextButton(
            onPressed: busy ? null : () => load(offset),
            child: const Text('Muat ulang'),
          ),
        ],
        if (action != null) editor(),
        if (page != null) ...[
          Text("${page!['total']} permintaan"),
          if ((page!['rows'] as List).isEmpty)
            const Text('Tidak ada permintaan pada lokasi dan filter ini.'),
          for (final item
              in (page!['rows'] as List).cast<Map<String, dynamic>>())
            row(item),
          Wrap(
            spacing: 8,
            children: [
              if (offset > 0)
                OutlinedButton(
                  onPressed: busy || action != null
                      ? null
                      : () => load(offset - 30),
                  child: const Text('Sebelumnya'),
                ),
              if (page!['has_more'] == true)
                OutlinedButton(
                  onPressed: busy || action != null
                      ? null
                      : () => load(offset + 30),
                  child: const Text('Berikutnya'),
                ),
            ],
          ),
        ],
      ],
    ),
  );
}
