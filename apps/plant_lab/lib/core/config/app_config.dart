import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static const standalonePreview = bool.fromEnvironment(
    'PLANT_LAB_LOCAL_PREVIEW',
  );
  static const hostedPilot = bool.fromEnvironment('PLANT_LAB_HOSTED_PILOT');
  static const plantSampleRequestsEnabled =
      hostedPilot && bool.fromEnvironment('PLANT_LAB_SAMPLE_REQUESTS');
  static const isolatedPlantLab = standalonePreview || hostedPilot;
  static const isolatedApiSchema = hostedPilot
      ? 'plantlab_api'
      : 'plant_lab_api';
  static const hostedPilotUrl = 'https://bstxdyyglxrrfqgohllz.supabase.co';
  static const localPreviewUrl = 'http://127.0.0.1:54521';
  static const standaloneWritePreview =
      kDebugMode &&
      standalonePreview &&
      bool.fromEnvironment('PLANT_LAB_LOCAL_WRITE_PREVIEW');

  static const canonicalWritesEnabled =
      standaloneWritePreview ||
      (hostedPilot &&
          !standalonePreview &&
          bool.fromEnvironment('PLANT_LAB_HOSTED_WRITES_ENABLED'));

  /// P0 safety switch. Builds are read-only unless explicitly enabled after
  /// the canonical write APIs and production RLS have passed P0-B/UAT.
  static const operationalWritesEnabled =
      !isolatedPlantLab &&
      bool.fromEnvironment('OPERATIONAL_WRITES_ENABLED', defaultValue: false);

  static void requireOperationalWritesEnabled() {
    if (!operationalWritesEnabled) {
      throw StateError(
        'Mode read-only aktif. Operasi tulis Plant/Lab belum diaktifkan.',
      );
    }
  }

  static const _definedSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _explicitPublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const _definedSupabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  static String get supabaseUrl {
    if (isolatedPlantLab) return _definedSupabaseUrl;
    if (_definedSupabaseUrl.isNotEmpty) return _definedSupabaseUrl;
    return dotenv.env['SUPABASE_URL'] ??
        'https://bstxdyyglxrrfqgohllz.supabase.co';
  }

  static String get supabasePublishableKey {
    if (hostedPilot) return _explicitPublishableKey;
    if (standalonePreview) return _definedSupabasePublishableKey;
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
    preview: standalonePreview,
    hosted: hostedPilot,
  );

  static String? validateSupabaseConfiguration({
    required String url,
    required String publishableKey,
    bool preview = false,
    bool hosted = false,
  }) {
    if (hosted) {
      if (preview ||
          url != hostedPilotUrl ||
          !RegExp(
            r'^sb_publishable_[A-Za-z0-9_-]+$',
          ).hasMatch(publishableKey)) {
        return 'Pilot hosted memerlukan URL Advanta-CC dan publishable key.';
      }
      return null;
    }
    if (preview) {
      if (!kDebugMode ||
          url != localPreviewUrl ||
          publishableKey.trim().isEmpty) {
        return 'Preview Plant/Lab memerlukan build debug dan Supabase lokal '
            'di 127.0.0.1:54521.';
      }
      return null;
    }
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
