import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/database/supabase_client.dart';
import 'routine_form_download.dart';

const requestSeedlingStatuses = [
  'IN_PROGRESS',
  'SUBMITTED',
  'IN_REVIEW',
  'APPROVED',
  'RETEST',
  'REJECTED',
  'CANCELLED',
];

class RequestSeedlingFile {
  const RequestSeedlingFile(this.bytes, this.name);
  final Uint8List bytes;
  final String name;
}

Uri requestSeedlingUri(String code, String status, String format) {
  if (!RegExp(r'^LT-[A-Z0-9]{1,60}$').hasMatch(code) ||
      !requestSeedlingStatuses.contains(status) ||
      !['pdf', 'xlsx'].contains(format)) {
    throw const FormatException('Pilihan form pengujian tidak benar.');
  }
  return Uri.https(
    'lab.advantaindonesia.com',
    '/api/lab-request-form/$code/export',
    {'format': format, 'status': status},
  );
}

Future<RequestSeedlingFile> fetchRequestSeedlingForm(
  String code,
  String status,
  String format,
) async {
  if (!AppConfig.hostedPilot) {
    throw StateError('Unduhan hanya tersedia pada Lab online.');
  }
  final uri = requestSeedlingUri(code, status, format),
      token = supabase.auth.currentSession?.accessToken;
  if (token == null) {
    throw StateError('Sesi berakhir. Silakan login kembali.');
  }
  final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 45),
          followRedirects: false,
        ),
      ),
      cancel = CancelToken();
  try {
    final response = await dio.getUri<List<int>>(
      uri,
      cancelToken: cancel,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Authorization': 'Bearer $token'},
        validateStatus: (s) => s != null && s < 600,
      ),
      onReceiveProgress: (n, _) {
        if (n > 5 * 1024 * 1024) {
          cancel.cancel('File terlalu besar.');
        }
      },
    );
    if (response.statusCode != 200) {
      throw StateError(
        response.statusCode == 409
            ? 'Status pengujian berubah. Muat ulang sebelum mengunduh.'
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
    final name = RegExp(
      r'filename="(Form-(?:Germinasi|Vigor)-Request-[0-9a-fA-F-]{36}-(?:IN_PROGRESS|SUBMITTED|IN_REVIEW|APPROVED|RETEST|REJECTED|CANCELLED|APPROVAL_INCOMPLETE)\.(?:pdf|xlsx))"',
    ).firstMatch(response.headers.value('content-disposition') ?? '')?.group(1);
    if (name == null || !name.endsWith('.$format')) {
      throw const FormatException('Nama file pengujian tidak sesuai.');
    }
    return RequestSeedlingFile(bytes, name);
  } finally {
    dio.close(force: true);
  }
}

class RequestSeedlingFormDownload extends StatefulWidget {
  const RequestSeedlingFormDownload({
    super.key,
    required this.runCode,
    required this.status,
    required this.kind,
    this.load = fetchRequestSeedlingForm,
    this.share = shareRoutineForm,
  });
  final String runCode, status, kind;
  final Future<RequestSeedlingFile> Function(String, String, String) load;
  final Future<void> Function(Uint8List, String, String) share;
  @override
  State<RequestSeedlingFormDownload> createState() =>
      _RequestSeedlingFormDownloadState();
}

class _RequestSeedlingFormDownloadState
    extends State<RequestSeedlingFormDownload> {
  bool busy = false;
  String? error;
  Future<void> download(String format) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final file = await widget.load(widget.runCode, widget.status, format);
      if (!file.name.startsWith('Form-${widget.kind}-Request-')) {
        throw const FormatException('Jenis file tidak sesuai pengujian.');
      }
      if (mounted) {
        await widget.share(file.bytes, file.name, format);
      }
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
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Form ${widget.kind} permintaan Plant · ${widget.runCode}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const Text(
          'Satu file per percobaan sesuai hitungan sumber. Kolom yang belum dicatat tetap kosong; bukan pelepasan lot.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final format in ['pdf', 'xlsx'])
              OutlinedButton(
                onPressed: busy ? null : () => download(format),
                child: Text(
                  format == 'pdf'
                      ? 'Unduh ${widget.kind} PDF'
                      : 'Unduh ${widget.kind} Excel',
                ),
              ),
          ],
        ),
        if (busy) const Text('Menyiapkan form pengujian…'),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
  );
}
