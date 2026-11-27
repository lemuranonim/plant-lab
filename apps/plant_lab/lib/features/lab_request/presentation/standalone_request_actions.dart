import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/database/supabase_client.dart';
import 'provisional_quality_reference.dart';

String compactPreviewLotCode(String code) {
  final characters = code.runes.toList();
  if (characters.length <= 24) return code;
  final prefix = String.fromCharCodes(characters.take(7));
  final suffix = String.fromCharCodes(characters.skip(characters.length - 16));
  return '$prefix…$suffix';
}

Widget _lotOptionLabel(String code) => Tooltip(
  message: code,
  excludeFromSemantics: true,
  child: Text(compactPreviewLotCode(code), semanticsLabel: code, maxLines: 2),
);

class StandaloneSubmitDialog extends StatefulWidget {
  const StandaloneSubmitDialog({super.key, this.options});

  /// Allows UI-only tests without initializing a Supabase session.
  final Future<Map<String, dynamic>>? options;

  @override
  State<StandaloneSubmitDialog> createState() => _StandaloneSubmitDialogState();
}

class _StandaloneSubmitDialogState extends State<StandaloneSubmitDialog> {
  late final _options = widget.options ?? _loadOptions();
  Future<Map<String, dynamic>> _loadOptions() async {
    final api = supabase.schema(AppConfig.isolatedApiSchema);
    final options = await api.rpc<Map<String, dynamic>>('get_request_options');
    if (AppConfig.hostedPilot) {
      try {
        options['vigour_methods'] = (await api.rpc<Map<String, dynamic>>(
          'get_vigour_workflow_options_v2',
        ))['methods'];
      } catch (_) {
        options['vigour_options_failed'] = true;
      }
    }
    return options;
  }

  final _instruction = TextEditingController();
  String? _lot, _lab, _test, _lastDetails, _submissionId, _error;
  bool _busy = false;
  String _query = '';
  final _vigourMethods = <String>{};

