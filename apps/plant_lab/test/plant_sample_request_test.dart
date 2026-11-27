import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_lab/features/lab_request/presentation/plant_sample_request_screen.dart';

Map<String, dynamic> samplePage(String status, {bool canWrite = true}) => {
  'version': 1,
  'selected_site_id': 'site-a',
  'can_write': canWrite,
  'sites': [
    {'id': 'site-a', 'site_name': 'Lokasi A'},
  ],
  'offset': 0,
  'total': 1,
  'limit': 30,
  'has_more': false,
  'rows': <Map<String, dynamic>>[
    {
      'id': 'request-1',
      'lot_code': 'LOT-MEMORY',
      'hybrid': 'H59',
      'plant_site': 'Plant A',
      'lab_site': 'Lab A',
      'status': status,
      'purpose': 'Sampel rutin',
      'requested_at': '2026-11-18T01:00:00Z',
      'sample_label': status == 'REQUESTED' ? null : 'FISIK-01',
    },
  ],
};

Future<void> show(WidgetTester t, Finder f, {double delta = 300}) async {
  if (f.evaluate().isEmpty) {
    await t.scrollUntilVisible(
      f,
      delta,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await t.ensureVisible(f);
  await t.pumpAndSettle();
}

Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);

Future<void> input(WidgetTester t, String name, String text) async {
  final f = field(name);
  await show(t, f);
  await t.enterText(f, text);
  await t.pumpAndSettle();
}

void main() {
  test('physical label feedback uses exact code and keeps blank distinct', () {
    expect(sampleLabelMatch('', 'FISIK-01'), SampleLabelMatch.empty);
    expect(sampleLabelMatch(' FISIK-01 ', 'FISIK-01'), SampleLabelMatch.match);
    expect(sampleLabelMatch('fisik-01', 'FISIK-01'), SampleLabelMatch.mismatch);
    expect(sampleLabelMatch('FISIK-01', null), SampleLabelMatch.mismatch);
  });

  testWidgets(
    'Lab quick filter keeps scope and shows the receipt as read only',
    (t) async {
      await t.binding.setSurfaceSize(const Size(375, 840));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final requests = <Map<String, dynamic>>[];
      await t.pumpWidget(
        MaterialApp(
          home: PlantSampleRequestScreen(
            module: 'LAB',
            writesEnabled: true,
            rpc: (name, params) async {
              expect(name, 'list_plant_sample_requests');
              requests.add(Map.of(params));
              final received = params['p_status'] == 'RECEIVED';
              final result = samplePage(
                received ? 'RECEIVED' : 'SENT',
                canWrite: false,
              );
              if (received) result['rows'][0]['received_grams'] = 9.75;
              return result;
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Minta sampel'), findsNothing);
      final button = find.byKey(const ValueKey('lab-sample-quick-RECEIVED'));
      await show(t, button);
      await t.tap(button.hitTestable());
      await t.pumpAndSettle();
      expect(requests.last['p_site_id'], 'site-a');
      expect(requests.last['p_offset'], 0);
      expect(requests.last['p_status'], 'RECEIVED');
      await show(t, button);
      expect(t.widget<ChoiceChip>(button).selected, true);
      await show(t, find.text('Label yang dicocokkan'));
      expect(find.text('9,75 g'), findsOneWidget);
      expect(find.text('Konfirmasi sampel diterima'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  test(
    'gram input supports decimal comma but not blank, invalid or milligram overflow',
    () {
      expect(plantSampleGrams(' 15,250 '), 15.25);
      expect(plantSampleGrams('10'), 10);
      for (final invalid in [
        '',
        '0',
        '-1',
        '1,0001',
        '1e3',
        'NaN',
        '1000000000',
      ]) {
        expect(plantSampleGrams(invalid), isNull);
      }
    },
  );
  testWidgets('Plant dispatch retains command when server reply is lost', (
    t,
  ) async {
    await t.binding.setSurfaceSize(const Size(360, 700));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final calls = <Map<String, dynamic>>[];
    var status = 'REQUESTED';
    await t.pumpWidget(
      MaterialApp(
        home: PlantSampleRequestScreen(
          module: 'PLANT',
          writesEnabled: true,
          rpc: (name, params) async {
            if (name == 'list_plant_sample_requests') return samplePage(status);
            expect(name, 'record_plant_sample_request');
            calls.add(Map.of(params));
            status = 'SENT';
            if (calls.length == 1) throw StateError('Simulated lost reply');
            return {'id': 'request-1', 'status': status};
          },
        ),
      ),
    );
    await t.pumpAndSettle();
    final send = find.widgetWithText(OutlinedButton, 'Catat sudah dikirim');
    await show(t, send);
    await t.tap(send);
    await t.pumpAndSettle();
    await input(t, 'Label pada sampel fisik', 'FISIK-01');
    await input(t, 'Berat aktual (gram)', '10,25');
    await input(t, 'Kondisi kemasan/sampel', 'Kemasan utuh');
    final confirmed = find.byType(CheckboxListTile);
    await show(t, confirmed);
    await t.tap(confirmed);
    await t.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Catat sudah dikirim');
    await show(t, save);
    await t.tap(save);
    await t.pumpAndSettle();
    final retry = find.widgetWithText(FilledButton, 'Coba kirim ulang');
    await show(t, retry);
    await t.tap(retry);
    await t.pumpAndSettle();
    expect(calls, hasLength(2));
    expect(calls[0], calls[1]);
    expect(calls[0]['p_grams'], 10.25);
    expect(calls[0]['p_sample_label'], 'FISIK-01');
    expect(calls[0]['p_action'], 'SEND');
    expect(find.text('Catatan tersimpan.'), findsOneWidget);
  });

  testWidgets(
    'Lab cannot confirm mismatched physical label; QA sees no actions',
    (t) async {
      await t.binding.setSurfaceSize(const Size(360, 760));
      addTearDown(() => t.binding.setSurfaceSize(null));
      var qa = false;
      final calls = <Map<String, dynamic>>[];
      Future<Map<String, dynamic>> rpc(
        String name,
        Map<String, dynamic> params,
      ) async {
        if (name == 'list_plant_sample_requests') {
          return samplePage('SENT', canWrite: !qa);
        }
        calls.add(Map.of(params));
        return {'id': 'request-1'};
      }

      await t.pumpWidget(
        MaterialApp(
          home: PlantSampleRequestScreen(
            module: 'LAB',
            writesEnabled: true,
            rpc: rpc,
          ),
        ),
      );
      await t.pumpAndSettle();
      final receive = find.widgetWithText(
        OutlinedButton,
        'Konfirmasi sampel diterima',
      );
      await show(t, receive);
      await t.tap(receive);
      await t.pumpAndSettle();
      await input(t, 'Label pada sampel fisik', 'SALAH');
      expect(
        find.text('Label berbeda. Jangan konfirmasi; hubungi Plant.'),
        findsOneWidget,
      );
      await input(t, 'Berat aktual (gram)', '10');
      await input(t, 'Kondisi kemasan/sampel', 'Utuh');
      final confirmed = find.byType(CheckboxListTile);
      await show(t, confirmed);
      await t.tap(confirmed);
      await t.pumpAndSettle();
      final save = find.widgetWithText(
        FilledButton,
        'Konfirmasi sampel diterima',
      );
      await show(t, save);
      await t.tap(save);
      await t.pumpAndSettle();
      expect(calls, isEmpty);
      expect(
        find.textContaining('Label penerimaan harus sama'),
        findsOneWidget,
      );
      await input(t, 'Label pada sampel fisik', 'FISIK-01');
      expect(find.text('Label cocok dengan kiriman.'), findsOneWidget);
      expect(find.textContaining('Label penerimaan harus sama'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('LOT-MEMORY'),
        ),
        findsOneWidget,
      );
      await show(t, save);
      await t.tap(save.hitTestable());
      await t.pumpAndSettle();
      expect(calls.single['p_action'], 'RECEIVE');
      expect(calls.single['p_sample_label'], 'FISIK-01');
      expect(calls.single['p_grams'], 10);
      qa = true;
      await t.pumpWidget(
        MaterialApp(
          home: PlantSampleRequestScreen(
            key: const ValueKey('qa'),
            module: 'LAB',
            writesEnabled: true,
            rpc: rpc,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Minta sampel'), findsNothing);
      expect(receive, findsNothing);
    },
  );
}
