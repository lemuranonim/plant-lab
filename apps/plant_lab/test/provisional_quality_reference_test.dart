import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_lab/features/lab_request/presentation/provisional_quality_reference.dart';
import 'package:plant_lab/features/lab_request/presentation/standalone_request_actions.dart';

void main() {
  final scopedRules = [
    for (final programme in ['COMMERCIAL', 'PARENT_SEED'])
      for (final crop in ['FC', 'SWC'])
        for (final test in ['GERMINATION', 'VIGOUR'])
          <String, dynamic>{
            'programme_code': programme,
            'crop_category_code': crop,
            'test_code': test,
            'minimum_percent': test == 'GERMINATION'
                ? 90
                : programme == 'PARENT_SEED'
                ? 70
                : 80,
            'version': 3,
            'validation_status': 'PENDING_CONTROLLED_SOP',
            'business_confirmation_status': 'USER_CONFIRMED',
          },
  ];
  test('programme-aware eight rules keep PS70 separate from commercial80', () {
    expect(validQualityReferences(scopedRules), true);
    expect(validQualityReferences(scopedRules.take(7).toList()), false);
    expect(
      validQualityReferences([...scopedRules.take(7), scopedRules.first]),
      false,
    );
    expect(qualityProgrammeLabel('PARENT_SEED'), 'Parent Seed (PS)');
    expect(qualityProgrammeLabel('PS'), '');
    expect(
      qualityReferenceConfirmation(scopedRules.first),
      'Angka dikonfirmasi tim',
    );
  });
  testWidgets(
    'confirmed RET contract wraps on narrow screens and does not activate writes',
    (tester) async {
      tester.view.physicalSize = const Size(375, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                ProvisionalQualityReference(
                  rules: scopedRules,
                  methods: const [
                    {
                      'method_code': 'RET_16C_72H',
                      'method_name': 'Radicle Emergence Test',
                      'replicate_count': 4,
                      'seeds_per_replicate': 100,
                      'minimum_radicle_mm': 2,
                      'duration_days': 3,
                    },
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('Acuan mutu sementara FC / Sweet Corn'));
      await tester.pumpAndSettle();
      expect(find.textContaining('radikula ≥2 mm · 3 hari'), findsOneWidget);
      expect(find.textContaining('4 × 100 benih'), findsOneWidget);
      expect(
        find.textContaining('Form hasil Vigor belum aktif'),
        findsOneWidget,
      );
      expect(find.byType(ElevatedButton), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  final lots = [
    {'id': 'one', 'lot_code': 'DEMO-R-0002', 'company_id': 2},
    {'id': 'two', 'lot_code': 'DEMO-RR-0002', 'company_id': 2},
  ];
  test('search keeps double-R identity, selected lot and source order', () {
    expect(filterReferenceLots(lots, ' demo-rr ', null).single['id'], 'two');
    expect(filterReferenceLots(lots, 'UNKNOWN', null), isEmpty);
    expect(filterReferenceLots(lots, 'UNKNOWN', 'one').single['id'], 'one');
    expect(filterReferenceLots(lots, '', null), lots);
  });
  testWidgets(
    'old approved result is not retrospectively called provisional PASS',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ProvisionalResultSnapshot(snapshot: null)),
        ),
      );
      expect(
        find.textContaining(RegExp('hasil lama tidak dievaluasi ulang', caseSensitive: false)),
        findsOneWidget,
      );
      expect(find.textContaining('Memenuhi acuan'), findsNothing);
    },
  );
  testWidgets('below-threshold snapshot remains provisional, not release', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProvisionalResultSnapshot(
            snapshot: {
              'assessment': 'BELOW_PROVISIONAL_REFERENCE',
              'minimum_percent': 90,
              'version': 1,
            },
          ),
        ),
      ),
    );
    expect(find.textContaining('Di bawah acuan sementara'), findsOneWidget);
    expect(find.textContaining('bukan izin pelepasan lot'), findsOneWidget);
  });
  testWidgets(
    'dialog searches more than 100 lots without submitting or networking',
    (tester) async {
      final many = [
        for (var i = 0; i < 650; i++)
          {'id': 'unit-$i', 'lot_code': 'LOT-$i', 'company_id': 2},
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StandaloneSubmitDialog(
              options: Future.value({
                'lots': many,
                'lab_sites': <Map<String, dynamic>>[],
                'test_types': <Map<String, dynamic>>[],
              }),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Cari kode lot'),
        'LOT-649',
      );
      await tester.pump();
      expect(
        find.text('1 pilihan ditampilkan dari 650 lot dalam cakupan Anda.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
