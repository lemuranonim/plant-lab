import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/supabase_client.dart';

final labRequestRepositoryProvider = Provider((ref) => LabRequestRepository());

final labRequestsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(labRequestRepositoryProvider).fetchLabRequests();
});

class LabRequestRepository {
  Future<List<Map<String, dynamic>>> fetchLabRequests() async {
    final response = await supabase
        .from('pl_lab_requests')
        .select()
        .order('requested_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> createLabRequest({
    required String lotIdRaw,
    required String testType,
    required double sampleQtyGrams,
    String? notes,
  }) async {
    final user = supabase.auth.currentUser;
    final now = DateTime.now();
    final reqNo = 'REQ-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(7)}';

    await supabase.from('pl_lab_requests').insert({
      'request_no': reqNo,
      'lot_id_raw': lotIdRaw.toUpperCase(),
      'test_type': testType,
      'sample_qty_grams': sampleQtyGrams,
      'sampler_name': user?.email?.split('@')[0] ?? 'Inspector',
      'sampler_email': user?.email ?? 'inspector@advantaseeds.com',
      'status': 'PREPARED',
      'notes': notes,
      'requested_at': now.toIso8601String(),
    });
  }

  Future<void> updateSampleStatus({
    required String requestId,
    required String newStatus,
  }) async {
    await supabase.from('pl_lab_requests').update({
      'status': newStatus,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);
  }
}
