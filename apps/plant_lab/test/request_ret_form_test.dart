import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_lab/app/theme/app_theme.dart';
import 'package:plant_lab/features/lab_request/presentation/request_ret_form_download.dart';
import 'package:plant_lab/features/lab_request/presentation/standalone_vigour.dart';

void main() {
  test(
    'RET request URI uses saved run/status, fixed Lab HTTPS and no fake revision',
    () {
      final u = requestRetUri('LT-ENGINEERINGONLY', 'RETEST', 'xlsx');
      expect(u.host, 'lab.advantaindonesia.com');
      expect(u.scheme, 'https');
      expect(u.path, '/api/lab-ret-request/LT-ENGINEERINGONLY/export');
      expect(u.queryParameters, {'format': 'xlsx', 'status': 'RETEST'});
      for (final args in [
        ['https://evil.invalid', 'APPROVED', 'pdf'],
        ['LT-TEST/../', 'APPROVED', 'pdf'],
        ['LT-TEST', 'DRAFT', 'pdf'],
        ['LT-TEST', 'APPROVED', 'html'],
      ]) {
        expect(
          () => requestRetUri(args[0], args[1], args[2]),
          throwsFormatException,
        );
      }
    },
  );
  for (final dark in [false, true]) {
    testWidgets(
      'RET request per-attempt download 320px150percent $dark retry and saved status',
      (t) async {
        t.view.physicalSize = const Size(320, 1000);
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
                  RequestRetFormDownload(
                    runCode: 'LT-ENGINEERINGONLY',
                    status: 'RETEST',
                    load: (code, status, format) async {
                      calls.add([code, status, format]);
                      if (++loads == 1) {
                        throw StateError('Koneksi terputus. Coba lagi.');
                      }
                      return RequestRetFile(
                        Uint8List.fromList([37, 80, 68, 70, 45]),
                        'Form-RET-Request-99000000-0000-4000-8000-000000000051-RETEST.$format',
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
        await t.tap(find.text('Unduh RET PDF'));
        await t.pumpAndSettle();
        expect(find.text('Koneksi terputus. Coba lagi.'), findsOneWidget);
        expect(shared, isNull);
        await t.tap(find.text('Unduh RET PDF'));
        await t.pumpAndSettle();
        expect(shared, endsWith('-RETEST.pdf'));
        expect(calls.last, ['LT-ENGINEERINGONLY', 'RETEST', 'pdf']);
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'RET request current and prior attempt show separate forms, not on Plant',
    (t) async {
      final run = {
        'method_code': 'RET_16C_72H',
        'method_name': 'RET',
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
        await t.tap(find.text('Vigor · RET'));
        await t.pumpAndSettle();
      }

      await show(true);
      expect(find.byType(RequestRetFormDownload), findsOneWidget);
      await t.tap(find.text('Riwayat percobaan sebelumnya (1)'));
      await t.pumpAndSettle();
      expect(find.byType(RequestRetFormDownload), findsNWidgets(2));
      await t.pumpWidget(const SizedBox());
      await show(false);
      expect(find.byType(RequestRetFormDownload), findsNothing);
    },
  );
}
