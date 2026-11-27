import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_lab/app/theme/app_theme.dart';
import 'package:plant_lab/features/lab_request/presentation/moisture_lab_screen.dart';
import 'package:plant_lab/features/lab_request/presentation/routine_form_download.dart';

void main() {
  test('MC three readings preserve unknown/zero and never scale1to100', () {
    expect(moistureMean([0, null, 0]), isNull);
    expect(moistureMean([0, 0, 0]), 0);
    expect(moistureMean([1, 1, 1]), 1);
    expect(moistureMean([11.2, 11.3, 11.3]), closeTo(11.2666666666667, 1e-10));
    expect(moistureMean([101, 11, 11]), isNull);
    expect(moistureMean([double.nan, 11, 11]), isNull);
    expect(moistureNumber(0), '0');
    expect(moistureNumber(100), '100');
    expect(
      routineFormUri(
        '83000000-0000-4000-8000-000000000041',
        1,
        'pdf',
        module: 'lab-moisture',
      ).path,
      contains('/lab-moisture/'),
    );
    expect(
      () => routineFormUri(
        '83000000-0000-4000-8000-000000000041',
        1,
        'pdf',
        module: 'https://other.invalid',
      ),
      throwsFormatException,
    );
  });
  for (final dark in [false, true]) {
    testWidgets(
      'MC editor320px150percent ${dark ? 'dark' : 'light'} retry and blank',
      (tester) async {
        tester.view.physicalSize = const Size(320, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final calls = <Map<String, dynamic>>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark : AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: MoistureDraftEditor(
              record: {
                'id': 'memory-mc',
                'revision': 0,
                'lot_id': 'memory-lot',
                'lot_code': 'MEMORY-ONLY',
                'hybrid': 'H59',
                'stage_code': 'DCS',
                'content': emptyMoistureContent(),
              },
              labSiteId: 'memory-lab',
              loadReferences: (_, _) async => {
                'references': [],
                'total': 0,
                'offset': 0,
                'has_more': false,
              },
              saveDraft: (args) async {
                calls.add(args);
                if (calls.length == 1) throw Exception('offline fixture');
                return {'revision': 1};
              },
            ),
          ),
        );
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('mc-reading-0')),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(find.byKey(const ValueKey('mc-reading-0')), '0');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(find.text('Pratinjau rata-rata · 1/3 terisi'), findsOneWidget);
        expect(find.text('Belum lengkap'), findsOneWidget);
        final save = find.text('Simpan draft MC Lab');
        await tester.ensureVisible(save);
        await tester.tap(save.hitTestable());
        await tester.pumpAndSettle();
        expect(calls.length, 1);
        await tester.ensureVisible(save);
        await tester.tap(save.hitTestable());
        await tester.pumpAndSettle();
        expect(calls.length, 2);
        expect(calls[0], calls[1]);
        final content = calls.last['p_content'] as Map;
        expect(content['readings'], [0, null, null]);
        expect(content['received_at'], isNull);
        expect(content['measured_at'], isNull);
        expect(content['instrument'], isNull);
        expect(find.textContaining('MC Lab tersimpan'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'MC preview is complete at three valid readings and keeps lot pinned',
    (tester) async {
      tester.view.physicalSize = const Size(390, 830);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MoistureDraftEditor(
            record: {
              'id': 'memory',
              'revision': 0,
              'lot_id': 'memory-lot',
              'lot_code': 'DEMO-DCS-024',
              'hybrid': 'H59',
              'stage_code': 'DCS',
              'content': emptyMoistureContent(),
            },
            labSiteId: 'memory-lab',
            loadReferences: (_, _) async => {},
            saveDraft: (_) async =>
                throw StateError('Preview must not save or submit'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final header = find.descendant(
        of: find.byType(AppBar),
        matching: find.text('DEMO-DCS-024'),
      );
      final save = find.byKey(const ValueKey('mc-save-draft'));
      expect(save.hitTestable(), findsOneWidget);
      final top = tester.getTopLeft(header);
      await tester.tap(find.text('Pembacaan'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        final field = find.byKey(ValueKey('mc-reading-$i'));
        await tester.ensureVisible(field);
        await tester.enterText(field, const ['0', '11,2', '12,2'][i]);
        await tester.pumpAndSettle();
      }
      expect(find.text('Pratinjau rata-rata · 3/3 terisi'), findsOneWidget);
      expect(find.text('7,8%'), findsOneWidget);
      expect(tester.getTopLeft(header), top);
      expect(save.hitTestable(), findsOneWidget);
      final last = find.byKey(const ValueKey('mc-reading-2'));
      await tester.enterText(last, '');
      await tester.pumpAndSettle();
      expect(find.text('Pratinjau rata-rata · 2/3 terisi'), findsOneWidget);
      expect(find.text('7,8%'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('invalid MC cannot be saved as unknown', (tester) async {
    int calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MoistureDraftEditor(
          record: {
            'id': 'memory',
            'revision': 0,
            'lot_id': 'memory',
            'lot_code': 'MEMORY',
            'hybrid': 'H59',
            'stage_code': 'DCS',
            'content': emptyMoistureContent(),
          },
          labSiteId: 'memory',
          loadReferences: (_, _) async => {},
          saveDraft: (_) async {
            calls++;
            return {'revision': 1};
          },
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('mc-reading-0')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byKey(const ValueKey('mc-reading-0')), '101');
    await tester.ensureVisible(find.text('Simpan draft MC Lab'));
    await tester.tap(find.text('Simpan draft MC Lab'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.textContaining('Isi MC'), findsOneWidget);
  });
}
