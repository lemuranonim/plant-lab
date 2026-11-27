import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_lab/app/theme/lab_theme.dart';
import 'package:plant_lab/core/config/app_config.dart';
import 'package:plant_lab/features/lab_request/presentation/lab_workspace_widgets.dart';
import 'package:plant_lab/features/lab_request/presentation/lab_logbook_screen.dart';
import 'package:plant_lab/features/lab_request/presentation/lab_logbook_download.dart';

Map<String, dynamic> entry({dynamic result = 0, String state = 'DRAFT_MEAN'}) =>
    {
      'entry_kind': 'MC_DRAFT',
      'entry_id': '89000000-0000-4000-8000-000000000012',
      'lot_code': 'LONG-LOT-CODE-12345678901234567890',
      'hybrid': 'H59',
      'stage_code': 'DCS',
      'method_name': 'MC Lab',
      'method_code': 'MC_LAB',
      'status': 'DRAFT',
      'sample_reference': null,
      'request_code': null,
      'run_code': null,
      'recorded_at': '2026-11-01T17:00:00Z',
      'observed_at': null,
      'reviewed_at': null,
      'result_percent': result,
      'result_state': state,
      'revision': 1,
      'attempt_no': null,
    };
Map<String, dynamic> records({int offset = 0}) => {
  'selected_lab_site_id': 'memory-lab',
  'lab_sites': [
    {'id': 'memory-lab', 'site_name': 'Advanta Laboratory Pasuruan'},
  ],
  'method_options': [
    {'method_code': 'MC_LAB', 'method_name': 'MC Lab'},
  ],
  'entries': [entry()],
  'total': 51,
  'offset': offset,
  'limit': 50,
  'has_more': offset == 0,
  'summary': {
    'approved': 3,
    'draft': 45,
    'waiting_qa': 1,
    'retest': 1,
    'other': 1,
    'missing_observation_time': 45,
  },
  'as_of': '2026-11-15T10:00:00Z',
};

Future<void> reveal(WidgetTester tester, Finder target, double delta) async {
  await tester.scrollUntilVisible(
    target,
    delta,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(target), alignment: .5);
  await tester.pumpAndSettle();
}

