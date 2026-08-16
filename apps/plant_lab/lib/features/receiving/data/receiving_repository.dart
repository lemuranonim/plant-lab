import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:plant_lab/core/config/app_config.dart';

part 'receiving_repository.g.dart';

class ReceivingRepository {
  final SupabaseClient _supabase;

  ReceivingRepository(this._supabase);

  Future<List<Map<String, dynamic>>> getRecentHarvests() async {
    final response = await _supabase
        .from('pl_receiving_harvest')
        .select()
        .order('incoming_date', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> submitHarvest({
    required String lotIdRaw,
    required String hybridCode,
    required double shellingQtyKg,
  }) async {
    AppConfig.requireOperationalWritesEnabled();
    final now = DateTime.now().toIso8601String();
    await _supabase.from('pl_receiving_harvest').insert({
      'lot_id_raw': lotIdRaw,
      'hybrid_code': hybridCode,
      'shelling_qty_kg': shellingQtyKg,
      'incoming_date': now,
      'season_year': DateTime.now().year.toString(),
      'corn_type': 'DSS', // Default for now, can be expanded
      'field_status': 'RECEIVED',
    });
  }
}

@riverpod
ReceivingRepository receivingRepository(Ref ref) {
  return ReceivingRepository(Supabase.instance.client);
}

@riverpod
Future<List<Map<String, dynamic>>> recentHarvests(Ref ref) {
  return ref.watch(receivingRepositoryProvider).getRecentHarvests();
}
