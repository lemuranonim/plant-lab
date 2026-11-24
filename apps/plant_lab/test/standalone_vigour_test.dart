import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_lab/features/lab_request/presentation/standalone_vigour.dart';

void main() {
  test(
    'RET payload uses four radicle counts, not normal seedling categories',
    () {
      expect(confirmedRetCounts(['80', '81', '82', '82']), [
        {'tested': 100, 'radicle_at_least_2mm': 80},
        {'tested': 100, 'radicle_at_least_2mm': 81},
        {'tested': 100, 'radicle_at_least_2mm': 82},
        {'tested': 100, 'radicle_at_least_2mm': 82},
      ]);
      expect(
        confirmedRetCounts(['0', '0', '0', '0'])!.first['radicle_at_least_2mm'],
        0,
      );
      for (final bad in [
        ['80', '80'],
        ['', '0', '0', '0'],
        ['101', '0', '0', '0'],
        ['80.5', '0', '0', '0'],
      ]) {
        expect(confirmedRetCounts(bad), isNull);
      }
    },
  );
  test(
    '2x100 preserves zero and rejects missing, fractional, oversized and2x50 input',
    () {
      expect(confirmedVigourCounts(['70', '20', '10', '69', '20', '11']), [
        {'normal': 70, 'abnormal': 20, 'dead': 10},
        {'normal': 69, 'abnormal': 20, 'dead': 11},
      ]);
      expect(
        confirmedVigourCounts([
          '0',
          '0',
          '100',
          '0',
          '100',
          '0',
        ])!.first['normal'],
        0,
      );
      for (final invalid in [
        ['48', '0', '2', '47', '2', '1'],
        ['', '0', '100', '0', '0', '100'],
        ['99.5', '0', '0.5', '0', '0', '100'],
        ['101', '0', '0', '0', '0', '100'],
        ['-1', '0', '101', '0', '0', '100'],
        ['100', '0', '0'],
      ]) {
        expect(confirmedVigourCounts(invalid), isNull);
      }
    },
  );
  final run = <String, dynamic>{
    'item_id': 'UNIT-ITEM',
    'run_id': 'UNIT-RUN',
    'method_name': 'Accelerated Aging Test (42°C,72h,RH>90%)',
    'status': 'IN_PROGRESS',
    'item_status': 'TESTING',
    'is_assigned_analyst': true,
    'prior_attempts': <Map<String, dynamic>>[],
  };

  Future<void> form(
    WidgetTester tester,
    String action, {
    Map<String, dynamic>? row,
    Future<void> Function(String, Map<String, dynamic>)? execute,
  }) async {
    tester.view.physicalSize = const Size(360, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: VigourActionDialog(
            run: row ?? run,
            action: action,
            execute: execute,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'RET final form has four radicle fields and no normal categories',
    (tester) async {
      await form(
        tester,
        'submit',
        row: {
          ...run,
          'method_code': 'RET_16C_72H',
          'method_name': 'RET16C72h',
          'actual_started_at': DateTime.now()
              .subtract(const Duration(hours: 73))
              .toUtc()
              .toIso8601String(),
        },
      );
      expect(find.byType(TextField), findsNWidgets(5));
      expect(find.text('Radikula ≥2 mm ulangan 1'), findsOneWidget);
      expect(find.text('Radikula ≥2 mm ulangan 4'), findsOneWidget);
      expect(find.text('Normal ulangan 1'), findsNothing);
      expect(find.textContaining('Toleransi 4 Reps'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Kirim hasil Vigor ke QA'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('RET start form names placement16C as the actual time anchor', (
    tester,
  ) async {
    await form(
      tester,
      'start',
      row: {...run, 'method_code': 'RET_16C_72H', 'method_name': 'RET16C72h'},
    );
    expect(find.text('Pilih waktu penempatan pada 16°C'), findsOneWidget);
    expect(find.textContaining('Minimal 72 jam'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'narrow final form has complete labels and no fabricated time or counts',
    (tester) async {
      var commands = 0;
      await form(
        tester,
        'submit',
        execute: (_, _) async {
          commands++;
        },
      );
      expect(find.text('Pilih waktu pengamatan nyata'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(7));
      final button = find.widgetWithText(
        FilledButton,
        'Kirim hasil Vigor ke QA',
      );
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      final fields = find.byType(TextField);
      const counts = ['70', '20', '10', '69', '20', '11'];
      for (var i = 0; i < 6; i++) {
        await tester.enterText(fields.at(i), counts[i]);
        await tester.pump();
      }
      await tester.enterText(fields.at(6), 'Actual observation note');
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(commands, 0);
      expect(find.textContaining('Pilih waktu kejadian nyata'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('QA cannot choose approval without configured source tolerance', (
    tester,
  ) async {
    await form(
      tester,
      'review',
      row: {
        ...run,
        'summary': {'within_tolerance': null},
      },
    );
    final dropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );
    expect(dropdown.items!.first.enabled, false);
    expect(dropdown.items!.last.value, 'RETEST');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'failed QA retry retains action UUID; changing reason starts a new action',
    (tester) async {
      final actions = <String>[];
      await form(
        tester,
        'review',
        row: {
          ...run,
          'summary': {'within_tolerance': true},
        },
        execute: (_, params) async {
          actions.add(params['p_action_id'] as String);
          throw StateError('memory-only transport failure');
        },
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Minta uji ulang').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Real QA retest reason');
      final button = find.widgetWithText(FilledButton, 'Simpan keputusan QA');
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(actions.length, 2);
      expect(actions[0], actions[1]);
      await tester.enterText(
        find.byType(TextField),
        'Changed QA retest reason',
      );
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(actions.length, 3);
      expect(actions[2], isNot(actions[1]));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Plant read-only panel does not expose Lab input controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StandaloneVigour(
              run: {...run, 'is_assigned_analyst': false},
              requestStatus: 'TESTING',
              analyst: false,
              reviewer: false,
              onSaved: () {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.textContaining('Vigor ·'));
    await tester.pumpAndSettle();
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });
}
