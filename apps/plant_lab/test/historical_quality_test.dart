import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_lab/app/theme/lab_theme.dart';
import 'package:plant_lab/features/lab_request/presentation/historical_quality_screen.dart';

Map<String, dynamic> history({String lot = 'DEMO-RR-0002', int total = 1}) => {
  'lot_code': lot,
  'history_status': 'SOURCE_HISTORY_NOT_APP_APPROVED',
  'total_records': total,
  'records': total == 0
      ? []
      : [
          {
            'id': lot,
            'source_type': 'GERMINATION_VIGOR_2026',
            'source_file_name': 'Source.xlsx',
            'sheet': 'Detail SWC',
            'source_row': 20,
            'mapping_version': 1,
            'phases': [
              {
                'key': 'first',
                'kind': 'FIRST_COUNT',
                'label': 'GERMINATION FIRST COUNT',
                'source_method_label': null,
                'source_stage': null,
                'source_planted_date': null,
                'source_observation_date': '2026-10-01',
                'source_observation_origin': 'FORMULA_CACHE',
                'source_percent': 0,
                'diagnostic_percent': null,
                'source_conclusion': 'ACCEPTED',
                'review_codes': ['FIRST_COUNT_NO_MISSING_COUNTS_IMPUTED'],
                'subunits': [
                  {
                    'label': '1A',
                    'source_row': 20,
                    'normal': 0,
                    'abnormal': null,
                    'dead': null,
                    'total': null,
                  },
                ],
                'values': [
                  {
                    'coordinate': 'H20',
                    'header': 'Normal',
                    'number': 0,
                    'source_value': 0,
                    'unit': 'SEED',
                    'origin': 'LITERAL',
                  },
                ],
              },
            ],
          },
        ],
};

final options = {
  'lots': [
    {'id': 'one', 'lot_code': 'DEMO-R-0002'},
    {'id': 'two', 'lot_code': 'DEMO-RR-0002'},
  ],
};

Future<void> choose(WidgetTester tester, String code) async {
  final dropdown = find.byType(DropdownButtonFormField<String>);
  await Scrollable.ensureVisible(tester.element(dropdown), alignment: .5);
  await tester.pumpAndSettle();
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(code).last);
  await tester.pumpAndSettle();
}

Future<void> showHistory(WidgetTester tester) async {
  final show = find.text('Tampilkan histori');
  await Scrollable.ensureVisible(tester.element(show), alignment: .5);
  await tester.pumpAndSettle();
  await tester.tap(show.hitTestable());
}

void main() {
  test('raw false, zero and missing stay distinct', () {
    expect(historyValue(0), '0');
    expect(historyValue(false), 'false');
    expect(historyValue(null), 'Belum dicatat');
  });
  testWidgets(
    'source approval, missing counts and computed date are explicit',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HistoricalQualityContent(data: history()),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Germinasi / Vigor'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Pengamatan awal'));
      await tester.pumpAndSettle();
      expect(find.text('Persentase sumber: 0%'), findsOneWidget);
      expect(
        find.textContaining('ACCEPTED · bukan approval QA aplikasi'),
        findsOneWidget,
      );
      expect(
        find.textContaining('hasil rumus sumber, bukan bukti aktual'),
        findsOneWidget,
      );
      expect(find.text('—'), findsNWidgets(3));
      expect(find.text('APPROVED'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'lot selection preserves RR; empty response is not failed result',
    (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: HistoricalQualityScreen(
            module: 'PLANT',
            options: Future.value(options),
            loader: (id, module, offset) async {
              calls.add('$id/$module/$offset');
              return history(total: 0);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await choose(tester, 'DEMO-RR-0002');
      await tester.ensureVisible(find.text('Tampilkan histori'));
      await tester.tap(find.text('Tampilkan histori'));
      await tester.pumpAndSettle();
      expect(calls, ['two/PLANT/0']);
      expect(
        find.textContaining('bukan hasil nol atau gagal uji'),
        findsOneWidget,
      );
      expect(find.byType(DataTable), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Lab archive shows source counts without horizontal scrolling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: LabTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: HistoricalQualityContent(data: history(), labStyle: true),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Germinasi / Vigor').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Pengamatan awal').hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(DataTable), findsNothing);
    expect(find.text('1A · Baris 20'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(3));
    expect(
      find.textContaining('ACCEPTED · bukan approval QA aplikasi'),
      findsOneWidget,
    );
    final cells = find.text('Nilai sumber & posisi sel (1)');
    await tester.ensureVisible(cells);
    await tester.tap(cells.hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('H20 · Normal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('denied and error responses do not retain old lot content', (
    tester,
  ) async {
    var attempt = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HistoricalQualityScreen(
          module: 'LAB',
          options: Future.value(options),
          loader: (_, _, _) async {
            attempt++;
            if (attempt == 1) return history();
            if (attempt == 2) return null;
            throw StateError('Network');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await choose(tester, 'DEMO-RR-0002');
    await showHistory(tester);
    await tester.pumpAndSettle();
    expect(find.text('Histori lot DEMO-RR-0002'), findsOneWidget);
    await choose(tester, 'DEMO-R-0002');
    expect(find.text('Histori lot DEMO-RR-0002'), findsNothing);
    await showHistory(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('tidak tersedia dalam cakupan'), findsOneWidget);
    await showHistory(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('Tidak menggunakan data lama'), findsOneWidget);
    expect(find.text('Histori lot DEMO-RR-0002'), findsNothing);
  });
  testWidgets('late response cannot replace newly selected lot', (
    tester,
  ) async {
    final pending = Completer<Map<String, dynamic>?>();
    await tester.pumpWidget(
      MaterialApp(
        home: HistoricalQualityScreen(
          module: 'PLANT',
          options: Future.value(options),
          loader: (_, _, _) => pending.future,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await choose(tester, 'DEMO-RR-0002');
    await tester.ensureVisible(find.text('Tampilkan histori'));
    await tester.tap(find.text('Tampilkan histori'));
    await tester.pump();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('DEMO-R-0002').last);
    await tester.pump();
    pending.complete(history());
    await tester.pumpAndSettle();
    expect(find.text('Histori lot DEMO-RR-0002'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'pagination requests offset, without appending duplicated records',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1300));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final offsets = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: HistoricalQualityScreen(
            module: 'PLANT',
            options: Future.value(options),
            loader: (_, _, offset) async {
              offsets.add(offset);
              return history(total: 5);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await choose(tester, 'DEMO-RR-0002');
      await tester.tap(find.text('Tampilkan histori'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Berikutnya'));
      await tester.tap(find.text('Berikutnya'));
      await tester.pumpAndSettle();
      expect(offsets, [0, 3]);
      expect(find.text('Germinasi / Vigor'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
