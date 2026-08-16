// Reads from --dart-define at build time
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

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://bstxdyyglxrrfqgohllz.supabase.co',
  );
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
}
