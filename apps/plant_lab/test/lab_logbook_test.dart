import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_lab/app/theme/app_theme.dart';
import 'package:plant_lab/features/lab_request/presentation/lab_logbook_screen.dart';
import 'package:plant_lab/features/lab_request/presentation/lab_logbook_download.dart';

Map<String, dynamic> entry({dynamic result = 0, String state = 'DRAFT_MEAN'}) =>
    {
      'entry_kind': 'MC_DRAFT',
      'lot_code': 'LONG-LOT-CODE-12345678901234567890',
      'hybrid': 'H59',
      'stage_code': 'DCS',
      'method_name': 'MC Lab',
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
void main() {
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
      await tester.scrollUntilVisible(
        find.text('Unduh rekap Excel'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Unduh rekap Excel'));
      await tester.pumpAndSettle();
      expect(downloaded!['p_lab_site_id'], 'memory-lab');
      expect(downloaded!.containsKey('p_offset'), false);
      expect(shared, 'Rekap-Lab-20261116T010203Z.xlsx');
      await tester.scrollUntilVisible(
        find.byType(TextField),
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byType(TextField), 'LABEL%_');
      await tester.scrollUntilVisible(
        find.text('Unduh rekap Excel'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      final button = tester.widget<OutlinedButton>(
        find
            .ancestor(
              of: find.text('Unduh rekap Excel'),
              matching: find.byWidgetPredicate((w) => w is OutlinedButton),
            )
            .first,
      );
      expect(button.onPressed, isNull);
      await tester.scrollUntilVisible(
        find.text('Tampilkan catatan'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Tampilkan catatan'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Unduh rekap Excel'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Unduh rekap Excel'));
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
    expect(
      find.textContaining('Lebih dari 2000 catatan cocok'),
      findsOneWidget,
    );
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
            theme: dark ? AppTheme.dark : AppTheme.light,
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
        await tester.scrollUntilVisible(
          find.text('Berikutnya'),
          250,
          scrollable: scroll,
        );
        await tester.ensureVisible(find.text('Berikutnya'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Berikutnya'));
        await tester.pumpAndSettle();
        expect(calls.last['p_offset'], 50);
        await tester.scrollUntilVisible(
          find.text('3 · Analisis disetujui QA'),
          -180,
          scrollable: scroll,
        );
        expect(find.text('3 · Analisis disetujui QA'), findsOneWidget);
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
        await tester.scrollUntilVisible(
          find.text('Tampilkan catatan'),
          200,
          scrollable: scroll,
        );
        fail = true;
        await tester.tap(find.text('Tampilkan catatan'));
        await tester.pumpAndSettle();
        expect(calls.last['p_search'], 'LABEL%_');
        expect(calls.last['p_offset'], 0);
        expect(find.byType(LogbookEntryCard), findsNothing);
        await tester.scrollUntilVisible(
          find.text('Coba muat ulang'),
          150,
          scrollable: scroll,
        );
        await tester.tap(find.text('Coba muat ulang'));
        await tester.pumpAndSettle();
        expect(calls.last, calls[calls.length - 2]);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
