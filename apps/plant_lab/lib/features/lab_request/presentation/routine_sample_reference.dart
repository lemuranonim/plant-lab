import 'package:flutter/material.dart';

typedef RoutineReferenceLoader =
    Future<Map<String, dynamic>> Function(String search, int offset);

class RoutineSampleReferenceField extends StatefulWidget {
  const RoutineSampleReferenceField({
    super.key,
    required this.controller,
    required this.enabled,
    required this.locked,
    required this.loadReferences,
  });
  final TextEditingController controller;
  final bool enabled;
  final bool locked;
  final RoutineReferenceLoader loadReferences;
  @override
  State<RoutineSampleReferenceField> createState() =>
      _RoutineSampleReferenceFieldState();
}

class _RoutineSampleReferenceFieldState
    extends State<RoutineSampleReferenceField> {
  late bool manual = widget.controller.text.isNotEmpty;
  final focus = FocusNode();
  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  Future<void> choose() async {
    final reference = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _ReferencePicker(load: widget.loadReferences),
      ),
    );
    if (!mounted || reference == null || !widget.enabled || widget.locked) {
      return;
    }
    setState(() {
      // Empty return selects manual mode without changing the existing value.
      manual = reference.isEmpty;
      if (reference.isNotEmpty) widget.controller.text = reference;
    });
    if (manual) focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextFormField(
        key: const ValueKey('routine-sample-reference'),
        controller: widget.controller,
        focusNode: focus,
        enabled: widget.enabled,
        readOnly: widget.locked || !manual,
        maxLength: 120,
        decoration: const InputDecoration(
          labelText: 'Referensi / label sampel',
          hintText: 'Pilih dari daftar atau tekan Isi manual',
        ),
      ),
      if (widget.enabled && !widget.locked)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: choose,
              child: const Text('Pilih label tercatat'),
            ),
            TextButton(
              onPressed: () {
                setState(() => manual = true);
                focus.requestFocus();
              },
              child: const Text('Isi manual'),
            ),
          ],
        ),
      Text(
        widget.locked
            ? 'Label sumber terkunci.'
            : 'Cocokkan dengan label fisik.',
      ),
    ],
  );
}

class _ReferencePicker extends StatefulWidget {
  const _ReferencePicker({required this.load});
  final RoutineReferenceLoader load;
  @override
  State<_ReferencePicker> createState() => _ReferencePickerState();
}

class _ReferencePickerState extends State<_ReferencePicker> {
  final search = TextEditingController();
  Map<String, dynamic>? page;
  String applied = '';
  bool busy = false;
  String? error;
  int request = 0;
  @override
  void initState() {
    super.initState();
    load('', 0);
  }

  @override
  void dispose() {
    request++;
    search.dispose();
    super.dispose();
  }

  Future<void> load(String term, int offset) async {
    final version = ++request;
    setState(() {
      busy = true;
      error = null;
      page = null;
    });
    try {
      final result = await widget.load(term.trim(), offset);
      if (!mounted || version != request) return;
      setState(() {
        page = result;
        applied = term.trim();
      });
    } catch (_) {
      if (!mounted || version != request) return;
      setState(() {
        error =
            'Daftar belum bisa dimuat. Coba lagi atau isi label sebenarnya melalui Isi manual.';
      });
    } finally {
      if (mounted && version == request) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final references = (page?['references'] as List?) ?? [];
    final offset = (page?['offset'] as num?)?.toInt() ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Pilih label sampel')),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('routine-reference-list'),
          padding: const EdgeInsets.all(16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Hanya catatan untuk lot dan Lab ini. Cocokkan dengan label sampel fisik; label draft belum diverifikasi.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('routine-reference-search'),
                    controller: search,
                    maxLength: 120,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (value) => load(value, 0),
                    decoration: const InputDecoration(
                      labelText: 'Cari label sampel',
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(
                        onPressed: busy ? null : () => load(search.text, 0),
                        child: const Text('Cari sampel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, ''),
                        child: const Text('Tidak ada di daftar · isi manual'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (busy) const LinearProgressIndicator(),
            if (error != null) Text(error!),
            if (page != null)
              Text('${page!['total']} label cocok · maksimal 50 per halaman.'),
            if (page != null && references.isEmpty)
              const Text(
                'Label belum ditemukan. Periksa pencarian atau isi manual sesuai sampel sebenarnya.',
              ),
            for (final item in references)
              Card(
                child: ListTile(
                  title: Text(item['reference'] as String),
                  subtitle: Text(
                    [
                      item['source_kind'] == 'RECEIVED'
                          ? 'Sampel sudah diterima Lab'
                          : 'Label dari draft · belum diverifikasi',
                      if (item['sample_code'] != null &&
                          item['sample_code'] != item['reference'])
                        item['sample_code'] as String,
                    ].join(' · '),
                  ),
                  onTap: () =>
                      Navigator.pop(context, item['reference'] as String),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: busy || offset == 0
                        ? null
                        : () => load(applied, (offset - 50).clamp(0, offset)),
                    child: const Text('Sebelumnya'),
                  ),
                  OutlinedButton(
                    onPressed: busy || page?['has_more'] != true
                        ? null
                        : () => load(applied, offset + 50),
                    child: const Text('Berikutnya'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
