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

    final authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        state = AsyncValue.data(AuthState.authenticated(session.user));
      } else {
        state = const AsyncValue.data(AuthState.unauthenticated());
      }
    });
    ref.onDispose(authSubscription.cancel);

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
      final response = await _repository.signIn(email, password);
      final user = response.user;
      if (user == null) {
        state = const AsyncValue.data(
          AuthState.error('Login gagal. Silakan coba kembali.'),
        );
        return;
      }
      state = AsyncValue.data(AuthState.authenticated(user));
    } on AuthException catch (error) {
      state = AsyncValue.data(AuthState.error(_authErrorMessage(error)));
    } catch (_) {
      state = const AsyncValue.data(
        AuthState.error(
          'Tidak dapat terhubung ke server. Periksa koneksi lalu coba kembali.',
        ),
      );
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

  String _authErrorMessage(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Email atau password tidak sesuai.';
    }
    if (message.contains('email not confirmed')) {
      return 'Email belum dikonfirmasi oleh administrator.';
    }
    if (message.contains('rate limit') || message.contains('too many')) {
      return 'Terlalu banyak percobaan login. Tunggu sebentar lalu coba lagi.';
    }
    return 'Login gagal: ${error.message}';
  }
}
