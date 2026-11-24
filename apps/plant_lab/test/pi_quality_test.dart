import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_lab/features/plant_inspection/presentation/pi_quality_screen.dart';

Future<void> reveal(
  WidgetTester tester,
  Finder finder, {
  double delta = 300,
}) async {
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
}

const lotId = '74000000-0000-4000-8000-000000000041';
Map<String, dynamic> options() => {
  'lots': [
    {
      'id': lotId,
      'lot_code': 'TEST-PI',
      'product_name': 'Test SWC',
      'site_code': 'TEST',
      'crop_category_code': 'SWC',
      'can_write': true,
    },
  ],
  'pp_components': piComponentLabels.keys.toList(),
};
Map<String, dynamic> record(String type) => {
  'id': '74000000-0000-4000-8000-000000000021',
  'lot_id': lotId,
  'test_type': type,
  'material_form': 'SEED',
  'crop_kind': 'SWC',
  'programme': 'COMMERCIAL',
  'numeric_value': null,
  'tested_at': '2026-11-08T08:00:00+07:00',
  'row_version': 1,
  'revision_of_id': null,
  'method_reference': 'TEST-METHOD',
  'equipment_reference': 'TEST-SCALE',
  'notes': '',
  'components': <String, dynamic>{},
  'evidence': <dynamic>[],
  'can_write': true,
  'source_status': 'DRAFT',
};
void main() {
  test('photo header is checked independently of filename', () {
    expect(
      piImageKind(Uint8List.fromList([255, 216, 255, 0])).mime,
      'image/jpeg',
    );
    expect(
      piImageKind(
        Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
      ).extension,
      'png',
    );
    expect(
      piImageKind(Uint8List.fromList('RIFF0000WEBP'.codeUnits)).mime,
      'image/webp',
    );
    expect(
      () => piImageKind(Uint8List.fromList('<svg/>'.codeUnits)),
      throwsFormatException,
    );
    expect(() => piImageKind(Uint8List(0)), throwsFormatException);
  });
  testWidgets('small TSW form preserves grams, 1000 seeds and retry action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final calls = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: PiTestForm(
          options: options(),
          record: record('TSW'),
          saveAction: (payload) async {
            calls.add(Map.from(payload));
            if (calls.length == 1) {
              throw Exception('Network acknowledgement lost');
            }
            return {...record('TSW'), 'row_version': 2};
          },
        ),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Nilai terukur (g per 1.000 benih)'),
      '150.25',
    );
    final save = find.widgetWithText(OutlinedButton, 'Simpan draft PI');
    await tester.scrollUntilVisible(
      save,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await reveal(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(calls.length, 1);
    expect(calls[0]['numeric_value'], 150.25);
    expect(calls[0]['seed_count'], 1000);
    expect(calls[0]['components'], isEmpty);
    expect(calls[0]['tested_at'], '2026-11-08T01:00:00.000Z');
    await tester.scrollUntilVisible(
      save,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await reveal(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(calls.length, 2);
    expect(calls[1]['action_id'], calls[0]['action_id']);
    expect(calls[1]['id'], calls[0]['id']);
    expect(tester.takeException(), isNull);
  });
  testWidgets('missing actual identity/time never calls server', (
    tester,
  ) async {
    var called = false;
    await tester.pumpWidget(
      MaterialApp(
        home: PiTestForm(
          options: options(),
          saveAction: (p) async {
            called = true;
            return record('PP');
          },
        ),
      ),
    );
    final save = find.widgetWithText(OutlinedButton, 'Simpan draft PI');
    await tester.scrollUntilVisible(
      save,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await reveal(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(called, isFalse);
    await tester.scrollUntilVisible(
      find.text('Pilih lot dan waktu pengukuran nyata.'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Pilih lot dan waktu pengukuran nyata.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('PP component fields say grams and preserve source measure', (
    tester,
  ) async {
    Map<String, dynamic>? sent;
    await tester.pumpWidget(
      MaterialApp(
        home: PiTestForm(
          options: options(),
          record: record('PP'),
          saveAction: (p) async {
            sent = p;
            return {...record('PP'), 'row_version': 2};
          },
        ),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Nilai terukur (%)'),
      '99.5',
    );
    final components = find.text('Komponen opsional · gram');
    await tester.scrollUntilVisible(
      components,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(components);
    await tester.pumpAndSettle();
    final pure = find.widgetWithText(TextField, 'Pure seed (g)');
    await tester.scrollUntilVisible(
      pure,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(pure, '99.5');
    final save = find.widgetWithText(OutlinedButton, 'Simpan draft PI');
    await tester.scrollUntilVisible(
      save,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(sent!['numeric_value'], 99.5);
    expect(sent!['components'], {'PURE_SEED_GRAM': 99.5});
    expect(sent!['seed_count'], isNull);
    expect(tester.takeException(), isNull);
  });
}
