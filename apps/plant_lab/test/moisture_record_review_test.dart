import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_lab/features/lab_request/presentation/moisture_record_workflow.dart';

void main() {
  final record = <String, dynamic>{
    'id': 'memory-mc',
    'revision': 3,
    'submission_id': 'memory-submission',
    'can_submit': false,
    'can_review': true,
  };
  testWidgets(
    'MC verification requires QA name and explicit record-only confirmation; retry stable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calls = <Map<String, dynamic>>[];
      int changed = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: MoistureRecordWorkflow(
                record: record,
                onChanged: () => changed++,
                command: (name, args) async {
                  expect(name, 'review_lab_moisture_record');
                  calls.add(args);
                  if (calls.length == 1) throw Exception('memory offline');
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Verifikasi catatan MC'));
      await tester.pumpAndSettle();
      final save = find.widgetWithText(
        FilledButton,
        'Simpan verifikasi catatan',
      );
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await tester.enterText(find.byType(TextField).first, 'QA actual');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(calls.length, 1);
      expect(changed, 0);
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(calls.length, 2);
      expect(calls[0], calls[1]);
      expect(changed, 1);
      expect(calls[0]['p_decision'], 'VERIFY_RECORD');
      expect(calls[0]['p_expected_revision'], 3);
      expect(calls[0]['p_reviewer_name'], 'QA actual');
      expect(
        find.textContaining('bukan keputusan lulus/gagal'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('MC return needs reason; no quality PASS/FAIL choice', (
    tester,
  ) async {
    final calls = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MoistureRecordWorkflow(
              record: record,
              onChanged: () {},
              command: (name, args) async => calls.add(args),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Verifikasi catatan MC'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'QA actual');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kembalikan untuk diperbaiki').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Kembalikan ke Analis');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.enterText(find.byType(TextField).last, 'Priksa label sampel');
    await tester.pumpAndSettle();
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(calls.single['p_decision'], 'RETURN');
    expect(calls.single['p_note'], 'Priksa label sampel');
    expect(tester.takeException(), isNull);
  });
  testWidgets('MC submit always uses saved revision and confirmation', (
    tester,
  ) async {
    final calls = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MoistureRecordWorkflow(
              record: {...record, 'can_submit': true, 'can_review': false},
              onChanged: () {},
              command: (name, args) async {
                expect(name, 'submit_lab_moisture_record');
                calls.add(args);
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Kirim catatan MC ke QA'));
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Ya, kirim revisi ini');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(calls.single['p_expected_revision'], 3);
    expect(calls.single.containsKey('p_content'), isFalse);
  });
  testWidgets('MC workflow hidden without server-scoped permission', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MoistureRecordWorkflow(
          record: {...record, 'can_submit': false, 'can_review': false},
          onChanged: () {},
          command: (_, _) async => fail('No authority'),
        ),
      ),
    );
    expect(find.byType(OutlinedButton), findsNothing);
  });
}
