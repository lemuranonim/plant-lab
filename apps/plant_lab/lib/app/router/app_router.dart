// ignore_for_file: deprecated_member_use_from_same_package, unnecessary_import
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/auth/auth_notifier.dart';
import '../../core/auth/auth_state.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/lot/presentation/lot_list_screen.dart';
import '../../features/plant_plan/presentation/plant_plan_list_screen.dart';
import '../../features/plant_inspection/presentation/plant_inspection_list_screen.dart';
import '../../features/plant_inspection/presentation/plant_inspection_form_screen.dart';
import 'navigation_shell.dart' as app_shell;

part 'app_router.g.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

@riverpod
GoRouter appRouter(Ref ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/app/dashboard',
    redirect: (context, state) {
      final isAuthenticated = authState.valueOrNull?.maybeWhen(
        authenticated: (_) => true,
        orElse: () => false,
      ) ?? false;

      final isLoginRoute = state.matchedLocation == '/login';

      if (!isAuthenticated && !isLoginRoute) {
        return '/login';
      }

      if (isAuthenticated && isLoginRoute) {
        return '/app/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
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
                path: '/app/lots',
                builder: (context, state) => const LotListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/plant',
                builder: (context, state) => const PlantPlanListScreen(),
                routes: [
                  GoRoute(
                    path: ':planId/inspections',
                    builder: (context, state) => PlantInspectionListScreen(
                      planId: state.pathParameters['planId']!,
                    ),
                  ),
                  GoRoute(
                    path: ':planId/inspection/new',
                    builder: (context, state) => PlantInspectionFormScreen(
                      planId: state.pathParameters['planId']!,
                    ),
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
