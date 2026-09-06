import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/app_config.dart';
import '../../core/config/app_variant.dart';
import '../../plant_lab_app.dart';

Future<void> bootstrap(AppVariant variant) async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Compile-time dart-defines remain supported for CI or environments that
    // intentionally do not package a local .env file.
  }

  final configurationError = AppConfig.configurationError;
  if (configurationError != null) {
    runApp(
      _ConfigurationErrorApp(variant: variant, message: configurationError),
    );
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
  );

  runApp(
    ProviderScope(
      overrides: [appVariantProvider.overrideWithValue(variant)],
      child: const PlantLabApp(),
    ),
  );
}

class _ConfigurationErrorApp extends StatelessWidget {
  const _ConfigurationErrorApp({required this.variant, required this.message});

  final AppVariant variant;
  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: variant.appName,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 64),
                    const SizedBox(height: 20),
                    Text(
                      'Konfigurasi ${variant.appName} belum lengkap',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Text(
                      'Jalankan kembali flavor ${variant.name} menggunakan '
                      'tool\\flutter_with_local_config.ps1 atau berikan '
                      '--dart-define yang sesuai.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
