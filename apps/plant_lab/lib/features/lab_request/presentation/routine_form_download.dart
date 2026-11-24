import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/config/app_config.dart';
import '../../../core/database/supabase_client.dart';

const routineFormHost = 'https://lab.advantaindonesia.com';
Uri routineFormUri(
  String id,
  int revision,
  String format, {
  String module = 'lab-routine',
  bool plant = false,
}) {
  if (!RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(id) ||
      revision < 1 ||
      revision > 999999999 ||
      !['pdf', 'xlsx'].contains(format) ||
      ![
        'lab-routine',
        'lab-moisture',
        'pi-quality',
        'lab-ret',
      ].contains(module) ||
      plant && module != 'pi-quality') {
    throw const FormatException('Pilihan form tidak benar.');
  }
  return Uri.parse(
    '${plant ? 'https://plant.advantaindonesia.com' : routineFormHost}/api/$module/$id/export',
  ).replace(queryParameters: {'format': format, 'revision': '$revision'});
}

void validateRoutineFormBytes(Uint8List bytes, String format, String? type) {
  final mime = format == 'pdf'
      ? 'application/pdf'
      : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  if (bytes.length < 5 ||
      bytes.length > 5 * 1024 * 1024 ||
      type?.split(';').first != mime ||
      (format == 'pdf'
          ? String.fromCharCodes(bytes.take(5)) != '%PDF-'
          : bytes[0] != 0x50 || bytes[1] != 0x4b)) {
    throw const FormatException(
      'File unduhan tidak sesuai. Muat ulang lalu coba kembali.',
    );
  }
}

Future<Uint8List> fetchRoutineForm(String id, int revision, String format) =>
    fetchLabForm(id, revision, format);
Future<Uint8List> fetchMcForm(String id, int revision, String format) =>
    fetchLabForm(id, revision, format, module: 'lab-moisture');
Future<Uint8List> fetchRetForm(String id, int revision, String format) =>
    fetchLabForm(id, revision, format, module: 'lab-ret');
Future<Uint8List> fetchLabForm(
  String id,
  int revision,
  String format, {
  String module = 'lab-routine',
  bool plant = false,
}) async {
  if (!AppConfig.hostedPilot) {
    throw StateError('Unduhan hanya tersedia pada Plant/Lab online.');
  }
  // Never put the session in URLs, follow redirects, or send it to another host.
  final token = supabase.auth.currentSession?.accessToken;
  if (token == null) throw StateError('Sesi berakhir. Silakan login kembali.');
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 45),
      followRedirects: false,
    ),
  );
  final cancel = CancelToken();
  try {
    final response = await dio.getUri<List<int>>(
      routineFormUri(id, revision, format, module: module, plant: plant),
      cancelToken: cancel,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Authorization': 'Bearer $token'},
        validateStatus: (s) => s != null && s < 600,
      ),
      onReceiveProgress: (count, _) {
        if (count > 5 * 1024 * 1024) {
          cancel.cancel('File terlalu besar.');
        }
      },
    );
    if (response.statusCode != 200) {
      throw StateError(
        response.statusCode == 409
            ? 'Revisi berubah. Muat ulang sebelum mengunduh.'
            : response.statusCode == 401
            ? 'Sesi berakhir. Silakan login kembali.'
            : 'Unduhan belum berhasil. Periksa akses dan koneksi.',
      );
    }
    final bytes = Uint8List.fromList(response.data ?? []);
    validateRoutineFormBytes(
      bytes,
      format,
      response.headers.value('content-type'),
    );
    return bytes;
  } finally {
    dio.close(force: true);
  }
}

Future<void> shareRoutineForm(
  Uint8List bytes,
  String name,
  String format,
) async {
  await Share.shareXFiles(
    [
      XFile.fromData(
        bytes,
        mimeType: format == 'pdf'
            ? 'application/pdf'
            : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        name: name,
      ),
    ],
    fileNameOverrides: [name],
  );
}

class RoutineFormDownload extends StatefulWidget {
  const RoutineFormDownload({
    super.key,
    required this.record,
    this.load = fetchRoutineForm,
    this.share = shareRoutineForm,
    this.formName,
    this.versionPrefix = 'r',
    this.title = 'Unduh form pengujian',
    this.description =
        'PDF atau Excel per form, memakai revisi tersimpan. Pilih tujuan penyimpanan setelah file siap. Status QA ikut tercetak.',
  });
  final Map<String, dynamic> record;
  final String? formName;
  final String versionPrefix, title, description;
  final Future<Uint8List> Function(String, int, String) load;
  final Future<void> Function(Uint8List, String, String) share;
  @override
  State<RoutineFormDownload> createState() => _RoutineFormDownloadState();
}

class _RoutineFormDownloadState extends State<RoutineFormDownload> {
  bool busy = false;
  String? error;
  Future<void> download(String format) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final id = widget.record['id'] as String,
          revision = widget.record['revision'] as int;
      final bytes = await widget.load(id, revision, format);
      final name =
          'Form-${widget.formName ?? (widget.record['method_code'] == 'SAND_25C' ? 'Germinasi' : 'Vigor')}-$id-${widget.versionPrefix}$revision.$format';
      if (mounted) await widget.share(bytes, name, format);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is StateError
              ? e.message.toString()
              : e is FormatException
              ? e.message
              : 'Unduhan belum berhasil. Periksa koneksi lalu coba kembali.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(widget.description),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: busy ? null : () => download('pdf'),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Unduh form PDF'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : () => download('xlsx'),
                icon: const Icon(Icons.table_chart_outlined),
                label: const Text('Unduh form Excel'),
              ),
            ],
          ),
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
  );
}
