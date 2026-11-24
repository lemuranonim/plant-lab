import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/database/supabase_client.dart';

enum SampleHandoffAction {
  prepare('Siapkan sampel', 'prepare_lab_sample'),
  send('Tandai dikirim', 'send_lab_sample'),
  receive('Terima sampel fisik', 'receive_lab_sample');

  const SampleHandoffAction(this.label, this.rpc);
  final String label;
  final String rpc;
}

class StandaloneHandoffDialog extends StatefulWidget {
  const StandaloneHandoffDialog({
    super.key,
    required this.requestId,
    required this.action,
    this.sampleCode,
  });

  final String requestId;
  final SampleHandoffAction action;
  final String? sampleCode;

  @override
  State<StandaloneHandoffDialog> createState() =>
      _StandaloneHandoffDialogState();
}

class _StandaloneHandoffDialogState extends State<StandaloneHandoffDialog> {
  final _weight = TextEditingController();
  final _condition = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _weight.dispose();
    _condition.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!AppConfig.canonicalWritesEnabled || _busy) return;
    final weight = double.tryParse(_weight.text.trim().replaceAll(',', '.'));
    final condition = _condition.text.trim();
    final code = _code.text.trim();
    final action = widget.action;
    if (action != SampleHandoffAction.send &&
        (weight == null ||
            !weight.isFinite ||
            weight <= 0 ||
            condition.isEmpty)) {
      setState(() => _error = 'Isi berat positif dan kondisi sampel.');
      return;
    }
    if (action == SampleHandoffAction.receive &&
        code.toUpperCase() != widget.sampleCode) {
      setState(() => _error = 'Kode tidak cocok dengan label sampel.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await supabase
          .schema(AppConfig.isolatedApiSchema)
          .rpc(
            action.rpc,
            params: {
              'p_request_id': widget.requestId,
              if (action == SampleHandoffAction.prepare)
                'p_quantity_grams': weight,
              if (action == SampleHandoffAction.receive) ...{
                'p_received_grams': weight,
                'p_sample_code': code,
              },
              if (action != SampleHandoffAction.send) 'p_condition': condition,
            },
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Gagal menyimpan. Periksa kode, status, dan akses.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(action.label),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (action == SampleHandoffAction.send)
                const Text(
                  'Konfirmasi bahwa sampel sudah diserahkan untuk dikirim.',
                ),
              if (action == SampleHandoffAction.receive) ...[
                const Text('Gunakan hanya untuk sampel yang layak diterima.'),
                TextField(
                  controller: _code,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Kode pada label sampel',
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
              ],
              if (action != SampleHandoffAction.send) ...[
                TextField(
                  controller: _weight,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Berat sampel (g)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                TextField(
                  controller: _condition,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Kondisi sampel',
                  ),
                  maxLength: 500,
                ),
              ],
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Menyimpan…' : action.label),
          ),
        ],
      ),
    );
  }
}
