import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/supabase_client.dart';

final inspectionRepositoryProvider = Provider((ref) => InspectionRepository());

final formTemplatesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(inspectionRepositoryProvider).fetchFormTemplates();
});

final recentInspectionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(inspectionRepositoryProvider).fetchInspections();
});

class InspectionRepository {
  Future<List<Map<String, dynamic>>> fetchFormTemplates() async {
    final response = await supabase
        .from('pl_form_templates')
        .select()
        .eq('is_active', true)
        .order('id', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> fetchFormTemplateByProcess(String processType) async {
    final response = await supabase
        .from('pl_form_templates')
        .select()
        .eq('process_type', processType.toUpperCase())
        .eq('is_active', true)
        .maybeSingle();
    return response;
  }

  Future<List<Map<String, dynamic>>> fetchInspections() async {
    final response = await supabase
        .from('pl_inspections')
        .select('*')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> submitInspection({
    required String processType,
    required Map<String, dynamic> formData,
    required bool isOos,
    String? lotIdRaw,
    String? remarks,
  }) async {
    final user = supabase.auth.currentUser;
    final now = DateTime.now().toIso8601String();
    final insNo = 'INS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    await supabase.from('pl_inspections').insert({
      'inspection_no': insNo,
      'process_type': processType.toUpperCase(),
      'form_data': formData,
      'is_oos': isOos,
      'inspector_id': user?.id,
      'notes': remarks ?? formData['remarks']?.toString(),
      'submitted_at': now,
      'created_at': now,
    });
  }
}
