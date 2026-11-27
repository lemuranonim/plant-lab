import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/database/supabase_client.dart';
import 'lab_workspace_widgets.dart';

typedef HistoryLoader =
    Future<Map<String, dynamic>?> Function(
      String lotId,
      String module,
      int offset,
    );

const _pageSize = 3;
const _phaseNames = {
  'FIRST_COUNT': 'Pengamatan awal',
  'FINAL_COUNT': 'Pengamatan final',
  'CONTEXT': 'Konteks lot',
  'SOURCE_CYCLE': 'Siklus sumber',
  'LATEST_SUMMARY': 'Ringkasan terbaru sumber',
};
const _reviewLabels = {
  'SOURCE_SUMMARY_NOT_QA_APPROVAL':
      'Kesimpulan Excel bukan approval QA aplikasi.',
  'FIRST_COUNT_NO_MISSING_COUNTS_IMPUTED':
      'Komponen kosong pada pengamatan awal tidak diisi dengan nol.',
  'GERMINATION_MEDIUM_UNSPECIFIED':
      'Media germinasi tidak disebutkan; tidak diasumsikan Sand.',
  'OBSERVATION_DATE_CALCULATED_NOT_ACTUAL_EVIDENCE':
      'Tanggal hasil rumus, bukan bukti pengamatan aktual.',
  'UNEQUAL_OR_ZERO_SUBUNIT_TOTALS':
      'Total subunit tidak seimbang atau nol. Perlu tinjauan.',
  'OBSERVATION_DATE_MISSING': 'Tanggal pengamatan belum tercatat.',
  'START_DATE_MISSING': 'Tanggal mulai belum tercatat.',
  'MISSING_OR_INVALID_FINAL_COUNTS':
      'Hitungan final belum lengkap atau tidak valid.',
  'REPLICATE_LAYOUT_REVIEW': 'Susunan ulangan perlu ditinjau.',
};

String historyValue(Object? value) =>
    value == null || value == '' ? 'Belum dicatat' : value.toString();

String _date(Object? value, Object? origin) => value == null
    ? 'Belum dicatat'
    : '$value · ${origin == 'FORMULA_CACHE' ? 'hasil rumus sumber, bukan bukti aktual' : 'tanggal sumber'}';

List<Map<String, dynamic>> _maps(Object? value) =>
    (value as List? ?? const []).cast<Map<String, dynamic>>();

/// Only reads the scoped API. No histories are cached across accounts/screens.
class HistoricalQualityScreen extends StatefulWidget {
  const HistoricalQualityScreen({
    super.key,
    required this.module,
    this.requestLots = const [],
    this.options,
    this.loader,
  });
  final String module;
  final List<Map<String, dynamic>> requestLots;
  final Future<Map<String, dynamic>>? options;
  final HistoryLoader? loader;

  @override
  State<HistoricalQualityScreen> createState() =>
      _HistoricalQualityScreenState();
}

class _HistoricalQualityScreenState extends State<HistoricalQualityScreen> {
  late Future<Map<String, dynamic>> _options;
  String _query = '';
  String? _lot;
  Map<String, dynamic>? _history;
  String? _message;
  bool _busy = false;
  int _offset = 0;
  int _attempt = 0;

  Future<Map<String, dynamic>> _loadOptions() async {
    if (widget.options != null) return widget.options!;
    if (widget.module == 'PLANT') {
      return supabase
          .schema(AppConfig.isolatedApiSchema)
          .rpc<Map<String, dynamic>>('get_request_options');
    }
    return {'lots': widget.requestLots};
  }

  @override
  void initState() {
    super.initState();
    _options = _loadOptions();
  }

  void _select(String? lot) {
    _attempt++;
    setState(() {
      _lot = lot;
      _history = null;
      _message = null;
      _busy = false;
      _offset = 0;
    });
  }

