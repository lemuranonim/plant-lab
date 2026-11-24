import 'package:flutter/material.dart';
import '../../lab_request/presentation/routine_form_download.dart';

class PiTswFormDownload extends StatelessWidget {
  const PiTswFormDownload({
    super.key,
    required this.record,
    required this.isPlant,
  });
  final Map<String, dynamic> record;
  final bool isPlant;
  @override
  Widget build(BuildContext context) => RoutineFormDownload(
    record: {'id': record['id'], 'revision': record['row_version']},
    formName: 'TSW-PI',
    versionPrefix: 'v',
    title: 'Unduh form TSW sumber PI',
    description:
        'Satu catatan, versi tersimpan ${record['row_version']}. Simpan perubahan sebelum diunduh. Status sumber PI ikut tercetak; bukan approval Lab atau pelepasan lot.',
    load: (id, version, format) =>
        fetchLabForm(id, version, format, module: 'pi-quality', plant: isPlant),
  );
}
