import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/access/access_context_provider.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../../core/config/app_variant.dart';

class AccessDeniedScreen extends ConsumerWidget {
  const AccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(accessContextProvider).valueOrNull;
    final variant = ref.watch(appVariantProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Akses dibatasi')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.gpp_bad_outlined, size: 64),
                  const SizedBox(height: 20),
                  Text(
                    'Akun tidak memiliki akses ${variant.appName}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    access == null
                        ? 'Aplikasi tidak menemukan assignment modul dan site yang aktif untuk akun ini.'
                        : '${access.primaryRoleName} memiliki scope ${access.siteSummary}, tetapi bukan untuk aplikasi ${variant.moduleName}.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (access != null && variant.allows(access))
                    FilledButton.icon(
                      onPressed: () => context.go('/app/dashboard'),
                      icon: const Icon(Icons.dashboard_outlined),
                      label: const Text('Kembali ke dashboard'),
                    ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () =>
                        ref.read(authNotifierProvider.notifier).signOut(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Keluar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
