import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';
import '../../../core/database/supabase_client.dart';
import 'routine_form_download.dart';

class LogbookExportFile {
  const LogbookExportFile(this.bytes, this.name);
  final Uint8List bytes;
  final String name;
}

typedef LogbookExporter =
    Future<LogbookExportFile> Function(Map<String, dynamic> filters);
typedef LogbookSharer = Future<void> Function(LogbookExportFile file);
Uri logbookExportUri(Map<String, dynamic> filters) {
  const names = {
    'p_lab_site_id': 'site',
    'p_search': 'search',
    'p_from': 'from',
    'p_to': 'to',
    'p_date_basis': 'date_basis',
    'p_origin': 'origin',
    'p_method': 'method',
    'p_status': 'status',
  };
  if (filters.keys.any((k) => !names.containsKey(k))) {
    throw const FormatException('Filter unduhan tidak benar.');
  }
  final query = <String, String>{
    for (final e in filters.entries)
      if (e.value != null && e.value.toString().isNotEmpty)
        names[e.key]!: e.value.toString(),
  };
  final site = query['site'],
      search = query['search'] ?? '',
      basis = query['date_basis'] ?? 'RECORDED',
      origin = query['origin'] ?? 'ALL',
      method = query['method'] ?? 'ALL',
      status = query['status'] ?? 'ALL';
  bool validDate(String? x) {
    if (x == null) return true;
    final d = DateTime.tryParse('${x}T00:00:00Z');
    return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(x) &&
        d != null &&
        d.toIso8601String().substring(0, 10) == x;
  }

  if ((site != null &&
          !RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
          ).hasMatch(site)) ||
      search.length > 120 ||
      !validDate(query['from']) ||
      !validDate(query['to']) ||
      (query['from'] != null &&
          query['to'] != null &&
          query['from']!.compareTo(query['to']!) > 0) ||
      !['RECORDED', 'OBSERVED'].contains(basis) ||
      !['ALL', 'PLANT', 'ROUTINE', 'MC'].contains(origin) ||
      !RegExp(r'^[A-Z][A-Z0-9_]{0,79}$').hasMatch(method) ||
      ![
        'ALL',
        'DRAFT',
        'WAITING_TEST',
        'ASSIGNED',
        'IN_PROGRESS',
        'SUBMITTED',
        'IN_REVIEW',
        'APPROVED',
        'RETEST',
        'REJECTED',
        'CANCELLED',
        'APPROVAL_INCOMPLETE',
        'VERIFIED_RECORD',
        'RETURNED',
      ].contains(status)) {
    throw const FormatException('Filter unduhan tidak benar.');
  }
  return Uri.https(
    'lab.advantaindonesia.com',
    '/api/lab-logbook/export',
    query,
  );
}

Future<void> shareLogbookExport(LogbookExportFile file) =>
    shareRoutineForm(file.bytes, file.name, 'xlsx');
Future<LogbookExportFile> fetchLogbookExport(
  Map<String, dynamic> filters,
) async {
  if (!AppConfig.hostedPilot) {
    throw StateError('Unduhan hanya tersedia pada Lab online.');
  }
  final uri = logbookExportUri(filters),
      token = supabase.auth.currentSession?.accessToken;
  if (token == null) throw StateError('Sesi berakhir. Silakan login kembali.');
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
        if (n > 5 * 1024 * 1024) cancel.cancel('File terlalu besar.');
      },
    );
    if (response.statusCode != 200) {
      throw StateError(
        response.statusCode == 422
            ? 'Rekap belum bisa dibuat. Persempit tanggal/filter hingga maksimal 2000 catatan lalu tampilkan ulang.'
            : response.statusCode == 401
            ? 'Sesi berakhir. Silakan login kembali.'
            : response.statusCode == 409
            ? 'Catatan berubah. Muat ulang sebelum mengunduh.'
            : 'Unduhan belum berhasil. Periksa akses dan koneksi.',
      );
    }
    final bytes = Uint8List.fromList(response.data ?? []);
    validateRoutineFormBytes(
      bytes,
      'xlsx',
      response.headers.value('content-type'),
    );
    final name = RegExp(
      r'filename="(Rekap-Lab-\d{8}T\d{6}Z\.xlsx)"',
    ).firstMatch(response.headers.value('content-disposition') ?? '')?.group(1);
    if (name == null) {
      throw const FormatException('Nama file unduhan tidak sesuai.');
    }
    return LogbookExportFile(bytes, name);
  } finally {
    dio.close(force: true);
  }
}