  Future<void> _load(int offset) async {
    if (_lot == null || _busy) return;
    final attempt = ++_attempt;
    final lot = _lot!;
    setState(() {
      _busy = true;
      _history = null;
      _message = null;
    });
    try {
      final result = await (widget.loader != null
          ? widget.loader!(lot, widget.module, offset)
          : supabase
                .schema(AppConfig.isolatedApiSchema)
                .rpc<Map<String, dynamic>?>(
                  'get_lot_historical_quality',
                  params: {
                    'p_lot_id': lot,
                    'p_module': widget.module,
                    'p_limit': _pageSize,
                    'p_offset': offset,
                  },
                ));
      if (!mounted || attempt != _attempt) return;
      if (result == null) {
        setState(
          () => _message = 'Histori tidak tersedia dalam cakupan akses Anda.',
        );
      } else {
        if (result['history_status'] != 'SOURCE_HISTORY_NOT_APP_APPROVED' ||
            result['records'] is! List) {
          throw StateError('Unsupported history contract');
        }
        setState(() {
          _history = result;
          _offset = offset;
        });
      }
    } catch (_) {
      if (mounted && attempt == _attempt) {
        setState(
          () => _message =
              'Histori gagal dimuat. Tidak menggunakan data lama. Coba lagi.',
        );
      }
    } finally {
      if (mounted && attempt == _attempt) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Histori Excel')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _options,
      builder: (context, snapshot) {
        final labStyle = widget.module == 'LAB';
        final unique = {
          for (final lot in _maps(snapshot.data?['lots']))
            lot['id'] as String: lot,
        };
        final lots = unique.values
            .where(
              (lot) =>
                  lot['id'] == _lot ||
                  (lot['lot_code'] as String).toUpperCase().contains(
                    _query.trim().toUpperCase(),
                  ),
            )
            .toList();
        final lotFields = [
          TextField(
            decoration: InputDecoration(
              labelText: 'Cari lot histori',
              prefixIcon: labStyle ? const Icon(Icons.search) : null,
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(_lot),
            initialValue: _lot,
            isExpanded: true,
            itemHeight: labStyle ? null : kMinInteractiveDimension,
            decoration: const InputDecoration(labelText: 'Lot histori'),
            items: lots
                .map(
                  (lot) => DropdownMenuItem(
                    value: lot['id'] as String,
                    child: Text(
                      lot['lot_code'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _select,
          ),
          const SizedBox(height: 8),
          Text('${lots.length} pilihan ditampilkan dari ${unique.length} lot.'),
          if (labStyle && lots.isEmpty)
            const Text(
              'Kode lot belum ditemukan. Cek kembali kode yang dicari.',
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _lot == null || _busy ? null : () => _load(0),
            child: Text(_busy ? 'Memuat histori…' : 'Tampilkan histori'),
          ),
        ];
        final children = <Widget>[
          if (labStyle)
            const LabReadOnlyIntro(
              title: 'Arsip sumber Excel',
              icon: Icons.inventory_2_outlined,
              description:
                  'Bukan hasil yang disetujui QA aplikasi atau izin pelepasan lot. Acuan mutu saat ini tidak diterapkan ulang pada histori.',
            )
          else
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Arsip sumber · Baca-saja\nBukan hasil yang disetujui QA aplikasi atau izin pelepasan lot. '
                  'Acuan mutu saat ini tidak diterapkan ulang pada histori.',
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            widget.module == 'LAB'
                ? 'Lab: hanya lot pada permintaan yang berizin. Fase QI tanpa tahap yang jelas tidak ditampilkan.'
                : 'Plant: lot dalam cakupan site Anda.',
          ),
          const Text(
            'Batch saat ini H59/SWC; tidak semua lot mempunyai histori terpetakan.',
          ),
          const SizedBox(height: 16),
          if (snapshot.connectionState != ConnectionState.done)
            const LinearProgressIndicator(),
          if (snapshot.hasError)
            TextButton(
              onPressed: () => setState(() => _options = _loadOptions()),
              child: const Text('Pilihan histori gagal dimuat. Coba lagi'),
            ),
          if (snapshot.hasData) ...[
            if (snapshot.data?['lots_truncated'] == true)
              const Text(
                'Daftar dibatasi API. Lot di luar daftar belum dapat dipilih di tampilan ini.',
              ),
            if (unique.isEmpty)
              const Text('Belum ada lot yang dapat dipilih dalam cakupan Anda.')
            else if (labStyle)
              LabFormCard(
                title: 'Pilih lot di arsip',
                icon: Icons.search,
                hint:
                    'Cari kode lot, pilih dari daftar, lalu tampilkan histori.',
                children: lotFields,
              )
            else
              ...lotFields,
          ],
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Semantics(liveRegion: true, child: Text(_message!)),
            ),
          if (_history != null) ...[
            const SizedBox(height: 16),
            HistoricalQualityContent(data: _history!, labStyle: labStyle),
            if ((_history!['total_records'] as int) > 0) ...[
              const SizedBox(height: 12),
              Text(
                'Rekaman ${_offset + 1}–${_offset + (_history!['records'] as List).length} '
                'dari ${_history!['total_records']}. Satu rekaman sumber dapat memuat beberapa fase.',
              ),
              Wrap(
                spacing: 12,
                children: [
                  TextButton(
                    onPressed: _busy || _offset == 0
                        ? null
                        : () => _load((_offset - _pageSize).clamp(0, _offset)),
                    child: const Text('Sebelumnya'),
                  ),
                  TextButton(
                    onPressed:
                        _busy ||
                            _offset + (_history!['records'] as List).length >=
                                (_history!['total_records'] as int)
                        ? null
                        : () => _load(_offset + _pageSize),
                    child: const Text('Berikutnya'),
                  ),
                ],
              ),
            ],
          ],
        ];
        return labStyle
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              )
            : ListView(padding: const EdgeInsets.all(16), children: children);
      },
    ),
  );
}

class HistoricalQualityContent extends StatelessWidget {
  const HistoricalQualityContent({
    super.key,
    required this.data,
    this.labStyle = false,
  });
  final Map<String, dynamic> data;
  final bool labStyle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Histori lot ${data['lot_code']}',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      if (data['total_records'] == 0)
        const Text(
          'Belum ada histori terpetakan yang dapat dibaca untuk lot ini. Ini bukan hasil nol atau gagal uji.',
        ),
      for (final record in _maps(data['records']))
        Card(
          child: ExpansionTile(
            key: ValueKey(record['id']),
            shape: labStyle ? const Border() : null,
            collapsedShape: labStyle ? const Border() : null,
            leading: labStyle ? const Icon(Icons.description_outlined) : null,
            title: Text(
              record['source_type'] == 'QUALITY_INFORMATION_2026'
                  ? 'Quality Information'
                  : 'Germinasi / Vigor',
            ),
            subtitle: Text(
              '${record['sheet']} · baris ${record['source_row']} · mapping v${record['mapping_version']}',
            ),
            childrenPadding: const EdgeInsets.all(12),
            children: [
              SelectableText('${record['source_file_name']}'),
              if (record['source_testing_type'] != null)
                Text('Jenis sumber: ${record['source_testing_type']}'),
              for (final phase in _maps(record['phases']))
                _SourcePhase(phase: phase, labStyle: labStyle),
            ],
          ),
        ),
    ],
  );
}

