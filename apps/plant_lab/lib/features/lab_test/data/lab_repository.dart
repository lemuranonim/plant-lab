import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:plant_lab/core/config/app_config.dart';

part 'lab_repository.g.dart';

class LabRepository {
  final SupabaseClient _supabase;

  LabRepository(this._supabase);

  Future<List<Map<String, dynamic>>> getRecentLabTests() async {
    final response = await _supabase
        .from('pl_germ_results')
        .select()
        .order('germ_date', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> submitLabTest({
    required String lotIdRaw,
    required String hybridCode,
    required double germNormalPct,
    required double soakNormalPct,
  }) async {
    AppConfig.requireOperationalWritesEnabled();
    final now = DateTime.now().toIso8601String();

    // Business Logic: Automate Conclusion based on Blueprint threshold (>= 80% is Passed)
    String conclusion = 'YF'; // Marginal by default
    if (germNormalPct >= 80) {
      conclusion = 'ACCEPTED';
    } else if (germNormalPct < 70) {
      conclusion = 'REJECTED';
    }

    await _supabase.from('pl_germ_results').insert({
      'lot_id_raw': lotIdRaw,
      'hybrid_code': hybridCode,
      'germ_normal_pct': germNormalPct,
      'soak_normal_pct': soakNormalPct,
      'germ_date': now.split('T')[0],
      'test_category': 'GERM_VIGOR',
      'germ_conclusion': conclusion,
    });
  }
}

@riverpod
LabRepository labRepository(Ref ref) {
  return LabRepository(Supabase.instance.client);
}

@riverpod
Future<List<Map<String, dynamic>>> recentLabTests(Ref ref) {
  return ref.watch(labRepositoryProvider).getRecentLabTests();
}
