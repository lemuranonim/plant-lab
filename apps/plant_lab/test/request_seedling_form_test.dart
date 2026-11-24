import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_lab/app/theme/app_theme.dart';
import 'package:plant_lab/features/lab_request/presentation/request_seedling_form_download.dart';
import 'package:plant_lab/features/lab_request/presentation/germination_request_forms.dart';
import 'package:plant_lab/features/lab_request/presentation/standalone_vigour.dart';

void main() {
  test('Seedling source URI is fixed HTTPS, exact run/status, no revision', () {
    final u = requestSeedlingUri('LT-ENGINEERINGONLY', 'RETEST', 'xlsx');
    expect(u.scheme, 'https');
    expect(u.host, 'lab.advantaindonesia.com');
    expect(u.path, '/api/lab-request-form/LT-ENGINEERINGONLY/export');
    expect(u.queryParameters, {'format': 'xlsx', 'status': 'RETEST'});
    for (final args in [
      ['https://evil.invalid', 'APPROVED', 'pdf'],
      ['LT-TEST/../', 'APPROVED', 'pdf'],
      ['LT-TEST', 'DRAFT', 'pdf'],
      ['LT-TEST', 'APPROVED', 'html'],
    ]) {
      expect(
        () => requestSeedlingUri(args[0], args[1], args[2]),
        throwsFormatException,
      );
    }
  });
  for (final dark in [false, true]) {
    for (final kind in ['Germinasi', 'Vigor']) {
      testWidgets(
        '$kind download at 320px150percent $dark retries without losing source',
        (t) async {
          t.view.physicalSize = const Size(320, 1100);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          var loads = 0;
          String? shared;
          final calls = <List<String>>[];
          await t.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.dark : AppTheme.light,
              builder: (c, w) => MediaQuery(
                data: MediaQuery.of(
                  c,
                ).copyWith(textScaler: const TextScaler.linear(1.5)),
                child: w!,
              ),
              home: Scaffold(
                body: ListView(
                  children: [
                    RequestSeedlingFormDownload(
                      runCode: 'LT-ENGINEERINGONLY',
                      status: 'RETEST',
                      kind: kind,
                      load: (code, status, format) async {
                        calls.add([code, status, format]);
                        if (++loads == 1) {
                          throw StateError('Koneksi terputus. Coba lagi.');
                        }
                        return RequestSeedlingFile(
                          Uint8List.fromList([37, 80, 68, 70, 45]),
                          'Form-$kind-Request-99000000-0000-4000-8000-000000000051-RETEST.$format',
                        );
                      },
                      share: (bytes, name, format) async {
                        shared = name;
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          await t.tap(find.text('Unduh $kind PDF'));
          await t.pumpAndSettle();
          expect(find.text('Koneksi terputus. Coba lagi.'), findsOneWidget);
          expect(shared, isNull);
          await t.tap(find.text('Unduh $kind PDF'));
          await t.pumpAndSettle();
          expect(shared, startsWith('Form-$kind-Request-'));
          expect(shared, endsWith('-RETEST.pdf'));
          await t.tap(find.text('Unduh $kind Excel'));
          await t.pumpAndSettle();
          expect(shared, endsWith('-RETEST.xlsx'));
          expect(calls.last, ['LT-ENGINEERINGONLY', 'RETEST', 'xlsx']);
          expect(t.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('Mismatched type is never shared', (t) async {
    var shared = false;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RequestSeedlingFormDownload(
            runCode: 'LT-ONLY',
            status: 'APPROVED',
            kind: 'Germinasi',
            load: (c, s, f) async => RequestSeedlingFile(
              Uint8List(5),
              'Form-Vigor-Request-99000000-0000-4000-8000-000000000051-APPROVED.pdf',
            ),
            share: (b, n, f) async {
              shared = true;
            },
          ),
        ),
      ),
    );
    await t.tap(find.text('Unduh Germinasi PDF'));
    await t.pumpAndSettle();
    expect(shared, isFalse);
    expect(find.textContaining('tidak sesuai'), findsOneWidget);
  });
  testWidgets(
    'Germination history failure is not empty, retries, current excluded',
    (t) async {
      const q = '99000000-0000-4000-8000-000000000031';
      var loads = 0;
      final calls = <String>[];
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                GerminationRequestForms(
                  requestId: q,
                  runCode: 'LT-CURRENT',
                  status: 'APPROVED',
                  loadRuns: (id) async {
                    expect(id, q);
                    if (++loads == 1) throw StateError('offline');
                    return {
                      'request_id': q,
                      'read_only': true,
                      'total': 2,
                      'runs': [
                        {
                          'run_code': 'LT-CURRENT',
                          'status': 'APPROVED',
                          'attempt_no': 2,
                        },
                        {
                          'run_code': 'LT-OLD',
                          'status': 'RETEST',
                          'attempt_no': 1,
                        },
                      ],
                    };
                  },
                  download: (c, s, f) async {
                    calls.add('$c/$s');
                    return RequestSeedlingFile(
                      Uint8List(5),
                      'Form-Germinasi-Request-99000000-0000-4000-8000-000000000051-$s.$f',
                    );
                  },
                  share: (b, n, f) async {},
                ),
              ],
            ),
          ),
        ),
      );
      await t.tap(find.text('Cetakan percobaan Germinasi lainnya'));
      await t.pumpAndSettle();
      await t.tap(find.text('Muat riwayat percobaan'));
      await t.pumpAndSettle();
      expect(find.textContaining('Riwayat belum dimuat'), findsOneWidget);
      expect(
        find.text('Tidak ada percobaan lain dalam permintaan ini.'),
        findsNothing,
      );
      await t.tap(find.text('Muat riwayat percobaan'));
      await t.pumpAndSettle();
      expect(find.byType(RequestSeedlingFormDownload), findsNWidgets(2));
      await t.ensureVisible(find.text('Unduh Germinasi PDF').last);
      await t.tap(find.text('Unduh Germinasi PDF').last);
      await t.pumpAndSettle();
      expect(calls, ['LT-OLD/RETEST']);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Ordinary Vigour current/prior forms stay separate and hidden on Plant',
    (t) async {
      final run = {
        'method_code': 'COLD_TEST_5C_24H',
        'method_name': 'Cold Test',
        'run_code': 'LT-CURRENT',
        'run_id': 'current',
        'status': 'IN_PROGRESS',
        'item_status': 'TESTING',
        'attempt_no': 2,
        'prior_attempts': [
          {'run_code': 'LT-OLD', 'status': 'RETEST', 'attempt_no': 1},
        ],
      };
      Future<void> show(bool lab) async {
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView(
                children: [
                  StandaloneVigour(
                    run: run,
                    requestStatus: 'TESTING',
                    analyst: lab,
                    reviewer: false,
                    onSaved: () {},
                  ),
                ],
              ),
            ),
          ),
        );
        await t.tap(find.text('Vigor · Cold Test'));
        await t.pumpAndSettle();
      }

      await show(true);
      expect(find.byType(RequestSeedlingFormDownload), findsOneWidget);
      await t.tap(find.text('Riwayat percobaan sebelumnya (1)'));
      await t.pumpAndSettle();
      expect(find.byType(RequestSeedlingFormDownload), findsNWidgets(2));
      await t.pumpWidget(const SizedBox());
      await show(false);
      expect(find.byType(RequestSeedlingFormDownload), findsNothing);
    },
  );
}
