import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_lab/app/theme/app_theme.dart';
import 'package:plant_lab/core/access/access_context.dart';
import 'package:plant_lab/core/access/access_context_provider.dart';
import 'package:plant_lab/core/config/app_variant.dart';
import 'package:plant_lab/features/lab_request/presentation/standalone_queue_screen.dart';
import 'package:plant_lab/features/lab_request/presentation/workflow_presentation.dart';

void main() {
  test(
    'labels do not turn approval into release and preserve unknown codes',
    () {
      expect(workflowStatus('APPROVED'), 'Hasil disetujui');
      expect(workflowStatus('NEW-SERVER-STATUS'), 'NEW-SERVER-STATUS');
      expect(
        workflowNextStep('APPROVED', true),
        contains('bukan pelepasan lot'),
      );
      expect(
        workflowNextStep('IN_REVIEW', false, reviewer: true),
        contains('review QA independen'),
      );
      expect(workflowNextStep('IN_REVIEW', false), contains('Menunggu review'));
      expect(workflowNextStep('SENT', false), contains('sampel fisik'));
      expect(workflowNextStep('SENT', true), contains('Menunggu'));
      expect(workflowGroup('IN_REVIEW'), 'review');
      expect(workflowGroup('CANCELLED'), 'closed');
      expect(workflowGroup('NEW-SERVER-STATUS'), 'active');
    },
  );
  test('role guides cover PI without granting PI to operators', () {
    expect(workflowRoleGuide(true, ['PLANT_PI']).title, 'Pengukuran mutu PI');
    expect(
      workflowRoleGuide(true, ['PLANT_OPERATOR']).title,
      'Pekerjaan operator Plant',
    );
    expect(workflowRoleGuide(true, ['PLANT_SPV']).title, 'Pengawasan Plant');
    expect(
      workflowRoleGuide(false, ['LAB_ANALYST']).title,
      'Pekerjaan analis Lab',
    );
    expect(
      workflowRoleGuide(false, ['LAB_QA_APPROVER']).title,
      'Pemeriksaan hasil Lab',
    );
  });
  test('action contrast is readable in both themes', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final a = theme.colorScheme.primary.computeLuminance();
      final b = theme.colorScheme.onPrimary.computeLuminance();
      final ratio = ((a > b ? a : b) + .05) / ((a < b ? a : b) + .05);
      expect(ratio, greaterThanOrEqualTo(4.5));
    }
  });

  for (final role in [
    'PLANT_OPERATOR',
    'PLANT_SPV',
    'PLANT_PI',
    'LAB_ANALYST',
    'LAB_QA_APPROVER',
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        '$role queue at 320px and 150% text, ${dark ? 'dark' : 'light'}',
        (tester) async {
          tester.view.physicalSize = const Size(320, 850);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final plant = role.startsWith('PLANT');
          final variant = plant ? AppVariant.plant : AppVariant.lab;
          final access = AccessContext(
            userId: 'MEMORY-ONLY',
            primaryRoleName: role,
            modules: [variant.code],
            roles: [
              AccessRole(
                moduleCode: variant.code,
                roleCode: role,
                roleName: role,
              ),
            ],
            sites: [
              AccessSite(
                id: 'MEMORY-SITE',
                siteCode: plant ? 'PRASAD' : 'LAB-PASURUAN',
                siteName: plant ? 'PRASAD' : 'Advanta Laboratory Pasuruan',
                siteType: variant.code,
                companyId: 1,
              ),
            ],
            canAccessPlant: plant,
            canAccessLab: !plant,
            canManageUsers: false,
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                appVariantProvider.overrideWithValue(variant),
                accessContextProvider.overrideWith((ref) async => access),
                standaloneQueueProvider.overrideWith(
                  (ref) async => (
                    requests: const [
                      PreviewLabRequest(
                        requestId: 'MEMORY-REQUEST',
                        requestCode: 'MEMORY-ONLY-LONG-REQUEST-ID-123456789',
                        lotCode: 'DEMO-RR-0002',
                        testCodes: ['GERMINATION'],
                        status: 'APPROVED',
                        requestedAt: '2026-11-07T12:00:00Z',
                        instruction: null,
                      ),
                    ],
                    pairLookupFailed: false,
                    vigourLookupFailed: false,
                  ),
                ),
                standaloneQualityReferenceProvider.overrideWith(
                  (ref) async => {},
                ),
              ],
              child: MaterialApp(
                theme: dark ? AppTheme.dark : AppTheme.light,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.5)),
                  child: child!,
                ),
                home: const StandaloneQueueScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(workflowRoleGuide(plant, [role]).title),
            findsOneWidget,
          );
          expect(find.byType(NavigationBar), findsOneWidget);
          expect(find.text('Terima permintaan'), findsNothing);
          await tester.scrollUntilVisible(
            find.byType(TextField),
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.enterText(find.byType(TextField), 'not-a-real-lot');
          await tester.pumpAndSettle();
          expect(find.text('Tidak ada hasil yang cocok'), findsOneWidget);
          await tester.tap(find.byTooltip('Hapus pencarian'));
          await tester.pumpAndSettle();
          expect(find.text('DEMO-RR-0002'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
