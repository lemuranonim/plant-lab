import 'package:flutter_test/flutter_test.dart';
import 'package:plant_lab/core/access/access_context.dart';
import 'package:plant_lab/core/access/route_access_policy.dart';
import 'package:plant_lab/core/config/app_variant.dart';

void main() {
  group('AccessContext', () {
    test('parses the authenticated access-context RPC response', () {
      final context = AccessContext.fromJson(_labAnalystJson);

      expect(context.userId, '7ec33410-dc3d-4e0c-a0ec-e875ae90a53c');
      expect(context.primaryRoleName, 'Lab Analyst');
      expect(context.modules, ['LAB']);
      expect(context.roles.single.roleCode, 'LAB_ANALYST');
      expect(context.sites.single.siteCode, 'LAB-PASURUAN');
      expect(context.siteSummary, 'Advanta Laboratory Pasuruan');
      expect(context.canAccessLab, isTrue);
      expect(context.canAccessPlant, isFalse);
      expect(context.canManageUsers, isFalse);
      expect(context.hasApplicationAccess, isTrue);
    });

    test('rejects an invalid capability payload', () {
      final invalid = Map<String, dynamic>.from(_labAnalystJson)
        ..['can_access_lab'] = 'true';

      expect(
        () => AccessContext.fromJson(invalid),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('mobile route access policy', () {
    final labAnalyst = AccessContext.fromJson(_labAnalystJson);
    final plantSpv = AccessContext.fromJson({
      ..._labAnalystJson,
      'primary_role_name': 'Plant Supervisor',
      'modules': ['PLANT'],
      'roles': [
        {
          'module_code': 'PLANT',
          'role_code': 'PLANT_SPV',
          'role_name': 'Plant Supervisor',
          'site_id': '0bdad56b-39b0-4291-9b73-10fe58fee2c4',
          'company_id': 1,
        },
      ],
      'sites': [
        {
          'id': '0bdad56b-39b0-4291-9b73-10fe58fee2c4',
          'site_code': 'PLANT-PASURUAN',
          'site_name': 'Advanta Plant Pasuruan',
          'site_type': 'PLANT',
          'company_id': 1,
        },
      ],
      'can_access_plant': true,
      'can_access_lab': false,
    });
    final platformAdmin = AccessContext.fromJson({
      ..._labAnalystJson,
      'primary_role_name': 'Platform Administrator',
      'modules': ['PLATFORM'],
      'roles': [
        {
          'module_code': 'PLATFORM',
          'role_code': 'PLATFORM_ADMIN',
          'role_name': 'Platform Administrator',
          'site_id': null,
          'company_id': null,
        },
      ],
      'can_access_plant': true,
      'can_access_lab': true,
      'can_manage_users': true,
    });

    test('LAB_ANALYST can open Lab routes but not Plant routes', () {
      expect(
        canAccessLocation(
          labAnalyst,
          '/app/dashboard',
          variant: AppVariant.lab,
        ),
        isTrue,
      );
      expect(
        canAccessLocation(labAnalyst, '/app/lab', variant: AppVariant.lab),
        isTrue,
      );
      expect(
        canAccessLocation(
          labAnalyst,
          '/app/lab/requests/new',
          variant: AppVariant.lab,
        ),
        isTrue,
      );
      expect(
        canAccessLocation(
          labAnalyst,
          '/app/receiving',
          variant: AppVariant.lab,
        ),
        isFalse,
      );
      expect(
        canAccessLocation(
          labAnalyst,
          '/app/inspections/new/INTAKE',
          variant: AppVariant.lab,
        ),
        isFalse,
      );
    });

    test('PLANT_SPV can open Plant routes but not Lab routes', () {
      expect(
        canAccessLocation(
          plantSpv,
          '/app/dashboard',
          variant: AppVariant.plant,
        ),
        isTrue,
      );
      expect(
        canAccessLocation(
          plantSpv,
          '/app/receiving/new',
          variant: AppVariant.plant,
        ),
        isTrue,
      );
      expect(
        canAccessLocation(
          plantSpv,
          '/app/inspections',
          variant: AppVariant.plant,
        ),
        isTrue,
      );
      expect(
        canAccessLocation(plantSpv, '/app/lab', variant: AppVariant.plant),
        isFalse,
      );
    });

    test('PLATFORM_ADMIN is still limited to the installed app variant', () {
      expect(
        canAccessLocation(
          platformAdmin,
          '/app/receiving',
          variant: AppVariant.plant,
        ),
        isTrue,
      );
      expect(
        canAccessLocation(platformAdmin, '/app/lab', variant: AppVariant.plant),
        isFalse,
      );
      expect(
        canAccessLocation(platformAdmin, '/app/lab', variant: AppVariant.lab),
        isTrue,
      );
      expect(
        canAccessLocation(
          platformAdmin,
          '/app/inspections',
          variant: AppVariant.lab,
        ),
        isFalse,
      );
    });

    test('redirects unauthenticated, loading, and forbidden routes safely', () {
      expect(
        redirectForAccess(
          location: '/app/dashboard',
          isAuthenticated: false,
          isAccessLoading: false,
          hasAccessError: false,
          access: null,
          variant: AppVariant.lab,
        ),
        '/login',
      );
      expect(
        redirectForAccess(
          location: '/app/dashboard',
          isAuthenticated: true,
          isAccessLoading: true,
          hasAccessError: false,
          access: null,
          variant: AppVariant.lab,
        ),
        '/access-loading',
      );
      expect(
        redirectForAccess(
          location: '/app/inspections',
          isAuthenticated: true,
          isAccessLoading: false,
          hasAccessError: false,
          access: labAnalyst,
          variant: AppVariant.lab,
        ),
        '/access-denied',
      );
      expect(
        redirectForAccess(
          location: '/app/lab',
          isAuthenticated: true,
          isAccessLoading: false,
          hasAccessError: false,
          access: labAnalyst,
          variant: AppVariant.lab,
        ),
        isNull,
      );
      expect(
        redirectForAccess(
          location: '/app/dashboard',
          isAuthenticated: true,
          isAccessLoading: false,
          hasAccessError: false,
          access: labAnalyst,
          variant: AppVariant.plant,
        ),
        '/access-denied',
      );
    });
  });
}

const _labAnalystJson = <String, dynamic>{
  'user_id': '7ec33410-dc3d-4e0c-a0ec-e875ae90a53c',
  'primary_role_name': 'Lab Analyst',
  'modules': ['LAB'],
  'roles': [
    {
      'module_code': 'LAB',
      'role_code': 'LAB_ANALYST',
      'role_name': 'Lab Analyst',
      'site_id': 'd39dd9b4-833b-4482-8270-59ec8915a177',
      'company_id': 1,
    },
  ],
  'sites': [
    {
      'id': 'd39dd9b4-833b-4482-8270-59ec8915a177',
      'site_code': 'LAB-PASURUAN',
      'site_name': 'Advanta Laboratory Pasuruan',
      'site_type': 'LAB',
      'company_id': 1,
    },
  ],
  'can_access_plant': false,
  'can_access_lab': true,
  'can_manage_users': false,
};
