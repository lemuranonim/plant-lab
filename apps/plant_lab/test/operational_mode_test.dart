import 'package:flutter_test/flutter_test.dart';
import 'package:plant_lab/core/config/app_config.dart';

void main() {
  test('operational writes are disabled by default', () {
    expect(AppConfig.operationalWritesEnabled, isFalse);
    expect(
      AppConfig.requireOperationalWritesEnabled,
      throwsA(isA<StateError>()),
    );
  });

  test('Supabase configuration validation reports a missing key', () {
    expect(
      AppConfig.validateSupabaseConfiguration(
        url: 'https://example.supabase.co',
        publishableKey: '',
      ),
      contains('SUPABASE_PUBLISHABLE_KEY'),
    );
    expect(
      AppConfig.validateSupabaseConfiguration(
        url: 'https://example.supabase.co',
        publishableKey: 'sb_publishable_example',
      ),
      isNull,
    );
  });
}
