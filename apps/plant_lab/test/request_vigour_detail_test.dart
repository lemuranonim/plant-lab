import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_lab/features/lab_request/presentation/request_germination_detail_screen.dart';

Map<String, dynamic> fixture({bool qa = false}) => {
  'version': 1,
  'run_id': 'memory-run',
  'run_code': 'LT-MEMORY',
  'request_id': 'memory-request',
  'lot_code': 'MEMORY-LOT',
  'sample_reference': 'MEMORY-SAMPLE',
  'lab_name': 'Memory Lab',
  'request_code': 'LR-MEMORY',
  'revision': qa ? 2 : 0,
  'status': qa ? 'IN_REVIEW' : 'IN_PROGRESS',
  'content': qa ? {...emptyRequestGerminationDetail(), 'temperature_text': null} : null,
  'method_code':'AAT_42C_72H_RH90',
  'treatment_started_at':'2026-11-18T00:00:00Z',
  'can_edit': !qa,
  'can_review': qa,
  'reviewer_name': null,
  'readiness': {
    'ready': qa,
    'blockers': qa ? [] : ['Lengkapi pengamatan nyata.'],
    'warnings': [],
  },
};

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'Vigor rich draft320px150percent $dark unknown vs zero, same revision retry',
      (t) async {
        t.view.physicalSize = const Size(320, 1100);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        var record = fixture();
        final writes = <Map<String, dynamic>>[];
        await t.pumpWidget(
          MaterialApp(
            theme: dark
                ? ThemeData.dark(useMaterial3: true)
                : ThemeData.light(useMaterial3: true),
            builder: (c, w) => MediaQuery(
              data: MediaQuery.of(
                c,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: w!,
            ),
            home: RequestGerminationDetailScreen(
              requestId: 'memory-request',
              runCode: 'LT-MEMORY',
              canApprove: true,
              vigour: true,
              command: (name, args) async {
                if (name == 'get_request_vigour_detail') {
                  return Map<String, dynamic>.from(
                    jsonDecode(jsonEncode(record)) as Map,
                  );
                }
                expect(name, 'save_request_vigour_detail');
                writes.add(Map.of(args));
                if (writes.length == 1) {
                  throw StateError('memory network failure');
                }
                record = {
                  ...record,
                  'revision': 1,
                  'content': args['p_content'],
                };
                return {'revision': 1};
              },
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.textContaining('MEMORY-LOT'), findsOneWidget);
        final target = find.byKey(const ValueKey('request-count-0-dead'));
        await t.scrollUntilVisible(
          target,
          350,
          scrollable: find.byType(Scrollable).first,
        );
        await t.enterText(target, '0');
        final save = find.widgetWithText(
          FilledButton,
          'Simpan rincian pengamatan',
        );
        await t.scrollUntilVisible(
          save,
          350,
          scrollable: find.byType(Scrollable).first,
        );
        await t.ensureVisible(save);
        await t.pumpAndSettle();
        await t.tap(save);
        await t.pumpAndSettle();
        expect(writes.length, 1);
        await t.ensureVisible(save);
        await t.tap(save);
        await t.pumpAndSettle();
        expect(writes.length, 2);
        expect(writes[0], writes[1]);
        final content = writes[1]['p_content'] as Map;
        expect(content['available_at'], isNull);
        expect(content['planted_at'], isNull);
        expect(content['final_at'], isNull);
        expect(content['analyst_name'], isNull);
        expect(content['observations'][0]['dead'], 0);
        expect(content['observations'][0]['fresh'], isNull);
        expect(content['observations'][0]['first_normal'], isNull);
        expect((content['observations'] as List).length, 2);
        expect(writes[0]['p_run_code'], 'LT-MEMORY');
        expect(writes[0]['p_expected_revision'], 0);
        await t.scrollUntilVisible(
          find.text('Kirim revisi ini ke QA'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          t
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Kirim revisi ini ke QA'),
              )
              .onPressed,
          isNull,
        );
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets('request invalid fractional count is not silently blanked', (
    t,
  ) async {
    var calls = 0;
    await t.pumpWidget(
      MaterialApp(
        home: RequestGerminationDetailScreen(
          requestId: 'memory-request',
          runCode: 'LT-MEMORY',
          canApprove: true,
              vigour: true,
          command: (name, args) async {
            if (name == 'get_request_vigour_detail') return fixture();
            calls++;
            return {};
          },
        ),
      ),
    );
    await t.pumpAndSettle();
    final target = find.byKey(const ValueKey('request-count-0-normal'));
    await t.scrollUntilVisible(
      target,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await t.enterText(target, '1.5');
    final save = find.widgetWithText(FilledButton, 'Simpan rincian pengamatan');
    await t.scrollUntilVisible(
      save,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(save);
    await t.pumpAndSettle();
    await t.tap(save);
    await t.pumpAndSettle();
    expect(calls, 0);
  });
  testWidgets(
    'independent QA needs actual name and confirmation; review retry stable',
    (t) async {
      var record = fixture(qa: true);
      final writes = <Map<String, dynamic>>[];
      await t.pumpWidget(
        MaterialApp(
          home: RequestGerminationDetailScreen(
            requestId: 'memory-request',
            runCode: 'LT-MEMORY',
            canApprove: true,
              vigour: true,
            command: (name, args) async {
              if (name == 'get_request_vigour_detail') return record;
              expect(name, 'review_request_vigour_detail');
              writes.add(Map.of(args));
              if (writes.length == 1) throw StateError('memory lost response');
              record = {
                ...record,
                'status': 'APPROVED',
                'can_review': false,
                'reviewer_name': args['p_reviewer_name'],
              };
              return {'status': 'APPROVED'};
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      final name = find.widgetWithText(TextField, 'Nama pemeriksa QA');
      await t.scrollUntilVisible(
        name,
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await t.enterText(name, 'Actual QA');
      await t.scrollUntilVisible(find.widgetWithText(TextField,'Catatan QA / alasan uji ulang'),200,scrollable:find.byType(Scrollable).first);
      await t.enterText(find.widgetWithText(TextField,'Catatan QA / alasan uji ulang'),'Checked actual counts and method');
      final save = find.widgetWithText(FilledButton, 'Simpan keputusan QA');
      await t.scrollUntilVisible(
        save,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await t.pumpAndSettle();
      expect(t.widget<FilledButton>(save).onPressed, isNull);
      await t.ensureVisible(find.byType(CheckboxListTile));
      await t.tap(find.byType(CheckboxListTile));
      await t.pumpAndSettle();
      await t.ensureVisible(save);
      await t.tap(save);
      await t.pumpAndSettle();
      expect(writes.length, 1);
      await t.scrollUntilVisible(save,200,scrollable:find.byType(Scrollable).first);
      await t.ensureVisible(save);
      await t.tap(save);
      await t.pumpAndSettle();
      expect(writes.length, 2);
      expect(writes[0], writes[1]);
      expect(writes[0]['p_reviewer_name'], 'Actual QA');
      expect(writes[0]['p_expected_revision'], 2);
      expect(writes[0]['p_decision'], 'APPROVE');
      expect(t.takeException(), isNull);
    },
  );
}
