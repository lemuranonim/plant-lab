import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_lab/app/theme/app_theme.dart';
import 'package:plant_lab/app/theme/lab_theme.dart';
import 'package:plant_lab/core/config/app_config.dart';
import 'package:plant_lab/core/access/access_context.dart';
import 'package:plant_lab/core/access/access_context_provider.dart';
import 'package:plant_lab/core/config/app_variant.dart';
import 'package:plant_lab/features/lab_request/presentation/standalone_queue_screen.dart';
import 'package:plant_lab/features/lab_request/presentation/lab_workspace_widgets.dart';
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
    for (final theme in [
      AppTheme.light,
      AppTheme.dark,
      LabTheme.light,
      LabTheme.dark,
    ]) {
      final a = theme.colorScheme.primary.computeLuminance();
      final b = theme.colorScheme.onPrimary.computeLuminance();
      final ratio = ((a > b ? a : b) + .05) / ((a < b ? a : b) + .05);
      expect(ratio, greaterThanOrEqualTo(4.5));
      final palette = theme.extension<LabPalette>();
      if (palette != null) {
        for (final status in [
          'REQUESTED',
          'TESTING',
          'IN_REVIEW',
          'RETEST',
          'APPROVED',
          'CLOSED',
        ]) {
          final tone = palette.status(status);
          final x = tone.ink.computeLuminance();
          final y = tone.surface.computeLuminance();
          expect(
            ((x > y ? x : y) + .05) / ((x < y ? x : y) + .05),
            greaterThanOrEqualTo(4.5),
            reason: status,
          );
        }
      }
    }
  });

  testWidgets('Lab detail pins the lot and follows the current queue scope', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const lot = 'UJI-DCS-026';
    var status = 'REQUESTED';
    var inScope = true;
    const access = AccessContext(
      userId: 'MEMORY-ONLY',
      primaryRoleName: 'Analis Lab',
      modules: ['LAB'],
      roles: [
        AccessRole(
          moduleCode: 'LAB',
          roleCode: 'LAB_ANALYST',
          roleName: 'Analis',
        ),
      ],
      sites: [],
      canAccessPlant: false,
      canAccessLab: true,
      canManageUsers: false,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appVariantProvider.overrideWithValue(AppVariant.lab),
          accessContextProvider.overrideWith((_) async => access),
          standaloneQueueProvider.overrideWith(
            (_) async => (
              requests: [
                if (inScope)
                  PreviewLabRequest(
                    requestId: 'local-request',
                    requestCode: 'UJI-LR-001',
                    lotCode: lot,
                    testCodes: const ['GERMINATION'],
                    status: status,
                    requestedAt: '2026-11-07T12:00:00Z',
                    instruction: List.filled(
                      18,
                      'Catatan pengiriman sampel.',
                    ).join(' '),
                  ),
              ],
              pairLookupFailed: false,
              vigourLookupFailed: false,
            ),
          ),
          standaloneQualityReferenceProvider.overrideWith((_) async => {}),
        ],
        child: MaterialApp(
          theme: LabTheme.light,
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
    final container = ProviderScope.containerOf(
      tester.element(find.byType(StandaloneQueueScreen)),
    );
    final open = find.byKey(const ValueKey('lab-open-request-local-request'));
    await tester.scrollUntilVisible(
      open,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Terima permintaan'), findsNothing);
    await tester.pumpAndSettle();
    await tester.tap(open.hitTestable());
    await tester.pumpAndSettle();

    final header = find.descendant(
      of: find.byType(AppBar),
      matching: find.text(lot),
    );
    expect(header, findsOneWidget);
    final accept = find.text('Terima permintaan');
    expect(
      accept,
      AppConfig.canonicalWritesEnabled ? findsOneWidget : findsNothing,
    );
    final top = tester.getTopLeft(header);
    final metadata = find.text('Rincian permintaan & pasangan lot');
    await tester.ensureVisible(metadata);
    await tester.tap(metadata);
    await tester.pumpAndSettle();
    final list = find.byType(ListView);
    await tester.drag(list, const Offset(0, -350));
    await tester.pumpAndSettle();
    final scroll = find.descendant(of: list, matching: find.byType(Scrollable));
    expect(
      tester.state<ScrollableState>(scroll.first).position.pixels,
      greaterThan(0),
    );
    expect(tester.getTopLeft(header), top);

    status = 'ACCEPTED';
    container.invalidate(standaloneQueueProvider);
    await tester.pumpAndSettle();
    expect(accept, findsNothing);
    expect(
      find.text(
        AppConfig.canonicalWritesEnabled
            ? 'Menunggu kiriman Plant'
            : 'Lihat detail · baca saja',
      ),
      findsOneWidget,
    );
    inScope = false;
    container.invalidate(standaloneQueueProvider);
    await tester.pumpAndSettle();
    expect(header, findsNothing);
    expect(
      find.text('Permintaan tidak tersedia dalam antrean Anda.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
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
                theme: plant
                    ? (dark ? AppTheme.dark : AppTheme.light)
                    : (dark ? LabTheme.dark : LabTheme.light),
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
          final guideTitle = workflowRoleGuide(plant, [role]).title;
          if (plant) {
            expect(find.text(guideTitle), findsOneWidget);
          } else {
            expect(find.textContaining(guideTitle), findsNothing);
            await tester.tap(find.text('Bantuan antrean').hitTestable());
            await tester.pumpAndSettle();
            expect(find.textContaining(guideTitle), findsOneWidget);
            await tester.tap(find.text('Tutup bantuan').hitTestable());
            await tester.pumpAndSettle();
          }
          expect(find.byType(NavigationBar), findsOneWidget);
          expect(
            find.byType(LabQueueHero),
            plant ? findsNothing : findsOneWidget,
          );
          if (!plant) {
            final routineLink = find.text('Catatan uji rutin & QA');
            await tester.scrollUntilVisible(
              routineLink,
              140,
              scrollable: find.byType(Scrollable).first,
            );
            expect(routineLink, findsOneWidget);
            if (AppConfig.plantSampleRequestsEnabled) {
              final samplesLink = find.text('Permintaan sampel ke Plant');
              await tester.scrollUntilVisible(
                samplesLink,
                140,
                scrollable: find.byType(Scrollable).first,
              );
              expect(samplesLink, findsOneWidget);
            }
          }
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
