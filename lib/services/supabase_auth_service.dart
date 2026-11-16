import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthService {
  static SupabaseClient get _client => Supabase.instance.client;

  static User? get currentUser => _client.auth.currentUser;

  /// Auto-create akun di DB jika belum ada, atau langsung login jika sudah terdaftar
  static Future<User> signInOrRegisterWithEmail({
    required String identifier,
    required String password,
  }) async {
    final cleanInput = identifier.trim();
    final email = cleanInput.contains('@')
        ? cleanInput.toLowerCase()
        : '${cleanInput.toLowerCase().replaceAll(' ', '_')}@singotune.app';

    final existing = await _client
        .from('users')
        .select('id')
        .eq('email', email)
        .maybeSingle();

    AuthResponse res;
    if (existing != null) {
      res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } else {
      try {
        res = await _client.auth.signUp(
          email: email,
          password: password,
          data: {'username': cleanInput.split('@').first},
        );
      } on AuthException catch (e) {
        if (e.message.toLowerCase().contains('already registered')) {
          res = await _client.auth.signInWithPassword(
            email: email,
            password: password,
          );
        } else {
          rethrow;
        }
      }
    }

    final user = res.user;
    if (user == null) {
      throw Exception('Gagal memproses akun. Periksa kembali email atau password.');
    }

    await _client.from('users').upsert(
      {
        'id': user.id,
        'email': user.email ?? email,
        'username': cleanInput.split('@').first,
        'provider': 'email',
        'last_login': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'id',
    );

    return user;
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
