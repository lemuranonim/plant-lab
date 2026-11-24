import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/database/supabase_client.dart';
import 'request_seedling_form_download.dart';
import 'routine_form_download.dart';

Future<Map<String, dynamic>> listRequestGerminationForms(
  String requestId,
) async {
  if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(requestId)) {
    throw const FormatException('Nomor permintaan tidak benar.');
  }
  return await supabase
      .schema(AppConfig.isolatedApiSchema)
      .rpc<Map<String, dynamic>>(
        'list_request_germination_form_runs',
        params: {'p_request_id': requestId},
      );
}

class GerminationRequestForms extends StatefulWidget {
  const GerminationRequestForms({
    super.key,
    required this.requestId,
    required this.runCode,
    required this.status,
    this.loadRuns = listRequestGerminationForms,
    this.download = fetchRequestSeedlingForm,
    this.share = shareRoutineForm,
  });
  final String requestId, runCode, status;
  final Future<Map<String, dynamic>> Function(String) loadRuns;
  final Future<RequestSeedlingFile> Function(String, String, String) download;
  final Future<void> Function(Uint8List, String, String) share;
  @override
  State<GerminationRequestForms> createState() =>
      _GerminationRequestFormsState();
}

class _GerminationRequestFormsState extends State<GerminationRequestForms> {
  bool busy = false;
  String? error;
  List<Map<String, dynamic>>? runs;
  Future<void> load() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      runs = null;
    });
    try {
      final data = await widget.loadRuns(widget.requestId);
      if (data['request_id'] != widget.requestId ||
          data['read_only'] != true ||
          data['total'] != (data['runs'] as List).length) {
        throw const FormatException('Riwayat tidak sesuai.');
      }
      if (mounted) {
        setState(
          () => runs = (data['runs'] as List)
              .cast<Map<String, dynamic>>()
              .where((r) => r['run_code'] != widget.runCode)
              .toList(),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Riwayat belum dimuat. Periksa koneksi dan penugasan Lab, lalu coba lagi.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RequestSeedlingFormDownload(
        runCode: widget.runCode,
        status: widget.status,
        kind: 'Germinasi',
        load: widget.download,
        share: widget.share,
      ),
      ExpansionTile(
        title: const Text('Cetakan percobaan Germinasi lainnya'),
        children: [
          TextButton(
            onPressed: busy ? null : load,
            child: Text(busy ? 'Memuat…' : 'Muat riwayat percobaan'),
          ),
          if (error != null) Text(error!),
          if (runs?.isEmpty == true)
            const Text('Tidak ada percobaan lain dalam permintaan ini.'),
          for (final r in runs ?? <Map<String, dynamic>>[]) ...[
            Text('Percobaan ${r['attempt_no']} · ${r['status']}'),
            RequestSeedlingFormDownload(
              runCode: r['run_code'] as String,
              status: r['status'] as String,
              kind: 'Germinasi',
              load: widget.download,
              share: widget.share,
            ),
          ],
        ],
      ),
    ],
  );
}
