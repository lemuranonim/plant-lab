import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_notifier.dart';
import '../auth/auth_state.dart';
import 'access_context.dart';
import 'access_context_repository.dart';

final accessContextRepositoryProvider = Provider<AccessContextRepository>((
  ref,
) {
  return AccessContextRepository(Supabase.instance.client);
});

final accessContextProvider = FutureProvider.autoDispose<AccessContext?>((ref) {
  final authState = ref.watch(authNotifierProvider).valueOrNull;
  final isAuthenticated =
      authState?.maybeWhen(authenticated: (_) => true, orElse: () => false) ??
      false;

  if (!isAuthenticated) return null;
  return ref.watch(accessContextRepositoryProvider).fetchCurrent();
});
