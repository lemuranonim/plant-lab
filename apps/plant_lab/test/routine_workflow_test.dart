import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_lab/app/theme/app_theme.dart';
import 'package:plant_lab/features/lab_request/presentation/routine_workflow_card.dart';

Map<String, dynamic> summary({bool? tolerance = true}) => {
  'germination_percent': 86,
  'unrounded_percent': 85.5,
  'gap_pp': 1,
  'limit_pp': tolerance == null ? null : 9,
  'within_tolerance': tolerance,
  'replicates': [
    {'normal': 85, 'abnormal': 5, 'fresh': 5, 'hard': 2, 'dead': 3},
    {'normal': 86, 'abnormal': 4, 'fresh': 5, 'hard': 2, 'dead': 3},
  ],
  'calculation_code': 'ROUTINE_ROUND_MEAN_2X100_V1',
  'calculation_version': 1,
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
    for (final available in [false, true]) {
      testWidgets(
        'routine QA ${available ? 'configured' : 'missing'} tolerance narrow150% ${dark ? 'dark' : 'light'}',
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
                    'summary': summary(tolerance: available ? true : null),
                    'can_review': true,
                  },
                },
                canWrite: true,
                checkDraft: () async => {},
                sendCommand: (name, args) async {
                  sent = args;
                  return {'status': 'APPROVED'};
                },
                onChanged: (_) async {},
              ),
              dark,
            ),
          );
          await tester.pumpAndSettle();
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
          if (available) {
            await tester.ensureVisible(approve);
            await tester.tap(approve);
            await tester.pumpAndSettle();
            expect(sent!['p_protocol_checked'], true);
            expect(sent!['p_decision'], 'APPROVE');
          } else {
            expect(tester.widget<FilledButton>(approve).onPressed, isNull);
            expect(
              tester
                  .widget<OutlinedButton>(
                    find.widgetWithText(OutlinedButton, 'Minta uji ulang'),
                  )
                  .onPressed,
              isNotNull,
            );
            expect(sent, isNull);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
