import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_lab/features/lab_request/presentation/lab_revalidation.dart';

final source = <String, dynamic>{
  'run_id': 'engineering-source',
  'run_code': 'LT-ENGINEERING',
  'lot_code': 'ENGINEERING-ONLY',
  'hybrid': 'H59',
  'method_code': 'SAND_25C',
  'method_name': 'Germinasi',
  'sample_reference': 'SAMPLE-ONLY',
  'next_stage': 1,
  'blocked_reason': null,
};
final plan = <String, dynamic>{
  'id': 'engineering-plan',
  'source_run_code': 'LT-ENGINEERING',
  'lot_code': 'ENGINEERING-ONLY',
  'stage': 1,
  'method_code': 'SAND_25C',
  'method_name': 'Germinasi',
  'sample_reference': 'SAMPLE-ONLY',
  'sample_plan': 'RETAINED_LAB',
  'sample_evidence': 'Rak A-1',
  'authorizer_name': 'Admin nyata',
  'authorized_at': '2026-11-16T01:00:00Z',
  'reason': 'Pemeriksaan simpanan',
  'status': 'AUTHORIZED',
  'can_start': true,
  'can_cancel': false,
};

Future<void> tapVisible(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Analis can search bounded sources but cannot authorize; no false empty on error',
    (tester) async {
      final calls = <Map<String, dynamic>>[];
      bool fail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LabRevalidationPanel(
                labSiteId: 'lab-only',
                onCreated: () {},
                command: (name, args) async {
                  calls.add({'name': name, ...args});
                  if (fail) throw Exception('offline');
                  return name == 'get_lab_revalidation_options'
                      ? {
                          'can_authorize': false,
                          'can_start': true,
                          'candidates': [source],
                          'offset': 0,
                          'total': 1,
                          'has_more': true,
                        }
                      : {
                          'authorizations': <Map<String, dynamic>>[],
                          'offset': 0,
                          'total': 0,
                          'has_more': false,
                        };
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Revalidation 1–3'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'H59');
      await tester.tap(find.text('Muat Revalidation'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('bukan berarti daftar kosong'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Sumber analisis yang disetujui QA'),
        findsNothing,
      );
      fail = false;
      await tester.tap(find.text('Muat Revalidation'));
      await tester.pumpAndSettle();
      expect(find.text('Beri persetujuan Revalidation 1'), findsNothing);
      await tapVisible(tester, find.text('Sumber berikutnya'));
      expect(
        calls.lastWhere(
          (c) => c['name'] == 'get_lab_revalidation_options',
        )['p_offset'],
        50,
      );
      expect(
        calls.lastWhere(
          (c) => c['name'] == 'get_lab_revalidation_options',
        )['p_search'],
        'H59',
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final brightness in Brightness.values) {
    testWidgets(
      'Admin manual authorization explicit plan and stable retry $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final calls = <Map<String, dynamic>>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: RevalidationActionScreen(
              mode: 'AUTHORIZE',
              item: source,
              labSiteId: 'lab-only',
              command: (name, args) async {
                expect(name, 'authorize_lab_revalidation');
                calls.add(args);
                throw Exception('offline');
              },
            ),
          ),
        );
        await tester.enterText(
          find.byType(TextFormField).first,
          'Admin Lapangan',
        );
        await tapVisible(tester, find.byType(DropdownButtonFormField<String>));
        await tester.tap(find.text('Sampel simpanan Lab').last);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.widgetWithText(TextFormField, 'Alasan Revalidation'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Alasan Revalidation'),
          'Periksa benih simpanan',
        );
        await tester.scrollUntilVisible(
          find.widgetWithText(
            TextFormField,
            'Rujukan / lokasi / catatan sampel',
          ),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(
          find.widgetWithText(
            TextFormField,
            'Rujukan / lokasi / catatan sampel',
          ),
          'Rak A-1 sesuai label',
        );
        await tapVisible(tester, find.byType(CheckboxListTile));
        await tapVisible(tester, find.text('Simpan persetujuan'));
        expect(calls.length, 1);
        await tapVisible(tester, find.text('Simpan persetujuan'));
        expect(calls.length, 2);
        expect(calls.first, calls.last);
        expect(calls.first['p_sample_plan'], 'RETAINED_LAB');
        expect(calls.first['p_authorizer_name'], 'Admin Lapangan');
        expect(calls.first.containsKey('p_replicate_count'), isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Retained start needs physical availability; label locked and 2 or 4x100 selectable',
    (tester) async {
      final calls = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: RevalidationActionScreen(
            mode: 'START',
            item: plan,
            labSiteId: 'lab-only',
            command: (name, args) async {
              calls.add({'name': name, ...args});
              throw Exception('memory offline');
            },
          ),
        ),
      );
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
      expect(find.text('SAMPLE-ONLY'), findsOneWidget);
      expect(find.text('Belum diisi'), findsOneWidget);
      await tapVisible(tester, find.byType(CheckboxListTile));
      await tapVisible(tester, find.text('Siapkan catatan kosong'));
      expect(calls, isEmpty);
      expect(find.textContaining('Isi waktu sampel'), findsOneWidget);
      await tapVisible(tester, find.byTooltip('Pilih waktu sampel tersedia'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byType(DropdownButtonFormField<int>));
      await tester.tap(find.text('4 × 100 benih').last);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Siapkan catatan kosong'));
      expect(calls.single['name'], 'start_lab_revalidation');
      expect(calls.single['p_sample_reference'], 'SAMPLE-ONLY');
      expect(calls.single['p_replicate_count'], 4);
      expect(calls.single['p_sample_confirmed'], true);
      expect(
        DateTime.parse(calls.single['p_available_at'] as String).isUtc,
        isTrue,
      );
      expect(calls.single.containsKey('p_observations'), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('RET always 4x100, new sample blank; cancel reason mandatory', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RevalidationActionScreen(
          mode: 'START',
          item: {
            ...plan,
            'method_code': 'RET_16C_72H',
            'sample_plan': 'NEW_SAMPLE',
          },
          labSiteId: 'lab-only',
          command: (_, _) async => {},
        ),
      ),
    );
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isFalse);
    expect(find.text('SAMPLE-ONLY'), findsNothing);
    expect(find.text('4 × 100 benih'), findsOneWidget);
    final calls = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: RevalidationActionScreen(
          key: const ValueKey('cancel'),
          mode: 'CANCEL',
          item: plan,
          labSiteId: 'lab-only',
          command: (name, args) async {
            calls.add({'name': name, ...args});
            throw Exception('offline');
          },
        ),
      ),
    );
    await tapVisible(tester, find.byType(CheckboxListTile));
    await tapVisible(tester, find.text('Simpan pembatalan'));
    expect(calls, isEmpty);
    await tester.enterText(find.byType(TextFormField), 'Sampel belum tersedia');
    await tapVisible(tester, find.text('Simpan pembatalan'));
    expect(calls.single['name'], 'cancel_lab_revalidation');
    expect(calls.single['p_reason'], 'Sampel belum tersedia');
    expect(tester.takeException(), isNull);
  });
}
