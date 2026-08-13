import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'auth_state.dart';
import 'auth_repository.dart';
import '../database/supabase_client.dart';

part 'auth_notifier.g.dart';

@riverpod
class AuthNotifier extends _$AuthNotifier {
  late final AuthRepository _repository;
  @override
  FutureOr<AuthState> build() {
    _repository = AuthRepository();
    
    supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        state = AsyncValue.data(AuthState.authenticated(session.user));
      } else {
        state = const AsyncValue.data(AuthState.unauthenticated());
      }
    });

    final currentUser = _repository.getCurrentUser();
    if (currentUser != null) {
      return AuthState.authenticated(currentUser);
    }
    return const AuthState.unauthenticated();
  }

  User? get currentUser {
    return _repository.getCurrentUser();
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.data(AuthState.loading());
    try {
      await _repository.signIn(email, password);
    } catch (e) {
      state = AsyncValue.data(AuthState.error(e.toString()));
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.data(AuthState.loading());
    try {
      await _repository.signOut();
    } catch (e) {
      state = AsyncValue.data(AuthState.error(e.toString()));
    }
  }
}
