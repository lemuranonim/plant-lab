import 'access_context.dart';
import '../config/app_variant.dart';

enum RouteAccessRequirement { public, authenticated, plant, lab }

RouteAccessRequirement accessRequirementForLocation(String location) {
  if (location == '/splash' || location == '/login') {
    return RouteAccessRequirement.public;
  }
  if (location == '/access-loading' || location == '/access-denied') {
    return RouteAccessRequirement.authenticated;
  }
  if (location.startsWith('/app/receiving') ||
      location.startsWith('/app/inspections')) {
    return RouteAccessRequirement.plant;
  }
  if (location.startsWith('/app/lab')) {
    return RouteAccessRequirement.lab;
  }
  return RouteAccessRequirement.authenticated;
}

bool canAccessLocation(
  AccessContext context,
  String location, {
  required AppVariant variant,
}) {
  return switch (accessRequirementForLocation(location)) {
    RouteAccessRequirement.public => true,
    RouteAccessRequirement.authenticated => variant.allows(context),
    RouteAccessRequirement.plant => variant.isPlant && context.canAccessPlant,
    RouteAccessRequirement.lab => variant.isLab && context.canAccessLab,
  };
}

String? redirectForAccess({
  required String location,
  required bool isAuthenticated,
  required bool isAccessLoading,
  required bool hasAccessError,
  required AccessContext? access,
  required AppVariant variant,
}) {
  final isLoginRoute = location == '/login';

  if (!isAuthenticated) {
    return location == '/splash' || isLoginRoute ? null : '/login';
  }
  if (location == '/splash') return null;

  if (isAccessLoading) {
    return location == '/access-loading' ? null : '/access-loading';
  }

  if (hasAccessError ||
      access == null ||
      !access.hasApplicationAccess ||
      !variant.allows(access)) {
    return location == '/access-denied' ? null : '/access-denied';
  }

  if (location == '/access-loading' || isLoginRoute) {
    return '/app/dashboard';
  }
  if (location == '/access-denied') return null;
  if (!canAccessLocation(access, location, variant: variant)) {
    return '/access-denied';
  }

  return null;
}