void main() {
  test('one form target requires a recognized record and a saved revision', () {
    final mc = entry();
    expect(logbookFormTarget(mc)?.module, 'lab-moisture');
    final routine = {...mc, 'entry_kind': 'ROUTINE', 'method_code': 'SAND_25C'};
    expect(logbookFormTarget(routine)?.module, 'lab-routine');
    expect(
      logbookFormTarget({...routine, 'method_code': 'RET_16C_72H'})?.module,
      'lab-ret',
    );
    expect(logbookFormTarget({...routine, 'entry_kind': 'PLANT_RUN'}), isNull);
    expect(logbookFormTarget({...routine, 'revision': null}), isNull);
    expect(logbookFormTarget({...routine, 'entry_id': '../export'}), isNull);
  });

  testWidgets(
    'details keep the lot and use the exact form revision, not rekap',
    (tester) async {
      tester.view.physicalSize = const Size(390, 840);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      var serverRevision = 7;
      String? shared;
      final row = {
        ...entry(result: 94, state: 'QA_APPROVED'),
        'entry_kind': 'ROUTINE',
        'method_code': 'RET_16C_72H',
        'method_name': 'RET',
        'lot_code': 'DEMO-DCS-024',
        'revision': 7,
        'status': 'APPROVED',
        'run_code': 'LT-DEMO-024',
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: LabTheme.light,
          home: LabLogbookScreen(
            loadRecords: (_) async => {
              ...records(),
              'entries': [
                {...row, 'revision': serverRevision},
              ],
            },
            download: (_) async =>
                throw StateError('Rekap is a separate action'),
            downloadForm: (id, revision, format, {required module}) async {
              expect(id, row['entry_id']);
              expect(format, 'pdf');
              expect(module, 'lab-ret');
              if (++calls == 1) {
                expect(revision, 7);
                throw StateError(
                  'Revisi berubah. Muat ulang sebelum mengunduh.',
                );
              }
              expect(revision, 8);
              return Uint8List.fromList([37, 80, 68, 70, 45]);
            },
            shareForm: (_, name, format) async {
              shared = name;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Unduh form PDF'), findsNothing);
      final open = find.text('Buka rincian');
      await reveal(tester, open, 180);
      await tester.tap(open.hitTestable());
      await tester.pumpAndSettle();
      final pinned = find.descendant(
        of: find.byType(AppBar),
        matching: find.text('DEMO-DCS-024'),
      );
      expect(pinned.hitTestable(), findsOneWidget);
      expect(find.text('Unduh rekap Excel'), findsNothing);
      expect(
        find.text('Persetujuan analisis bukan pelepasan lot.'),
        findsOneWidget,
      );
      if (!AppConfig.hostedPilot) {
        expect(find.text('Unduh form PDF'), findsNothing);
        return;
      }
      final file = find.text('Unduh form PDF');
      await reveal(tester, file, 160);
      await tester.tap(file.hitTestable());
      await tester.pumpAndSettle();
      expect(
        find.text('Revisi berubah. Muat ulang sebelum mengunduh.'),
        findsOneWidget,
      );
      expect(shared, isNull);
      serverRevision = 8;
      await tester.pageBack();
      await tester.pumpAndSettle();
      final refresh = find.text('Muat ulang hasil');
      await reveal(tester, refresh, 180);
      await tester.tap(refresh.hitTestable());
      await tester.pumpAndSettle();
      await reveal(tester, open, -180);
      await tester.tap(open.hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('Form pengujian · revisi 8'), findsOneWidget);
      await reveal(tester, file, 160);
      await tester.tap(file.hitTestable());
      await tester.pumpAndSettle();
      expect(shared, 'Form-RET-${row['entry_id']}-r8.pdf');
      expect(calls, 2);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'logbook export URI is fixed Lab HTTPS and literal applied filters only',
    () {
      final f = emptyLogbookFilters()
        ..['p_lab_site_id'] = '89000000-0000-4000-8000-000000000001'
        ..['p_search'] = 'LABEL%_&'
        ..['p_date_basis'] = 'OBSERVED';
      final uri = logbookExportUri(f);
      expect(uri.host, 'lab.advantaindonesia.com');
      expect(uri.scheme, 'https');
      expect(uri.path, '/api/lab-logbook/export');
      expect(uri.queryParameters['search'], 'LABEL%_&');
      expect(uri.queryParameters['date_basis'], 'OBSERVED');
      expect(uri.queryParameters.containsKey('offset'), false);
      expect(
        () => logbookExportUri({...f, 'p_offset': 50}),
        throwsFormatException,
      );
      expect(
        () => logbookExportUri({...f, 'p_from': '2026-02-30'}),
        throwsFormatException,
      );
      expect(
        () => logbookExportUri({...f, 'p_lab_site_id': 'https://evil.invalid'}),
        throwsFormatException,
      );
    },
  );
  testWidgets(
    'logbook exports all applied filters and blocks pending filter changes',
    (tester) async {
      Map<String, dynamic>? downloaded;
      String? shared;
      await tester.pumpWidget(
        MaterialApp(
          home: LabLogbookScreen(
            loadRecords: (args) async => records(),
            download: (args) async {
              downloaded = Map.of(args);
              return LogbookExportFile(
                Uint8List.fromList([80, 75, 3, 4, 0]),
                'Rekap-Lab-20261116T010203Z.xlsx',
              );
            },
            share: (file) async {
              shared = file.name;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final export = find.text('Unduh rekap Excel');
      await reveal(tester, export, 250);
      await tester.tap(export.hitTestable());
      await tester.pumpAndSettle();
      expect(downloaded!['p_lab_site_id'], 'memory-lab');
      expect(downloaded!.containsKey('p_offset'), false);
      expect(shared, 'Rekap-Lab-20261116T010203Z.xlsx');
      await reveal(tester, find.byType(TextField), -250);
      await tester.enterText(find.byType(TextField), 'LABEL%_');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await reveal(tester, export, 250);
      final button = tester.widget<OutlinedButton>(
        find
            .ancestor(
              of: find.text('Unduh rekap Excel'),
              matching: find.byWidgetPredicate((w) => w is OutlinedButton),
            )
            .first,
      );
      expect(button.onPressed, isNull);
      final apply = find.text('Tampilkan catatan');
      await reveal(tester, apply, -200);
      await tester.tap(apply.hitTestable());
      await tester.pumpAndSettle();
      await reveal(tester, export, 250);
      await tester.tap(export.hitTestable());
      await tester.pumpAndSettle();
      expect(downloaded!['p_search'], 'LABEL%_');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('oversize logbook never offers a partial download', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LabLogbookScreen(
          loadRecords: (args) async => {...records(), 'total': 2001},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Unduh rekap Excel'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find
                .ancestor(
                  of: find.text('Unduh rekap Excel'),
                  matching: find.byWidgetPredicate((w) => w is OutlinedButton),
                )
                .first,
          )
          .onPressed,
      isNull,
    );
    final oversize = find.textContaining('Lebih dari 2000 catatan cocok');
    await reveal(tester, oversize, 200);
    expect(oversize.hitTestable(), findsOneWidget);
  });
  test('Actual WIB boundary, null is unknown and zero stays zero', () {
    expect(logbookWib('2026-11-01T17:00:00Z'), '2026-11-02 00:00 WIB');
    expect(logbookWib(null), 'Belum dicatat');
    expect(logbookResult(entry()), 'Rata-rata 3 pembacaan MC: 0%');
    expect(logbookResult(entry(result: null)), 'Angka hasil belum tersedia');
    expect(
      logbookResult(entry(result: 95, state: 'QA_APPROVED')),
      'Hasil analisis: 95%',
    );
  });
  testWidgets('advanced filters are optional and apply only on request', (
    tester,
  ) async {
    final calls = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: LabTheme.light,
        home: LabLogbookScreen(
          loadRecords: (args) async {
            calls.add(Map.of(args));
            return records();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Baca saja'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    await tester.tap(find.text('Filter lanjutan').hitTestable());
    await tester.pumpAndSettle();
    final status = find.text('Semua status');
    await reveal(tester, status, 150);
    await tester.tap(status.hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Menunggu QA').hitTestable().last);
    await tester.pumpAndSettle();
    expect(calls, hasLength(1));
    await reveal(tester, find.text('Filter lanjutan'), -150);
    await tester.tap(find.text('Filter lanjutan').hitTestable());
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Tampilkan catatan'), 150);
    await tester.tap(find.text('Tampilkan catatan').hitTestable());
    await tester.pumpAndSettle();
    expect(calls.last['p_status'], 'IN_REVIEW');
    expect(calls.last['p_offset'], 0);
    expect(tester.takeException(), isNull);
  });
  for (final dark in [false, true]) {
    testWidgets(
      'Logbook readonly320px150percent ${dark ? 'dark' : 'light'} filters retry page',
      (tester) async {
        tester.view.physicalSize = const Size(320, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final calls = <Map<String, dynamic>>[];
        bool fail = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? LabTheme.dark : LabTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: LabLogbookScreen(
              loadRecords: (args) async {
                calls.add(Map.of(args));
                if (fail) {
                  fail = false;
                  throw Exception('offline');
                }
                return records(offset: args['p_offset'] as int);
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(calls.single['p_limit'], 50);
        final scroll = find.byType(Scrollable).first;
        final next = find.text('Berikutnya');
        await reveal(tester, next, 250);
        await tester.tap(next.hitTestable());
        await tester.pumpAndSettle();
        expect(calls.last['p_offset'], 50);
        final summary = find.text('Ringkasan & cara baca');
        await reveal(tester, summary, -180);
        await tester.tap(summary.hitTestable());
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<LabRecordValue>(
                find.widgetWithText(LabRecordValue, 'Analisis disetujui QA'),
              )
              .value,
          '3',
        );
        await tester.scrollUntilVisible(
          find.text('Rata-rata 3 pembacaan MC: 0%'),
          180,
          scrollable: scroll,
        );
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.byType(TextField),
          -300,
          scrollable: scroll,
        );
        await tester.enterText(find.byType(TextField), 'LABEL%_');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        final apply = find.text('Tampilkan catatan');
        await reveal(tester, apply, 200);
        fail = true;
        await tester.tap(apply.hitTestable());
        await tester.pumpAndSettle();
        expect(calls.last['p_search'], 'LABEL%_');
        expect(calls.last['p_offset'], 0);
        expect(find.byType(LogbookEntryCard), findsNothing);
        final retry = find.text('Coba muat ulang');
        await reveal(tester, retry, 150);
        await tester.tap(retry.hitTestable());
        await tester.pumpAndSettle();
        expect(calls.last, calls[calls.length - 2]);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
