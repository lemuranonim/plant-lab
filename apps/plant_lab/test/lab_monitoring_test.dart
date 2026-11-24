import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_lab/features/lab_request/presentation/lab_monitoring_screen.dart';

Map<String, dynamic> monitoringFixture({int offset = 0}) => {
  'version': 1,
  'read_only': true,
  'sla_applied': false,
  'authorizes_lot_release': false,
  'grain': 'ONE_TEST_ATTEMPT_OR_UNSTARTED_ITEM_OR_DRAFT',
  'selected_lab_site_id': 'memory-lab',
  'lab_sites': [
    {'id': 'memory-lab', 'site_name': 'Memory Lab'},
  ],
  'method_options': [
    {'method_code': 'SAND_25C', 'method_name': 'Germinasi'},
  ],
  'as_of': '2026-11-18T01:00:00Z',
  'total': 56,
  'offset': offset,
  'limit': 50,
  'has_more': offset == 0,
  'summary': {
    'total': 56,
    'active': 54,
    'waiting_sample': 2,
    'waiting_test': 1,
    'testing': 49,
    'waiting_qa': 1,
    'retest': 1,
    'returned': 0,
    'incomplete': 0,
    'approved_analysis': 1,
    'verified_mc': 1,
    'missing_sample_time': 2,
    'missing_qa_time': 0,
    'clock_issues': 0,
    'sample_tat_hours': 24,
    'sample_tat_count': 2,
    'qa_tat_hours': 0,
    'qa_tat_count': 2,
    'mc_qa_hours': null,
    'mc_qa_count': 0,
    'analytical_decisions': 2,
    'retest_decisions': 1,
    'retest_rate_percent': 50,
  },
  'entries': [
    {
      'entry_kind': 'ROUTINE',
      'entry_id': 'memory-${offset + 1}',
      'lot_code': 'MEMORY-LOT-123456789012345678901234567890',
      'hybrid': 'H59',
      'method_code': 'SAND_25C',
      'method_name': 'Germinasi',
      'status': 'IN_REVIEW',
      'work_group': 'WAITING_QA',
      'sample_reference': null,
      'run_code': 'LT-MEMORY-ONLY',
      'request_code': null,
      'attempt_no': 1,
      'received_at': null,
      'submitted_at': '2026-11-18T01:00:00Z',
      'decision_at': null,
      'receipt_basis': 'LAB_AVAILABLE_ACTUAL_INPUT',
      'open_sample_hours': null,
      'waiting_qa_hours': 0,
      'retest_wait_hours': null,
      'sample_to_submit_hours': null,
      'qa_tat_hours': null,
      'clock_issue': false,
      'active': true,
    },
  ],
};
void main() {
  test(
    'clock zero remains zero, missing is unavailable, invalid sources rejected',
    () {
      expect(monitoringHours(0), '0 jam');
      expect(monitoringHours(null), 'Belum dapat dihitung');
      expect(monitoringHours(24), '1 hari (24 jam)');
      final p = monitoringFixture();
      expect(validateMonitoringPage(p), same(p));
      p['entries'][0]['waiting_qa_hours'] = -1;
      expect(() => validateMonitoringPage(p), throwsFormatException);
    },
  );
  for (final dark in [false, true]) {
    testWidgets(
      'monitor320px150percent $dark applied filters, pagination, failed read hides stale results',
      (t) async {
        t.view.physicalSize = const Size(320, 1000);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final calls = <Map<String, dynamic>>[];
        var fail = false;
        await t.pumpWidget(
          MaterialApp(
            theme: dark
                ? ThemeData.dark(useMaterial3: true)
                : ThemeData.light(useMaterial3: true),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: LabMonitoringScreen(
              loadRecords: (args) async {
                calls.add(Map.of(args));
                if (fail) throw StateError('Memory connection failure');
                return monitoringFixture(offset: args['p_offset'] as int);
              },
            ),
          ),
        );
        Future<void> show(Finder finder, [double delta = 400]) async {
          await t.scrollUntilVisible(
            finder,
            delta,
            scrollable: find.byType(Scrollable).first,
          );
          await t.ensureVisible(finder);
          await t.pumpAndSettle();
        }

        await t.pumpAndSettle();
        expect(calls.single['p_offset'], 0);
        await show(find.text('56 pekerjaan cocok'));
        expect(find.text('56 pekerjaan cocok'), findsOneWidget);
        final search = find.widgetWithText(
          TextField,
          'Cari lot, hybrid, label, nomor uji',
        );
        await show(search, -400);
        await t.enterText(search, 'needle');
        await t.pumpAndSettle();
        await show(find.textContaining('Filter berubah.'));
        expect(find.textContaining('Filter berubah.'), findsOneWidget);
        final next = find.widgetWithText(OutlinedButton, 'Berikutnya');
        await show(next);
        await t.tap(next);
        await t.pumpAndSettle();
        expect(calls.last['p_search'], '');
        expect(calls.last['p_offset'], 50);
        fail = true;
        final apply = find.widgetWithText(FilledButton, 'Tampilkan pemantauan');
        await show(apply, -400);
        await t.tap(apply);
        await t.pumpAndSettle();
        expect(calls.last['p_search'], 'needle');
        expect(find.text('56 pekerjaan cocok'), findsNothing);
        expect(find.textContaining('Pemantauan belum dimuat.'), findsOneWidget);
        fail = false;
        final retry = find.widgetWithText(TextButton, 'Coba muat ulang');
        await show(retry);
        await t.tap(retry);
        await t.pumpAndSettle();
        expect(calls.last, calls[calls.length - 2]);
        await show(find.text('56 pekerjaan cocok'));
        expect(find.text('56 pekerjaan cocok'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
  }
}
