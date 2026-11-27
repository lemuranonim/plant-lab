import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_lab/app/theme/app_theme.dart';
import 'package:plant_lab/core/config/app_config.dart';
import 'package:plant_lab/features/lab_request/presentation/routine_lab_screen.dart';
import 'package:plant_lab/features/lab_request/presentation/routine_workflow_card.dart';

Map<String, dynamic> summary({bool? tolerance = true}) => {
  'germination_percent': 86,
  'unrounded_percent': 85.5,
  'gap_pp': tolerance == false ? 11 : 1,
  'limit_pp': tolerance == null ? null : 9,
  'within_tolerance': tolerance,
  'replicates': tolerance == false
      ? [
          {'normal': 80, 'abnormal': 10, 'fresh': 5, 'hard': 2, 'dead': 3},
          {'normal': 91, 'abnormal': 3, 'fresh': 2, 'hard': 1, 'dead': 3},
        ]
      : [
          {'normal': 85, 'abnormal': 5, 'fresh': 5, 'hard': 2, 'dead': 3},
          {'normal': 86, 'abnormal': 4, 'fresh': 5, 'hard': 2, 'dead': 3},
        ],
  'calculation_code': 'ROUTINE_ROUND_MEAN_2X100_V1',
  'calculation_version': 1,
};
Map<String, dynamic> qaRecord({bool? tolerance = true}) => {
  'id': 'qa-demo',
  'lot_code': 'DEMO-DCS-024',
  'hybrid': 'H59',
  'stage_code': 'DCS',
  'revision': 7,
  'status': 'IN_REVIEW',
  'method_code': 'SAND_25C',
  'method_name': 'Germinasi · Pasir 25 °C',
  'can_edit': false,
  'content': emptyRoutineContent('SAND_25C', 2)
    ..addAll({
      'sample_reference': 'SMP-DEMO-QA',
      'received_at': '2026-11-07T02:00:00Z',
      'started_at': '2026-11-07T04:00:00Z',
      'final_at': '2026-11-14T05:00:00Z',
      'observations': [
        for (final (n, a, f, h, d)
            in tolerance == false
                ? [
                    (40, 5, 2, 1, 2),
                    (40, 5, 3, 1, 1),
                    (45, 2, 1, 1, 1),
                    (46, 1, 1, 0, 2),
                  ]
                : [
                    (42, 3, 2, 1, 2),
                    (43, 2, 3, 1, 1),
                    (43, 2, 2, 1, 2),
                    (43, 2, 3, 1, 1),
                  ])
          {
            'first_normal': null,
            'final_normal': n,
            'abnormal': a,
            'fresh': f,
            'hard': h,
            'dead': d,
          },
      ],
    }),
  'workflow': {
    'run_id': 'DEMO-RUN',
    'run_code': 'DEMO-LT-026',
    'attempt_no': 1,
    'status': 'IN_REVIEW',
    'analyst_id': 'DEMO-ANALYST',
    'can_review': true,
    'summary': summary(tolerance: tolerance),
  },
};
Widget app(Widget child, bool dark) => MaterialApp(
  theme: dark ? AppTheme.dark : AppTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: const TextScaler.linear(1.5)),
    child: child!,
  ),
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: child,
    ),
  ),
);

