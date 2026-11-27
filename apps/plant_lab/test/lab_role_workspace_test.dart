import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_lab/app/theme/lab_theme.dart';
import 'package:plant_lab/core/access/access_context.dart';
import 'package:plant_lab/core/access/access_context_provider.dart';
import 'package:plant_lab/core/config/app_config.dart';
import 'package:plant_lab/core/config/app_variant.dart';
import 'package:plant_lab/features/lab_request/presentation/lab_revalidation.dart';
import 'package:plant_lab/features/lab_request/presentation/standalone_queue_screen.dart';

import 'lab_revalidation_test.dart' as fixtures;

const _lab = AccessSite(
  id: 'lab-fixture',
  siteCode: 'DEMO',
  siteName: 'Lab Demo',
  siteType: 'LAB',
  companyId: 1,
);

void main() {
  for (final (label, analyst, admin) in [
    ('Analis', true, false),
    ('QA biasa', false, false),
    ('QA dengan Admin Revalidation', false, true),
  ]) {
    testWidgets(
      '$label sees the Lab menu and only its test actions',
      (tester) async {
        tester.view.physicalSize = const Size(375, 840);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final access = AccessContext(
          userId: 'current-user',
          primaryRoleName: analyst ? 'Lab Analyst' : 'Lab QA Approver',
          modules: const ['LAB'],
          roles: [
            AccessRole(
              moduleCode: 'LAB',
              roleCode: analyst ? 'LAB_ANALYST' : 'LAB_QA_APPROVER',
              roleName: analyst ? 'Lab Analyst' : 'Lab QA Approver',
              siteId: _lab.id,
              companyId: _lab.companyId,
            ),
            if (admin)
              const AccessRole(
                moduleCode: 'LAB',
                roleCode: 'LAB_REVALIDATION_ADMIN',
                roleName: 'Admin Revalidation Lab',
                siteId: 'lab-fixture',
                companyId: 1,
              ),
          ],
          sites: const [_lab],
          canAccessPlant: false,
          canAccessLab: true,
          canManageUsers: false,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appVariantProvider.overrideWithValue(AppVariant.lab),
              accessContextProvider.overrideWith((_) async => access),
              standaloneQualityReferenceProvider.overrideWith((_) async => {}),
              standaloneQueueProvider.overrideWith(
                (_) async => (
                  requests: const [
                    PreviewLabRequest(
                      requestId: 'received',
                      requestCode: 'LR-DEMO-01',
                      lotCode: 'DEMO-DCS-01',
                      testCodes: ['GERMINATION'],
                      status: 'RECEIVED',
                      requestedAt: '2026-11-24T01:00:00Z',
                      instruction: null,
                    ),
                    PreviewLabRequest(
                      requestId: 'review',
                      requestCode: 'LR-DEMO-02',
                      lotCode: 'DEMO-DCS-02',
                      testCodes: ['GERMINATION'],
                      status: 'IN_REVIEW',
                      requestedAt: '2026-11-24T01:00:00Z',
                      instruction: null,
                      germination: {
                        'run_code': 'LT-DEMO-02',
                        'status': 'IN_REVIEW',
                        'is_assigned_analyst': false,
                        'summary': {
                          'germination_percent': 94,
                          'gap_pp': 2,
                          'limit_pp': 7,
                          'within_tolerance': true,
                          'replicates': [
                            {'normal': 93, 'abnormal': 5, 'dead': 2},
                            {'normal': 95, 'abnormal': 4, 'dead': 1},
                          ],
                        },
                      },
                    ),
                  ],
                  pairLookupFailed: false,
                  vigourLookupFailed: false,
                ),
              ),
            ],
            child: MaterialApp(
              theme: LabTheme.light,
              home: const StandaloneQueueScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Catatan uji rutin & QA'), findsOneWidget);
        expect(find.text('MC Lab'), findsOneWidget);
        expect(find.text('Buku pengujian Lab'), findsOneWidget);
        expect(find.text('Pemantauan kerja Lab'), findsOneWidget);
        if (AppConfig.plantSampleRequestsEnabled) {
          expect(find.text('Permintaan sampel ke Plant'), findsOneWidget);
        }
        expect(find.text('Ajukan Permintaan Uji'), findsNothing);
        expect(find.text('Input harian'), findsNothing);
        expect(
          find.text('Catat pembacaan kadar air.'),
          analyst ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Verifikasi catatan kadar air.'),
          analyst ? findsNothing : findsOneWidget,
        );

        Future<void> select(String id) async {
          final target = find.byKey(ValueKey('lab-open-request-$id'));
          await tester.scrollUntilVisible(
            target,
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await tester.tap(target.hitTestable());
          await tester.pumpAndSettle();
        }

        await select('received');
        final method = find.text('Germinasi · Pasir 25 °C');
        if (analyst) {
          await tester.ensureVisible(method);
          await tester.tap(method);
          await tester.pumpAndSettle();
        }
        expect(
          find.text('Mulai uji Germinasi'),
          analyst ? findsOneWidget : findsNothing,
        );
        expect(find.text('Review hasil'), findsNothing);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await select('review');
        await tester.ensureVisible(method);
        await tester.tap(method);
        await tester.pumpAndSettle();
        expect(
          find.text('Review hasil'),
          analyst ? findsNothing : findsOneWidget,
        );
        expect(find.text('Isi pengamatan final'), findsNothing);
        expect(tester.takeException(), isNull);

        final reads = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: LabTheme.light,
            home: Scaffold(
              body: SingleChildScrollView(
                child: LabRevalidationPanel(
                  labSiteId: _lab.id,
                  onCreated: () {},
                  command: (rpc, args) async {
                    reads.add(rpc);
                    expect(args['p_lab_site_id'], _lab.id);
                    return switch (rpc) {
                      'get_lab_revalidation_options' => {
                        'can_authorize': admin,
                        'can_start': analyst,
                        'candidates': [fixtures.source],
                        'total': 1,
                        'offset': 0,
                      },
                      'list_lab_revalidations' => {
                        'authorizations': [
                          {
                            ...fixtures.plan,
                            'can_start': analyst,
                            'can_cancel': admin,
                          },
                        ],
                        'total': 1,
                        'offset': 0,
                      },
                      _ => throw StateError('Unexpected command: $rpc'),
                    };
                  },
                ),
              ),
            ),
          ),
        );
        await fixtures.tapVisible(tester, find.text('Revalidation 1–3'));
        await fixtures.tapVisible(tester, find.text('Muat Revalidation'));
        if (!admin) {
          await fixtures.tapVisible(tester, find.text('Hasil sumber'));
        }
        expect(
          find.text('Beri persetujuan Revalidation 1'),
          admin ? findsOneWidget : findsNothing,
        );
        await fixtures.tapVisible(tester, find.text('Persetujuan'));
        expect(
          find.text('Siapkan catatan Revalidation 1'),
          analyst ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Batalkan persetujuan yang belum dimulai'),
          admin ? findsOneWidget : findsNothing,
        );
        expect(reads, [
          'get_lab_revalidation_options',
          'list_lab_revalidations',
        ]);
        expect(tester.takeException(), isNull);
      },
      skip: !AppConfig.hostedPilot || !AppConfig.canonicalWritesEnabled,
    );
  }
}
