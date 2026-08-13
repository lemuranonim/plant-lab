import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../data/receiving_repository.dart';

class ReceivingFormScreen extends ConsumerStatefulWidget {
  const ReceivingFormScreen({super.key});

  @override
  ConsumerState<ReceivingFormScreen> createState() => _ReceivingFormScreenState();
}

class _ReceivingFormScreenState extends ConsumerState<ReceivingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _lotIdController = TextEditingController();
  final _hybridController = TextEditingController();
  final _qtyController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _lotIdController.dispose();
    _hybridController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(receivingRepositoryProvider).submitHarvest(
            lotIdRaw: _lotIdController.text,
            hybridCode: _hybridController.text,
            shellingQtyKg: double.parse(_qtyController.text),
          );
      
      // ignore: unused_result
      ref.refresh(recentHarvestsProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Harvest intake submitted successfully!'), backgroundColor: AppColors.success),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Receiving Harvest'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _lotIdController,
                decoration: const InputDecoration(
                  labelText: 'Lot ID (Raw)',
                  hintText: 'e.g. L-26-001',
                  prefixIcon: Icon(Icons.qr_code),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required field' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _hybridController,
                decoration: const InputDecoration(
                  labelText: 'Hybrid Code',
                  hintText: 'e.g. AX09',
                  prefixIcon: Icon(Icons.eco),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required field' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _qtyController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Shelling Quantity (kg)',
                  hintText: 'e.g. 5000',
                  prefixIcon: Icon(Icons.scale),
                  suffixText: 'kg',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required field';
                  if (double.tryParse(v) == null) return 'Must be a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Submit Intake', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
