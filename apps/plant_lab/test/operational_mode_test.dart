import 'package:flutter_test/flutter_test.dart';
import 'package:plant_lab/core/config/app_config.dart';

void main() {
  test(
    'canonical hosted writes are opt-in and cannot enable legacy writes',
    () {
      const requested = bool.fromEnvironment('PLANT_LAB_HOSTED_WRITES_ENABLED');
      if (AppConfig.hostedPilot) {
        expect(AppConfig.isolatedApiSchema, 'plantlab_api');
        expect(AppConfig.operationalWritesEnabled, isFalse);
        expect(AppConfig.canonicalWritesEnabled, requested);
      } else if (!AppConfig.standalonePreview) {
        expect(AppConfig.canonicalWritesEnabled, isFalse);
      }
    },
  );
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

  test('only explicit preview can connect to the local API over HTTP', () {
    const key = 'local_test_key';
    expect(
      AppConfig.validateSupabaseConfiguration(
        url: AppConfig.localPreviewUrl,
        publishableKey: key,
      ),
      isNotNull,
    );
    expect(
      AppConfig.validateSupabaseConfiguration(
        url: AppConfig.localPreviewUrl,
        publishableKey: key,
        preview: true,
      ),
      isNull,
    );
    for (final url in [
      'https://example.supabase.co',
      'http://127.0.0.1:54522',
      'http://127.0.0.1:54521/path',
    ]) {
      expect(
        AppConfig.validateSupabaseConfiguration(
          url: url,
          publishableKey: key,
          preview: true,
        ),
        isNotNull,
      );
    }
  });

  test('hosted pilot requires the exact project and a publishable key', () {
    String? validate(String url, String key, {bool preview = false}) =>
        AppConfig.validateSupabaseConfiguration(
          url: url,
          publishableKey: key,
          hosted: true,
          preview: preview,
        );
    const key = 'sb_publishable_example';
    expect(validate(AppConfig.hostedPilotUrl, key), isNull);
    expect(validate(AppConfig.hostedPilotUrl, key, preview: true), isNotNull);
    expect(validate(AppConfig.localPreviewUrl, key), isNotNull);
    expect(validate('https://another.supabase.co', key), isNotNull);
    expect(validate(AppConfig.hostedPilotUrl, 'sb_secret_example'), isNotNull);
    expect(validate(AppConfig.hostedPilotUrl, ''), isNotNull);
  });
}
