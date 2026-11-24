import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_lab/core/config/app_config.dart';
import 'package:plant_lab/features/lab_request/presentation/standalone_germination.dart';

// UI-only fixtures. No Supabase client is initialized and no save is invoked.
void main() {
  Future<void> openForm(WidgetTester tester, {double scale = 1}) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: StandaloneGermination(
            requestId: 'UNIT-NOT-A-REAL-REQUEST',
            requestStatus: 'TESTING',
            run: const {
              'run_code': 'UNIT-RUN',
              'status': 'IN_PROGRESS',
              'is_assigned_analyst': true,
            },
            analyst: true,
            reviewer: false,
            onSaved: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Germinasi · Pasir 25 °C'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Isi pengamatan final'));
    await tester.pumpAndSettle();
  }

  FilledButton submitButton(WidgetTester tester) => tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, 'Kirim ke QA'),
  );

  for (final dark in [false, true]) {
    testWidgets(
      'retest confirmation at320px150percent $dark retries same prior, no inherited counts',
      (t) async {
        t.view.physicalSize = const Size(320, 1200);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        var saved = 0;
        final calls = <(String, Map<String, dynamic>)>[];
        await t.pumpWidget(
          MaterialApp(
            theme: dark
                ? ThemeData.dark(useMaterial3: true)
                : ThemeData.light(useMaterial3: true),
            builder: (c, w) => MediaQuery(
              data: MediaQuery.of(
                c,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: w!,
            ),
            home: Scaffold(
              body: ListView(
                children: [
                  StandaloneGermination(
                    requestId: '9c000000-0000-4000-8000-000000000031',
                    requestStatus: 'RETEST',
                    run: const {
                      'run_code': 'LT-PRIOR',
                      'status': 'RETEST',
                      'attempt_no': 1,
                      'decision_reason': 'Repeat independent observation',
                      'summary': {
                        'germination_percent': 95,
                        'within_tolerance': true,
                        'replicates': [
                          {'normal': 48, 'abnormal': 0, 'dead': 2},
                          {'normal': 47, 'abnormal': 2, 'dead': 1},
                        ],
                      },
                    },
                    analyst: true,
                    reviewer: false,
                    onSaved: () => saved++,
                    command: (name, params) async {
                      calls.add((name, Map.of(params)));
                      if (calls.length == 1) {
                        throw StateError('connection lost');
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
        await t.tap(find.text('Germinasi · Pasir 25 °C'));
        await t.pumpAndSettle();
        await t.ensureVisible(
          find.widgetWithText(TextButton, 'Mulai uji ulang Germinasi'),
        );
        await t.pumpAndSettle();
        for (
          var i = 0;
          i < 8 &&
              t
                      .getRect(
                        find.widgetWithText(
                          TextButton,
                          'Mulai uji ulang Germinasi',
                        ),
                      )
                      .bottom >
                  1180;
          i++
        ) {
          await t.drag(find.byType(ListView), const Offset(0, -700));
          await t.pumpAndSettle();
        }
        await t.tap(
          find.widgetWithText(TextButton, 'Mulai uji ulang Germinasi'),
        );
        await t.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
        FilledButton button() => t.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Mulai uji ulang'),
        );
        expect(button().onPressed, isNull);
        await t.ensureVisible(find.byType(Checkbox));
        await t.pumpAndSettle();
        await t.tap(find.byType(Checkbox));
        await t.pumpAndSettle();
        expect(button().onPressed, isNotNull);
        await t.ensureVisible(
          find.widgetWithText(FilledButton, 'Mulai uji ulang'),
        );
        await t.tap(find.widgetWithText(FilledButton, 'Mulai uji ulang'));
        await t.pumpAndSettle();
        expect(find.textContaining('Tidak dapat menyimpan'), findsOneWidget);
        expect(saved, 0);
        await t.tap(find.widgetWithText(FilledButton, 'Mulai uji ulang'));
        await t.pumpAndSettle();
        expect(saved, 1);
        expect(calls.length, 2);
        expect(calls[0].$1, 'start_germination_retest');
        expect(calls[1].$2, calls[0].$2);
        expect(calls[0].$2, {
          'p_request_id': '9c000000-0000-4000-8000-000000000031',
          'p_prior_run_code': 'LT-PRIOR',
          'p_sample_available': true,
        });
        expect(t.takeException(), isNull);
      },
      skip: !AppConfig.hostedPilot,
    );
  }
  testWidgets(
    'other analyst cannot input current final and dual-role analyst cannot self QA',
    (t) async {
      Future<void> show(String status, bool assigned) async {
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView(
                children: [
                  StandaloneGermination(
                    requestId: '9c000000-0000-4000-8000-000000000031',
                    requestStatus: status,
                    run: {
                      'run_code': 'LT-CURRENT',
                      'status': status,
                      'is_assigned_analyst': assigned,
                      'summary': {
                        'germination_percent': 94.5,
                        'within_tolerance': true,
                        'replicates': [
                          {'normal': 95, 'abnormal': 3, 'dead': 2},
                          {'normal': 94, 'abnormal': 4, 'dead': 2},
                        ],
                      },
                    },
                    analyst: true,
                    reviewer: true,
                    onSaved: () {},
                  ),
                ],
              ),
            ),
          ),
        );
        await t.tap(find.text('Germinasi · Pasir 25 °C'));
        await t.pumpAndSettle();
      }

      await show('IN_PROGRESS', false);
      expect(find.text('Isi pengamatan final'), findsNothing);
      expect(find.textContaining('Analis yang memulai'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await show('IN_REVIEW', true);
      expect(find.widgetWithText(TextButton, 'Review hasil'), findsNothing);
    },
    skip: !AppConfig.hostedPilot,
  );

  testWidgets(
    'legacy preview final form keeps complete labels and disables empty submission',
    (tester) async {
      await openForm(tester, scale: 1.3);
      expect(find.byType(TextField), findsNWidgets(6));
      expect(find.text('Abnormal'), findsNWidgets(2));
      expect(submitButton(tester).onPressed, isNull);
      final first = tester.getRect(find.byType(TextField).at(0));
      final second = tester.getRect(find.byType(TextField).at(1));
      expect(second.top, greaterThan(first.bottom));
      expect(tester.takeException(), isNull);
    },
    skip: !AppConfig.canonicalWritesEnabled || AppConfig.hostedPilot,
  );

  testWidgets(
    'legacy preview retains its original count contract (hosted rich capture tested separately)',
    (tester) async {
      await openForm(tester);
      const counts = ['48', '0', '2', '47', '2', '1'];
      for (var index = 0; index < counts.length; index++) {
        await tester.enterText(find.byType(TextField).at(index), counts[index]);
        await tester.pump();
      }
      expect(
        submitButton(tester).onPressed,
        AppConfig.hostedPilot ? isNull : isNotNull,
      );
      expect(find.text('Total ulangan 1: 50 benih'), findsOneWidget);
      expect(find.text('Total ulangan 2: 50 benih'), findsOneWidget);
      if (AppConfig.hostedPilot) {
        const confirmed = ['95', '3', '2', '94', '2', '4'];
        for (var index = 0; index < confirmed.length; index++) {
          await tester.enterText(
            find.byType(TextField).at(index),
            confirmed[index],
          );
          await tester.pump();
        }
        expect(find.text('Total ulangan 1: 100 benih'), findsOneWidget);
        expect(find.text('Total ulangan 2: 100 benih'), findsOneWidget);
        expect(submitButton(tester).onPressed, isNotNull);
        expect(find.text('4 ulangan'), findsNothing);
      }
      await tester.enterText(find.byType(TextField).at(5), '0');
      await tester.pump();
      expect(submitButton(tester).onPressed, isNull);
      await tester.enterText(find.byType(TextField).at(5), '1.5');
      await tester.pump();
      expect(submitButton(tester).onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
    skip: !AppConfig.canonicalWritesEnabled || AppConfig.hostedPilot,
  );
}
