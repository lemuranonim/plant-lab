import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  /// P0 safety switch. Builds are read-only unless explicitly enabled after
  /// the canonical write APIs and production RLS have passed P0-B/UAT.
  static const operationalWritesEnabled = bool.fromEnvironment(
    'OPERATIONAL_WRITES_ENABLED',
    defaultValue: false,
  );

  static void requireOperationalWritesEnabled() {
    if (!operationalWritesEnabled) {
      throw StateError(
        'Mode read-only aktif. Operasi tulis Plant/Lab belum diaktifkan.',
      );
    }
  }

  static const _definedSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _definedSupabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  static String get supabaseUrl {
    if (_definedSupabaseUrl.isNotEmpty) return _definedSupabaseUrl;
    return dotenv.env['SUPABASE_URL'] ??
        'https://bstxdyyglxrrfqgohllz.supabase.co';
  }

  static String get supabasePublishableKey {
    if (_definedSupabasePublishableKey.isNotEmpty) {
      return _definedSupabasePublishableKey;
    }
    return dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ??
        dotenv.env['SUPABASE_ANON_KEY'] ??
        '';
  }

  static String? get configurationError => validateSupabaseConfiguration(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );

  static String? validateSupabaseConfiguration({
    required String url,
    required String publishableKey,
  }) {
    final parsedUrl = Uri.tryParse(url);
    if (parsedUrl == null ||
        parsedUrl.scheme != 'https' ||
        parsedUrl.host.isEmpty) {
      return 'SUPABASE_URL harus berupa URL HTTPS Supabase yang valid.';
    }
    if (publishableKey.trim().isEmpty) {
      return 'SUPABASE_PUBLISHABLE_KEY belum diberikan saat aplikasi '
          'dijalankan atau dibangun.';
    }
    return null;
  }
}
