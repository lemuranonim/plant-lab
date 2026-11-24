import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_lab/app/theme/app_theme.dart';
import 'package:plant_lab/features/lab_request/presentation/routine_form_details.dart';
import 'package:plant_lab/features/lab_request/presentation/routine_form_download.dart';

void main() {
  const id = '82000000-0000-4000-8000-000000000041';
  for (final germination in [true, false]) {
    testWidgets(
      'form details 320px150percent ${germination ? 'Germinasi' : 'Vigor'}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var value = emptyRoutineForm(
          germination ? 'SAND_25C' : 'COLD_TEST_5C_24H',
          4,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => ListView(
                  children: [
                    RoutineFormDetailsFields(
                      value: value,
                      enabled: true,
                      germination: germination,
                      retest: false,
                      onChanged: (next) => setState(() => value = next),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.tap(
          find.text('Rincian form ${germination ? 'Germinasi' : 'Vigor'}'),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('routine-form-crop_species')),
        );
        await tester.enterText(
          find.byKey(const ValueKey('routine-form-crop_species')),
          'Jagung',
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('routine-form-analyst_name')),
        );
        await tester.enterText(
          find.byKey(const ValueKey('routine-form-analyst_name')),
          'Petugas sebenarnya',
        );
        await tester.pumpAndSettle();
        expect(value['crop_species'], 'Jagung');
        expect(value['analyst_name'], 'Petugas sebenarnya');
        expect(value['planted_at'], isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
  test('form metadata is blank and row-specific; Germ protocol fixed', () {
    final germ = emptyRoutineForm('SAND_25C', 8);
    expect(germ['temperature_text'], '25');
    expect(germ['analyst_name'], isNull);
    expect((germ['annotations'] as List).length, 8);
    expect(emptyRoutineForm('COLD_TEST_5C_24H', 4)['temperature_text'], isNull);
  });
  test(
    'download targets only own HTTPS host, saved revision and supported files',
    () {
      final uri = routineFormUri(id, 3, 'pdf');
      expect(uri.origin, 'https://lab.advantaindonesia.com');
      expect(uri.queryParameters, {'format': 'pdf', 'revision': '3'});
      for (final tuple in [
        ('https://evil.invalid', 3, 'pdf'),
        (id, 0, 'pdf'),
        (id, 1, 'html'),
      ]) {
        expect(
          () => routineFormUri(tuple.$1, tuple.$2, tuple.$3),
          throwsFormatException,
        );
      }
      expect(
        () => validateRoutineFormBytes(
          Uint8List.fromList('%PDF-1.7'.codeUnits),
          'pdf',
          'application/pdf',
        ),
        returnsNormally,
      );
      expect(
        () => validateRoutineFormBytes(
          Uint8List.fromList('<html>login</html>'.codeUnits),
          'pdf',
          'text/html',
        ),
        throwsFormatException,
      );
      expect(
        () => validateRoutineFormBytes(
          Uint8List.fromList('%PDF-1.7'.codeUnits),
          'xlsx',
          'application/pdf',
        ),
        throwsFormatException,
      );
    },
  );
  testWidgets('downloads are per-form and user chooses a destination', (
    tester,
  ) async {
    String? name;
    int loads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoutineFormDownload(
            record: {'id': id, 'revision': 3, 'method_code': 'SAND_25C'},
            load: (i, r, f) async {
              expect((i, r, f), (id, 3, 'pdf'));
              loads++;
              return Uint8List.fromList('%PDF-1.7'.codeUnits);
            },
            share: (b, n, f) async {
              name = n;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Unduh form PDF'));
    await tester.pumpAndSettle();
    expect(loads, 1);
    expect(name, 'Form-Germinasi-$id-r3.pdf');
  });
  test('TSW uses the current variant host and saved source version', () {
    for (final plant in [true, false]) {
      final uri = routineFormUri(
        id,
        4,
        'xlsx',
        module: 'pi-quality',
        plant: plant,
      );
      expect(
        uri.host,
        plant ? 'plant.advantaindonesia.com' : 'lab.advantaindonesia.com',
      );
      expect(uri.path, '/api/pi-quality/$id/export');
      expect(uri.queryParameters, {'format': 'xlsx', 'revision': '4'});
    }
    expect(
      () => routineFormUri(id, 4, 'pdf', plant: true),
      throwsFormatException,
    );
    expect(
      () => routineFormUri(id, 4, 'pdf', module: 'https://evil.invalid'),
      throwsFormatException,
    );
    expect(
      () => routineFormUri(id, 1000000000, 'pdf', module: 'pi-quality'),
      throwsFormatException,
    );
  });
  test('RET download stays on Lab HTTPS host and cannot be sent to Plant', () {
    final uri = routineFormUri(id, 2, 'pdf', module: 'lab-ret');
    expect(uri.host, 'lab.advantaindonesia.com');
    expect(uri.path, '/api/lab-ret/$id/export');
    expect(uri.queryParameters, {'format': 'pdf', 'revision': '2'});
    expect(
      () => routineFormUri(id, 2, 'pdf', module: 'lab-ret', plant: true),
      throwsFormatException,
    );
  });
  testWidgets('RET is downloaded as its own named form, not Vigor', (
    tester,
  ) async {
    String? name;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoutineFormDownload(
            record: {'id': id, 'revision': 2, 'method_code': 'RET_16C_72H'},
            formName: 'RET',
            load: (i, r, f) async {
              expect((i, r, f), (id, 2, 'pdf'));
              return Uint8List.fromList('%PDF-1.7'.codeUnits);
            },
            share: (b, n, f) async {
              name = n;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Unduh form PDF'));
    await tester.pumpAndSettle();
    expect(name, 'Form-RET-$id-r2.pdf');
  });
  testWidgets('TSW filename keeps source version distinct from raw revision', (
    tester,
  ) async {
    String? name;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoutineFormDownload(
            record: {'id': id, 'revision': 4},
            formName: 'TSW-PI',
            versionPrefix: 'v',
            title: 'Unduh form TSW PI',
            description: 'Versi sumber tersimpan, bukan approval Lab.',
            load: (i, r, f) async {
              expect((i, r, f), (id, 4, 'xlsx'));
              return Uint8List.fromList([80, 75, 3, 4, 0]);
            },
            share: (b, n, f) async {
              name = n;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Unduh form Excel'));
    await tester.pumpAndSettle();
    expect(name, 'Form-TSW-PI-$id-v4.xlsx');
    expect(find.text('Unduh form TSW PI'), findsOneWidget);
  });
  testWidgets('stale revision does not share a file', (tester) async {
    bool shared = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoutineFormDownload(
            record: {'id': id, 'revision': 1, 'method_code': 'SAND_25C'},
            load: (_, _, _) async => throw StateError(
              'Revisi berubah. Muat ulang sebelum mengunduh.',
            ),
            share: (_, _, _) async {
              shared = true;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Unduh form PDF'));
    await tester.pumpAndSettle();
    expect(shared, isFalse);
    expect(find.textContaining('Revisi berubah'), findsOneWidget);
  });
}