  @override
  void dispose() {
    _instruction.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!AppConfig.canonicalWritesEnabled ||
        _busy ||
        _lot == null ||
        _lab == null ||
        _test == null) {
      return;
    }
    final params = <String, dynamic>{
      'p_lot_id': _lot,
      'p_target_lab_site_id': _lab,
      if (AppConfig.hostedPilot && _test == 'VIGOUR')
        'p_method_codes': (_vigourMethods.toList()..sort())
      else
        'p_test_code': _test,
      'p_sampling_instruction': _instruction.text.trim(),
    };
    final details = jsonEncode(params);
    if (_lastDetails != details) {
      _lastDetails = details;
      _submissionId = const Uuid().v4();
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await supabase
          .schema(AppConfig.isolatedApiSchema)
          .rpc<Map<String, dynamic>>(
            AppConfig.hostedPilot && _test == 'VIGOUR'
                ? 'submit_vigour_request'
                : 'submit_plant_lab_request',
            params: {...params, 'p_submission_id': _submissionId},
          );
      if (mounted) Navigator.of(context).pop(result['request_code'] as String);
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.code == '23505'
              ? 'Sudah ada permintaan aktif untuk lot dan jenis uji ini.'
              : 'Pengajuan gagal. Periksa pilihan dan akses.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Koneksi terputus. Coba ulang dengan pilihan yang sama.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Map<String, dynamic>> _rows(Map<String, dynamic> options, String key) =>
      (options[key] as List? ?? const []).cast<Map<String, dynamic>>();

  Widget _select(
    String label,
    String? value,
    List<DropdownMenuItem<String>> items,
    ValueChanged<String?> onChanged,
  ) => DropdownButtonFormField<String>(
    key: ValueKey((label, value)),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: items,
    onChanged: _busy ? null : onChanged,
  );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: const Text('Ajukan Permintaan Uji'),
        content: FutureBuilder<Map<String, dynamic>>(
          future: _options,
          builder: (context, state) {
            if (state.hasError) {
              return const Text('Pilihan pengajuan gagal dimuat.');
            }
            if (!state.hasData) return const LinearProgressIndicator();
            final options = state.requireData;
            final lots = _rows(options, 'lots');
            final visibleLots = filterReferenceLots(lots, _query, _lot);
            if (lots.isEmpty) {
              return const Text('Belum ada lot dalam cakupan Anda.');
            }
            final company = lots
                .where((lot) => lot['id'] == _lot)
                .firstOrNull?['company_id'];
            final labs = _rows(
              options,
              'lab_sites',
            ).where((lab) => lab['company_id'] == company);
            final tests = _rows(options, 'test_types').where(
              (test) =>
                  !AppConfig.hostedPilot ||
                  test['test_code'] == 'GERMINATION' ||
                  (test['test_code'] == 'VIGOUR' &&
                      _rows(options, 'vigour_methods').isNotEmpty),
            );
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (AppConfig.hostedPilot)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Lot berasal dari Excel asli. Ajukan hanya pekerjaan atau pengujian ulang yang benar-benar dilakukan. RET memakai radikula ≥2 mm, 4×100 dan pengamatan setelah minimal 72 jam pada 16°C.',
                      ),
                    ),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Cari kode lot',
                      hintText: 'Contoh: DEMO-RR-0002',
                      prefixIcon: Icon(Icons.search),
                    ),
                    enabled: !_busy,
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  Text(
                    '${visibleLots.length} pilihan ditampilkan dari ${lots.length} lot dalam cakupan Anda.',
                  ),
                  if (options['lots_truncated'] == true)
                    const Text(
                      'Sebagian lot belum dimuat. Hubungi administrator jika kode yang dicari belum tersedia.',
                    ),
                  if (visibleLots.isEmpty)
                    const Text(
                      'Kode lot tidak ditemukan. Periksa kode atau cakupan site Anda.',
                    ),
                  _select(
                    'Lot',
                    _lot,
                    [
                      for (final lot in visibleLots)
                        DropdownMenuItem(
                          value: lot['id'] as String,
                          child: _lotOptionLabel(lot['lot_code'] as String),
                        ),
                    ],
                    (value) => setState(() {
                      _lot = value;
                      _lab = null;
                    }),
                  ),
                  _select('Lab tujuan', _lab, [
                    for (final lab in labs)
                      DropdownMenuItem(
                        value: lab['id'] as String,
                        child: Text(lab['site_name'] as String),
                      ),
                  ], (value) => setState(() => _lab = value)),
                  _select('Jenis uji', _test, [
                    for (final test in tests)
                      DropdownMenuItem(
                        value: test['test_code'] as String,
                        child: Text(test['test_name'] as String),
                      ),
                  ], (value) => setState(() => _test = value)),
                  if (options['vigour_options_failed'] == true)
                    const Text(
                      'Pilihan Vigor belum bisa dimuat; tidak memakai metode tebakan.',
                    ),
                  if (AppConfig.hostedPilot && _test == 'VIGOUR') ...[
                    const Text(
                      'Metode Vigor yang diminta · boleh lebih dari satu',
                    ),
                    for (final method in _rows(options, 'vigour_methods'))
                      CheckboxListTile(
                        title: Text(method['method_name'] as String),
                        contentPadding: EdgeInsets.zero,
                        value: _vigourMethods.contains(method['method_code']),
                        onChanged: _busy
                            ? null
                            : (checked) => setState(() {
                                if (checked == true) {
                                  _vigourMethods.add(
                                    method['method_code'] as String,
                                  );
                                } else {
                                  _vigourMethods.remove(method['method_code']);
                                }
                              }),
                      ),
                  ],
                  TextField(
                    controller: _instruction,
                    decoration: const InputDecoration(
                      labelText: 'Instruksi opsional',
                    ),
                    enabled: !_busy,
                    maxLength: 500,
                  ),
                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed:
                _busy ||
                    _lot == null ||
                    _lab == null ||
                    _test == null ||
                    (AppConfig.hostedPilot &&
                        _test == 'VIGOUR' &&
                        _vigourMethods.isEmpty)
                ? null
                : _submit,
            child: Text(_busy ? 'Mengajukan…' : 'Ajukan ke Lab'),
          ),
        ],
      ),
    );
  }
}

class StandaloneAcceptButton extends StatefulWidget {
  const StandaloneAcceptButton({
    super.key,
    required this.requestId,
    required this.onAccepted,
  });

  final String requestId;
  final VoidCallback onAccepted;

  @override
  State<StandaloneAcceptButton> createState() => _StandaloneAcceptButtonState();
}

class _StandaloneAcceptButtonState extends State<StandaloneAcceptButton> {
  bool _busy = false;

  Future<void> _accept() async {
    if (!AppConfig.canonicalWritesEnabled || _busy) return;
    setState(() => _busy = true);
    try {
      await supabase
          .schema(AppConfig.isolatedApiSchema)
          .rpc(
            'accept_plant_lab_request',
            params: {'p_request_id': widget.requestId},
          );
      if (mounted) widget.onAccepted();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tidak dapat menerima. Muat ulang antrean lalu coba lagi.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: _busy ? null : _accept,
    child: Text(_busy ? 'Memproses…' : 'Terima permintaan'),
  );
}
