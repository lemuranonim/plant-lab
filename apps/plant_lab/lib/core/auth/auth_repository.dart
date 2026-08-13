import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/supabase_client.dart';

class AuthRepository {
  Future<AuthResponse> signIn(String email, String password) async {
    return await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  Session? getSession() {
    return supabase.auth.currentSession;
  }

  User? getCurrentUser() {
    return supabase.auth.currentUser;
  }
}
