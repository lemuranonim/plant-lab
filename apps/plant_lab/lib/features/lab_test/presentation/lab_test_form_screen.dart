import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/config/app_config.dart';
import '../data/lab_repository.dart';

class LabTestFormScreen extends ConsumerStatefulWidget {
  const LabTestFormScreen({super.key});

  @override
  ConsumerState<LabTestFormScreen> createState() => _LabTestFormScreenState();
}

class _LabTestFormScreenState extends ConsumerState<LabTestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _lotIdController = TextEditingController();
  final _hybridController = TextEditingController();
  final _germPctController = TextEditingController();
  final _soakPctController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _lotIdController.dispose();
    _hybridController.dispose();
    _germPctController.dispose();
    _soakPctController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(labRepositoryProvider)
          .submitLabTest(
            lotIdRaw: _lotIdController.text,
            hybridCode: _hybridController.text,
            germNormalPct: double.parse(_germPctController.text),
            soakNormalPct: double.parse(_soakPctController.text),
          );

      // ignore: unused_result
      ref.refresh(recentLabTestsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lab evaluation submitted successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Lab Evaluation')),
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
                validator: (v) =>
                    v == null || v.isEmpty ? 'Required field' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _hybridController,
                decoration: const InputDecoration(
                  labelText: 'Hybrid Code',
                  hintText: 'e.g. AX09',
                  prefixIcon: Icon(Icons.eco),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Required field' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _germPctController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Germination Normal (%)',
                  hintText: 'e.g. 95',
                  prefixIcon: Icon(Icons.percent),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Required field';
                  }
                  if (double.tryParse(v) == null) {
                    return 'Must be a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _soakPctController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Vigor Soak Normal (%)',
                  hintText: 'e.g. 92',
                  prefixIcon: Icon(Icons.percent),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Required field';
                  }
                  if (double.tryParse(v) == null) {
                    return 'Must be a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: AppConfig.operationalWritesEnabled && !_isLoading
                    ? _submit
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        AppConfig.operationalWritesEnabled
                            ? 'Submit Evaluation'
                            : 'Read-only mode',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
