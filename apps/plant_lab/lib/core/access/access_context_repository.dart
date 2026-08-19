import 'package:supabase_flutter/supabase_flutter.dart';

import 'access_context.dart';

class AccessContextRepository {
  const AccessContextRepository(this._supabase);

  final SupabaseClient _supabase;

  Future<AccessContext> fetchCurrent() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const AuthException('Authentication is required.');
    }

    final response = await _supabase.rpc('pl_get_current_access_context');
    final json = switch (response) {
      Map<String, dynamic> value => value,
      Map value => Map<String, dynamic>.from(value),
      _ => throw const FormatException(
        'Access-context RPC returned an unsupported response.',
      ),
    };
    final context = AccessContext.fromJson(json);

    if (context.userId != user.id) {
      throw const FormatException(
        'Access-context user does not match the authenticated session.',
      );
    }

    return context;
  }
}
