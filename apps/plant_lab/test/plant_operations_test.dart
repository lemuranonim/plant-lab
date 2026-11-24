import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_lab/features/plant_inspection/presentation/plant_operations_screen.dart';
import 'package:plant_lab/features/lab_request/presentation/provisional_quality_reference.dart';

void main() {
  test('operation payload preserves zero and strips UI-only line keys', () {
    final payload = operationPayload(id: 'same-retry-id', siteId: 'site-a', productId: 7,
      processCode: 'PACKING', startedAt: DateTime.parse('2026-11-08T08:00:00+07:00'),
      values: {'mc_percent': 0, 'remark': 'Original input'},
      materials: [{'_key': 'ui-only', 'line_no': 9, 'direction': 'REJECT', 'quantity_kg': 0}],
      consumptions: [{'_key': 'ui-only', 'material_name': 'Pouch', 'unit_code': 'PIECE', 'quantity': 0}],
    );
    expect(payload['id'], 'same-retry-id');
    expect(payload['started_at'], '2026-11-08T01:00:00.000Z');
    expect(payload['expected_version'], 0);
    expect(payload['submit'], false);
    expect(payload['values']['mc_percent'], 0);
    expect(payload['materials'], [{'direction': 'REJECT', 'quantity_kg': 0}]);
    expect(payload['consumptions'][0].containsKey('_key'), false);
    expect(payload.containsKey('approved_by'), false);
  });
  test('v2 business confirmation is separate from formal validation', () {
    final rules = [for (final crop in ['FC', 'SWC']) for (final test in ['GERMINATION', 'VIGOUR'])
      {'crop_category_code': crop, 'test_code': test, 'minimum_percent': test == 'GERMINATION' ? 90 : 80,
        'version': 2, 'validation_status': 'PENDING_RESKI', 'business_confirmation_status': 'USER_CONFIRMED'}];
    expect(validQualityReferences(rules), true);
    expect(qualityReferenceConfirmation(rules.first), 'Angka dikonfirmasi tim');
    expect(validQualityReferences([rules.first, rules.first, rules.first, rules.first]), false);
    expect(validQualityReferences([null]), false);
    expect(qualityReferenceConfirmation({'validation_status': 'PENDING_RESKI', 'version': 1}), 'Menunggu validasi Reski');
  });
  testWidgets('narrow input form has explicit actual times and does not silently submit', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: PlantOperationForm(options: {
      'sites': [{'id': 'site-a', 'site_name': 'PRASAD', 'can_write': true}],
      'products': [{'id': 7, 'name': 'H59'}], 'lots': <Map<String, dynamic>>[],
      'forms': [{'process_code': 'RECEIVING', 'title': 'Receiving', 'version': 1, 'fields': <Map<String, dynamic>>[]}],
    })));
    expect(find.text('Mulai nyata *'), findsOneWidget);
    expect(find.text('Belum diisi'), findsNWidgets(2));
    await tester.scrollUntilVisible(find.text('Simpan draft'), 350,
      scrollable: find.descendant(of: find.byType(ListView).first, matching: find.byType(Scrollable)).first);
    await tester.tap(find.text('Simpan draft'));
    await tester.pump();
    expect(find.textContaining('Lengkapi site, produk'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
