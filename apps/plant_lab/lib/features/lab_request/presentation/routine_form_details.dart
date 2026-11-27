import 'package:flutter/material.dart';
import 'lab_workspace_widgets.dart';

Map<String, dynamic> emptyRoutineForm(String method, int rows) => {
  'version': 1,
  'crop_species': null,
  'analyst_name': null,
  'temperature_text': method == 'SAND_25C' ? '25' : null,
  'planted_at': null,
  'first_count_at': null,
  'annotations': List.generate(
    rows,
    (_) => {'abnormal_kind': null, 'remarks': null},
  ),
};

class RoutineFormDetailsFields extends StatelessWidget {
  const RoutineFormDetailsFields({
    super.key,
    required this.value,
    required this.enabled,
    required this.germination,
    required this.onChanged,
  });
  final Map<String, dynamic> value;
  final bool enabled, germination;
  final ValueChanged<Map<String, dynamic>> onChanged;

  Future<void> pick(BuildContext context, String key) async {
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    final old = value[key] == null
        ? now
        : DateTime.parse(
            value[key] as String,
          ).toUtc().add(const Duration(hours: 7));
    final date = await showDatePicker(
      context: context,
      initialDate: old.isAfter(now) ? now : old,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: old.hour, minute: old.minute),
    );
    if (time == null || !context.mounted) return;
    final at = DateTime.utc(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    ).subtract(const Duration(hours: 7));
    onChanged({...value, key: at.toIso8601String()});
  }

  String dateText(dynamic value) => value == null
      ? 'Belum dicatat'
      : '${DateTime.parse(value as String).toUtc().add(const Duration(hours: 7)).toIso8601String().substring(0, 16).replaceFirst('T', ' ')} WIB';

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      title: Text('Rincian form ${germination ? 'Germinasi' : 'Vigor'}'),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const LabHelp(
                label: 'Cara isi waktu form',
                text:
                    'Tanggal tanam berbeda dari mulai perlakuan Vigor. DAP dihitung dari tanggal tanam dan pengamatan dalam WIB.',
              ),
              for (final entry in {
                'crop_species': 'Tanaman / spesies pada form',
                'analyst_name': 'Nama pelaksana / Seed Analyst',
                if (!germination) 'temperature_text': 'Suhu pada form (°C)',
              }.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: TextFormField(
                    key: ValueKey('routine-form-${entry.key}'),
                    initialValue: value[entry.key] as String?,
                    enabled: enabled,
                    maxLength: 120,
                    decoration: InputDecoration(labelText: entry.value),
                    onChanged: (text) => onChanged({
                      ...value,
                      entry.key: text.trim().isEmpty ? null : text,
                    }),
                  ),
                ),
              if (germination) const Text('Metode: Pasir 25 °C.'),
              for (final entry in {
                'planted_at': 'Tanggal dan jam tanam aktual',
                'first_count_at': 'Pengamatan first count aktual',
              }.entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${entry.value} (WIB)'),
                  subtitle: Text(dateText(value[entry.key])),
                  onTap: enabled ? () => pick(context, entry.key) : null,
                  trailing: enabled
                      ? IconButton(
                          tooltip: 'Kosongkan waktu form',
                          icon: const Icon(Icons.clear),
                          onPressed: () =>
                              onChanged({...value, entry.key: null}),
                        )
                      : null,
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
