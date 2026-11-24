import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_lab/features/lab_request/presentation/standalone_lot_reference.dart';

void main() {
  for (final stage in ['DSS', 'DCS']) {
    testWidgets('keeps the tested $stage lot separate from the reference', (
      tester,
    ) async {
      final pair = PreviewLotPair.fromJson({
        'tested_stage_code': stage,
        'dss_lot_code': 'TEST-DSS-0123456789-0123456789-0123456789',
        'dcs_lot_code': 'TEST-DCS-0123456789-0123456789-0123456789',
      });
      final code = stage == 'DSS' ? pair.dssCode : pair.dcsCode;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 240,
                child: StandaloneRequestHeading(
                  requestCode: 'TEST-REQUEST',
                  status: 'APPROVED',
                  lotCode: code,
                  pair: pair,
                  details: 'Uji: GERMINATION',
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text(code), findsOneWidget);
      await tester.tap(find.text('Detail permintaan & pasangan lot'));
      await tester.pumpAndSettle();
      expect(find.text('Lot diuji: $code ($stage)'), findsOneWidget);
      expect(find.text('DSS: ${pair.dssCode}'), findsOneWidget);
      expect(find.text('DCS: ${pair.dcsCode}'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('keeps an unpaired request visible without inferring a pair', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: StandaloneLotReference(testedCode: 'TEST-LOT')),
    );
    expect(find.text('Lot diuji: TEST-LOT'), findsOneWidget);
    expect(find.text('Rujukan pasangan DSS–DCS'), findsNothing);
  });

  testWidgets('long request number does not compete with the status badge', (
    tester,
  ) async {
    const code = 'LR-6267F25D4A5B429987FF';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            child: StandaloneRequestHeading(
              requestCode: code,
              status: 'APPROVED',
              lotCode: 'UNIT-DCS',
              details: '',
            ),
          ),
        ),
      ),
    );
    expect(find.text('UNIT-DCS'), findsOneWidget);
    expect(find.text('Hasil disetujui'), findsOneWidget);
    await tester.tap(find.text('Detail permintaan & pasangan lot'));
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsOneWidget);
    expect(
      tester.getBottomLeft(find.text('Hasil disetujui')).dy,
      lessThan(tester.getTopLeft(find.text(code)).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
