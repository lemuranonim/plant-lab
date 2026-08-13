import 'package:supabase_flutter/supabase_flutter.dart';

extension SupabaseExtensions on SupabaseClient {
  Future<List<T>> rpcList<T>(
    String fn, {
    Map<String, dynamic>? params,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final response = await rpc(fn, params: params);
    if (response == null) return [];
    return (response as List).map((e) => fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<T?> rpcSingle<T>(
    String fn, {
    Map<String, dynamic>? params,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final response = await rpc(fn, params: params);
    if (response == null) return null;
    return fromJson(response as Map<String, dynamic>);
  }

  SupabaseQueryBuilder fromTable(String table) => from(table);
}