void main() {
  testWidgets('QA screen pins lot and shows sample evidence before decisions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 830);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routineRecordProvider(
            'qa-demo',
          ).overrideWith((_) async => qaRecord()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const RoutineWorkflowScreen(draftId: 'qa-demo'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final pinned = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('DEMO-DCS-024'),
    );
    expect(pinned.hitTestable(), findsOneWidget);
    if (!AppConfig.canonicalWritesEnabled) {
      expect(find.text('Pemeriksaan QA independen'), findsNothing);
      return;
    }
    final position = tester.getTopLeft(pinned);
    final evidence = find.text('Bukti sampel & waktu');
    await tester.scrollUntilVisible(
      evidence,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(evidence);
    await tester.pumpAndSettle();
    expect(find.text('SMP-DEMO-QA'), findsOneWidget);
    expect(find.text('2026-11-14 12:00 WIB'), findsOneWidget);
    final details = find.text('Catatan dan hitungan tercatat');
    await tester.ensureVisible(details);
    await tester.pumpAndSettle();
    await tester.tap(details);
    await tester.pumpAndSettle();
    expect(find.textContaining('Ulangan 1a · 50 benih'), findsOneWidget);
    expect(tester.getTopLeft(pinned), position);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    for (final ready in [false, true]) {
      testWidgets(
        'routine submission ${ready ? 'ready retry' : 'incomplete'} narrow150% ${dark ? 'dark' : 'light'}',
        (tester) async {
          tester.view.physicalSize = const Size(320, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final calls = <Map<String, dynamic>>[];
          await tester.pumpWidget(
            app(
              RoutineWorkflowCard(
                record: {
                  'id': 'MEMORY-DRAFT',
                  'revision': 7,
                  'status': 'DRAFT',
                  'can_edit': true,
                },
                canWrite: true,
                checkDraft: () async => {
                  'revision': 7,
                  'ready': ready,
                  'summary': ready ? summary() : null,
                  'blockers': ready
                      ? []
                      : [
                          {
                            'code': 'COUNTS',
                            'message':
                                'Lengkapi seluruh hitungan; kosong bukan nol.',
                          },
                        ],
                  'warnings': [],
                },
                sendCommand: (name, args) async {
                  calls.add({'name': name, ...args});
                  if (calls.length == 1) {
                    throw StateError('Memory connection break');
                  }
                  return {'status': 'IN_REVIEW'};
                },
                onChanged: (_) async {},
              ),
              dark,
            ),
          );
          await tester.pumpAndSettle();
          final inspect = find.widgetWithText(
            OutlinedButton,
            'Periksa sebelum kirim ke QA',
          );
          await tester.ensureVisible(inspect);
          await tester.tap(inspect);
          await tester.pumpAndSettle();
          final send = find.widgetWithText(
            FilledButton,
            'Kirim revisi ini ke QA',
          );
          await tester.ensureVisible(send);
          expect(tester.widget<FilledButton>(send).onPressed, isNull);
          await tester.tap(find.byType(CheckboxListTile));
          await tester.pumpAndSettle();
          if (ready) {
            await tester.ensureVisible(send);
            await tester.tap(send);
            await tester.pumpAndSettle();
            await tester.ensureVisible(send);
            await tester.tap(send);
            await tester.pumpAndSettle();
            expect(calls.length, 2);
            expect(calls[0], calls[1]);
            expect(calls[1]['p_expected_revision'], 7);
            expect(calls[1]['p_actual_work_confirmed'], true);
          } else {
            expect(tester.widget<FilledButton>(send).onPressed, isNull);
            expect(calls, isEmpty);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
    for (final tolerance in <bool?>[true, false, null]) {
      testWidgets(
        'routine QA tolerance $tolerance narrow150% ${dark ? 'dark' : 'light'}',
        (tester) async {
          tester.view.physicalSize = const Size(320, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          Map<String, dynamic>? sent;
          await tester.pumpWidget(
            app(
              RoutineWorkflowCard(
                record: {
                  'status': 'IN_REVIEW',
                  'workflow': {
                    'run_id': 'MEMORY-RUN',
                    'run_code': 'MEMORY-ONLY',
                    'attempt_no': 1,
                    'summary': summary(tolerance: tolerance),
                    'can_review': true,
                  },
                },
                canWrite: true,
                reviewEvidence: const Text('SMP-DEMO-QA'),
                checkDraft: () async => {},
                sendCommand: (name, args) async {
                  sent = args;
                  return {
                    'status': args['p_decision'] == 'APPROVE'
                        ? 'APPROVED'
                        : 'RETEST',
                  };
                },
                onChanged: (_) async {},
              ),
              dark,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('SMP-DEMO-QA'), findsOneWidget);
          expect(find.text('Selisih ulangan'), findsOneWidget);
          expect(find.text('Batas toleransi'), findsOneWidget);
          final approve = find.widgetWithText(FilledButton, 'Setujui analisis');
          await tester.ensureVisible(approve);
          expect(tester.widget<FilledButton>(approve).onPressed, isNull);
          final reason = find.byType(TextField);
          await tester.ensureVisible(reason);
          await tester.enterText(reason, 'Actual protocol and counts checked');
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byType(CheckboxListTile));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(CheckboxListTile));
          await tester.pumpAndSettle();
          if (tolerance == true) {
            await tester.ensureVisible(approve);
            await tester.tap(approve);
            await tester.pumpAndSettle();
            expect(sent!['p_protocol_checked'], true);
            expect(sent!['p_decision'], 'APPROVE');
          } else {
            expect(tester.widget<FilledButton>(approve).onPressed, isNull);
            expect(
              find.textContaining(
                'Persetujuan ditahan; QA masih bisa meminta uji ulang.',
              ),
              findsOneWidget,
            );
            final retest = find.widgetWithText(
              OutlinedButton,
              'Minta uji ulang',
            );
            expect(tester.widget<OutlinedButton>(retest).onPressed, isNotNull);
            expect(sent, isNull);
            await tester.ensureVisible(retest);
            await tester.pumpAndSettle();
            await tester.tap(retest);
            await tester.pumpAndSettle();
            expect(sent!['p_protocol_checked'], true);
            expect(sent!['p_decision'], 'RETEST');
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
