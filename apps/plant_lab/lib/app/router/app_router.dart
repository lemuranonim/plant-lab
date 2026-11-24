// ignore_for_file: deprecated_member_use_from_same_package
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/access/access_context_provider.dart';
import '../../core/access/route_access_policy.dart';
import '../../core/auth/auth_notifier.dart';
import '../../core/auth/auth_state.dart';
import '../../core/config/app_config.dart';
import '../../core/config/app_variant.dart';
import '../../core/widgets/qr_barcode_scanner_screen.dart';
import '../../features/access/presentation/access_denied_screen.dart';
import '../../features/access/presentation/access_loading_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';

import '../../features/receiving/presentation/receiving_list_screen.dart';
import '../../features/receiving/presentation/receiving_form_screen.dart';
import '../../features/lab_test/presentation/lab_test_list_screen.dart';
import '../../features/lab_test/presentation/lab_test_form_screen.dart';
import '../../features/lab_request/presentation/lab_request_list_screen.dart';
import '../../features/lab_request/presentation/lab_request_form_screen.dart';
import '../../features/lab_request/presentation/standalone_queue_screen.dart';
import '../../features/plant_inspection/presentation/inspection_list_screen.dart';
import '../../features/plant_inspection/presentation/inspection_process_selection_screen.dart';
import '../../features/plant_inspection/presentation/dynamic_inspection_form_screen.dart';
import 'navigation_shell.dart' as app_shell;

part 'app_router.g.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

@riverpod
GoRouter appRouter(Ref ref) {
  final authState = ref.watch(authNotifierProvider);
  final accessState = ref.watch(accessContextProvider);
  final variant = ref.watch(appVariantProvider);

  if (AppConfig.isolatedPlantLab) {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/splash',
      redirect: (context, state) {
        final access = accessState.valueOrNull;
        final assigned =
            access?.modules.contains(variant.code) == true ||
            access?.modules.contains('PLATFORM') == true;
        return redirectForAccess(
          location: state.matchedLocation,
          isAuthenticated:
              authState.valueOrNull?.maybeWhen(
                authenticated: (_) => true,
                orElse: () => false,
              ) ??
              false,
          isAccessLoading: accessState.isLoading,
          hasAccessError: accessState.hasError,
          access: assigned ? access : null,
          variant: variant,
        );
      },
      routes: [
        GoRoute(
          path: '/splash',
          builder: (_, _) => const PlantLabSplashScreen(),
        ),
        GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
        GoRoute(
          path: '/access-loading',
          builder: (_, _) => const AccessLoadingScreen(),
        ),
        GoRoute(
          path: '/access-denied',
          builder: (_, _) => const AccessDeniedScreen(),
        ),
        GoRoute(
          path: '/app/dashboard',
          builder: (_, _) => const StandaloneQueueScreen(),
        ),
      ],
    );
  }

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final isAuthenticated =
          authState.valueOrNull?.maybeWhen(
            authenticated: (_) => true,
            orElse: () => false,
          ) ??
          false;

      return redirectForAccess(
        location: state.matchedLocation,
        isAuthenticated: isAuthenticated,
        isAccessLoading: accessState.isLoading,
        hasAccessError: accessState.hasError,
        access: accessState.valueOrNull,
        variant: variant,
      );
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const PlantLabSplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/access-loading',
        builder: (context, state) => const AccessLoadingScreen(),
      ),
      GoRoute(
        path: '/access-denied',
        builder: (context, state) => const AccessDeniedScreen(),
      ),
      GoRoute(
        path: '/app/scanner',
        builder: (context, state) => const QrBarcodeScannerScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return app_shell.NavigationShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/receiving',
                builder: (context, state) => const ReceivingListScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const ReceivingFormScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/inspections',
                builder: (context, state) => const InspectionListScreen(),
                routes: [
                  GoRoute(
                    path: 'processes',
                    builder: (context, state) =>
                        const InspectionProcessSelectionScreen(),
                  ),
                  GoRoute(
                    path: 'new/:processType',
                    builder: (context, state) {
                      final pType =
                          state.pathParameters['processType'] ?? 'INTAKE';
                      return DynamicInspectionFormScreen(processType: pType);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/lab',
                builder: (context, state) => const LabTestListScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const LabTestFormScreen(),
                  ),
                  GoRoute(
                    path: 'requests',
                    builder: (context, state) => const LabRequestListScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (context, state) =>
                            const LabRequestFormScreen(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