class _SourcePhase extends StatelessWidget {
  const _SourcePhase({required this.phase, required this.labStyle});
  final Map<String, dynamic> phase;
  final bool labStyle;

  @override
  Widget build(BuildContext context) {
    final rows = _maps(phase['subunits']);
    final values = _maps(phase['values']);
    final facts = [
      ('Metode sumber', historyValue(phase['source_method_label'])),
      ('Tahap lot sumber', historyValue(phase['source_stage'])),
      (
        'Tanggal mulai',
        _date(phase['source_planted_date'], phase['source_planted_origin']),
      ),
      (
        'Tanggal pengamatan',
        _date(
          phase['source_observation_date'],
          phase['source_observation_origin'],
        ),
      ),
      (
        'Persentase sumber',
        phase['source_percent'] == null
            ? 'Belum dicatat'
            : '${phase['source_percent']}%',
      ),
      (
        'Hitung ulang diagnostik',
        phase['diagnostic_percent'] == null
            ? 'Tidak dihitung / data tidak cukup'
            : '${phase['diagnostic_percent']}%',
      ),
    ];
    return ExpansionTile(
      shape: labStyle ? const Border() : null,
      collapsedShape: labStyle ? const Border() : null,
      title: Text(
        '${_phaseNames[phase['kind']] ?? phase['kind']} · ${phase['label']}',
      ),
      childrenPadding: const EdgeInsets.symmetric(vertical: 8),
      expandedCrossAxisAlignment: labStyle
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.center,
      children: [
        if (labStyle)
          LabFieldGrid(
            fields: [
              for (final (label, value) in facts) LabRecordValue(label, value),
            ],
          )
        else
          for (final (label, value) in facts) _FactLine(label, value),
        if (phase['source_conclusion'] != null)
          _FactLine(
            'Keterangan Excel',
            '${phase['source_conclusion']} · bukan approval QA aplikasi',
          ),
        for (final code in (phase['review_codes'] as List? ?? []))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _FactLine('Catatan', _reviewLabels[code] ?? '$code'),
          ),
        if (rows.isNotEmpty) ...[
          const Text(
            'Hitungan asli per subunit · — berarti belum dicatat, bukan nol',
          ),
          if (labStyle)
            for (final row in rows)
              Card.filled(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "${row['label'] ?? 'Tanpa label'} · Baris ${row['source_row']}",
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      LabFieldGrid(
                        minFieldWidth: 86,
                        fields: [
                          for (final e in const {
                            'normal': 'Normal',
                            'abnormal': 'Abnormal',
                            'dead': 'Mati',
                            'total': 'Total',
                          }.entries)
                            LabRecordValue(e.value, '${row[e.key] ?? '—'}'),
                        ],
                      ),
                    ],
                  ),
                ),
              )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 18,
                columns: [
                  for (final label in [
                    'Subunit / baris',
                    'Normal',
                    'Abnormal',
                    'Mati',
                    'Total',
                  ])
                    DataColumn(label: Text(label)),
                ],
                rows: [
                  for (final row in rows)
                    DataRow(
                      cells: [
                        DataCell(
                          Text(
                            '${row['label'] ?? 'Tanpa label'} / ${row['source_row']}',
                          ),
                        ),
                        for (final name in [
                          'normal',
                          'abnormal',
                          'dead',
                          'total',
                        ])
                          DataCell(Text('${row[name] ?? '—'}')),
                      ],
                    ),
                ],
              ),
            ),
        ],
        ExpansionTile(
          shape: labStyle ? const Border() : null,
          collapsedShape: labStyle ? const Border() : null,
          title: Text('Nilai sumber & posisi sel (${values.length})'),
          children: [
            for (final value in values)
              ListTile(
                dense: true,
                isThreeLine: false,
                title: Text('${value['coordinate']} · ${value['header']}'),
                subtitle: Text(
                  [
                    if (value['header_band'] != null) '${value['header_band']}',
                    '${historyValue(value['date'] ?? value['number'] ?? value['source_value'])} · ${value['unit']}',
                    value['origin'] == 'FORMULA_CACHE'
                        ? 'Cache rumus sumber'
                        : '${value['origin']}',
                    if (value['warning'] != null) '${value['warning']}',
                  ].join('\n'),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _FactLine extends StatelessWidget {
  const _FactLine(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text('$label: $value'),
    ),
  );
}
