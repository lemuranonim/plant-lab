import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_lab/app/theme/app_theme.dart';
import 'package:plant_lab/features/lab_request/presentation/routine_lab_screen.dart';

void main() {
  testWidgets(
    'final total excludes first count and QA opens a saved revision',
    (tester) async {
      tester.view.physicalSize = const Size(390, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int revision = 0;
      Map<String, dynamic>? sent;
      bool? requestedReview;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  requestedReview = await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(
                      builder: (_) => RoutineDraftEditor(
                        labSiteId: 'memory-lab',
                        canOpenReview: true,
                        record: {
                          'id': 'memory-draft',
                          'lot_id': 'memory-lot',
                          'lot_code': 'DEMO-DCS-123',
                          'hybrid': 'H59',
                          'stage_code': 'DCS',
                          'revision': 0,
                          'can_edit': true,
                          'method_code': 'SAND_25C',
                          'method_name': 'Germinasi pasir',
                          'content': emptyRoutineContent('SAND_25C', 2),
                        },
                        saveDraft: (args) async {
                          sent = args;
                          return {'revision': ++revision};
                        },
                      ),
                    ),
                  );
                },
                child: const Text('Buka draft'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Buka draft'));
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('routine-save-draft'));
      final go = find.text('Ke pemeriksaan QA');
      expect(save.hitTestable(), findsOneWidget);
      expect(go, findsNothing);
      await tester.tap(find.text('Ulangan'));
      await tester.pumpAndSettle();
      final header = find.descendant(
        of: find.byType(AppBar),
        matching: find.text('DEMO-DCS-123'),
      );
      expect(header.hitTestable(), findsOneWidget);
      expect(save.hitTestable(), findsOneWidget);
      Future<void> count(String label, String value) async {
        final field = find.widgetWithText(TextFormField, label);
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        await tester.enterText(field, value);
        await tester.pumpAndSettle();
      }

      await count('Normal first count', '42');
      expect(find.text('Final: belum dicatat'), findsOneWidget);
      await count('Fresh', '0');
      expect(
        find.text('Final: 0/50 benih · 1/5 kategori terisi'),
        findsOneWidget,
      );
      await count('Normal final count', '45');
      await count('Abnormal', '6');
      expect(
        find.textContaining('Final: 51/50 benih · 3/5 kategori terisi'),
        findsOneWidget,
      );
      expect(find.textContaining('Jumlah melebihi 50 benih.'), findsOneWidget);
      await count('Abnormal', '5');
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(sent!['p_content']['observations'][0], {
        'first_normal': 42,
        'final_normal': 45,
        'abnormal': 5,
        'fresh': 0,
        'hard': null,
        'dead': null,
      });
      expect(revision, 1);
      await count('Mati', '0');
      await tester.tap(go);
      await tester.pumpAndSettle();
      expect(
        find.text('Simpan perubahan sebelum membuka pemeriksaan QA.'),
        findsOneWidget,
      );
      expect(requestedReview, isNull);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(sent!['p_expected_revision'], 1);
      await tester.tap(go);
      await tester.pumpAndSettle();
      expect(requestedReview, true);
      expect(revision, 2);
      expect(tester.takeException(), isNull);
    },
  );

  test('blank is unknown; a/b pairs and RET remain distinct', () {
    final germ = emptyRoutineContent('SAND_25C', 2);
    expect((germ['observations'] as List).length, 4);
    expect((germ['observations'] as List).first['final_normal'], null);
    expect(routineObservationLabel(1, false), contains('1b'));
    expect(
      (emptyRoutineContent('SAND_25C', 4)['observations'] as List).length,
      8,
    );
    expect(routineObservationLabel(7, false), contains('4b'));
    final ret = emptyRoutineContent('RET_16C_72H', 4);
    expect((ret['observations'] as List).length, 4);
    expect(((ret['observations'] as List).first as Map).keys, [
      'radicle_at_least_2mm',
    ]);
    expect(routineWib('2026-11-12T23:00:00Z'), '2026-11-13 06:00 WIB');
  });
  for (final accept in [false, true]) {
    testWidgets(
      'changing replication ${accept ? 'clears after confirmation' : 'cancel keeps counts and selection'}',
      (tester) async {
        final content = emptyRoutineContent('SAND_25C', 2);
        (content['observations'] as List)[0]['final_normal'] = 41;
        Map<String, dynamic>? payload;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: RoutineDraftEditor(
              labSiteId: 'memory-lab',
              record: {
                'id': 'memory-draft',
                'lot_id': 'memory-lot',
                'lot_code': 'MEMORY-ONLY',
                'hybrid': 'H59',
                'stage_code': 'DCS',
                'revision': 0,
                'method_code': 'SAND_25C',
                'method_name': 'Germ',
                'replicate_counts': [2, 4],
                'can_edit': true,
                'content': content,
              },
              saveDraft: (args) async {
                payload = args;
                return {'revision': 1};
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        final choice = find.byKey(const ValueKey('routine-replicates-2-0'));
        await tester.scrollUntilVisible(
          choice.hitTestable(),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(choice.hitTestable());
        await tester.pumpAndSettle();
        await tester.tap(find.text('4 × 100 benih').last);
        await tester.pumpAndSettle();
        expect(find.text('Ganti jumlah ulangan?'), findsOneWidget);
        await tester.tap(
          find.text(
            accept ? 'Ganti dan kosongkan hitungan' : 'Tetap rancangan lama',
          ),
        );
        await tester.pumpAndSettle();
        if (!accept) {
          expect(
            find.byKey(const ValueKey('routine-replicates-2-1')),
            findsOneWidget,
          );
        }
        final save = find.byKey(const ValueKey('routine-save-draft'));
        await tester.scrollUntilVisible(
          save,
          350,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(payload!['p_content']['replicate_count'], accept ? 4 : 2);
        expect(
          (payload!['p_content']['observations'] as List).length,
          accept ? 8 : 4,
        );
        expect(
          payload!['p_content']['observations'][0]['final_normal'],
          accept ? null : 41,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final dark in [false, true]) {
    for (final editable in [true, false]) {
      for (final replicates in [2, 4]) {
        testWidgets(
          'routine draft ${replicates}x100 320px 150% ${dark ? 'dark' : 'light'} ${editable ? 'analyst' : 'QA read-only'}',
          (tester) async {
            tester.view.physicalSize = const Size(320, 950);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final content = emptyRoutineContent(
              'SAND_25C',
              editable ? 2 : replicates,
            );
            int writes = 0;
            Map<String, dynamic>? payload;
            await tester.pumpWidget(
              MaterialApp(
                theme: dark ? AppTheme.dark : AppTheme.light,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.5)),
                  child: child!,
                ),
                home: RoutineDraftEditor(
                  labSiteId: 'memory-lab',
                  record: {
                    'id': 'memory-draft',
                    'lot_id': 'memory-lot',
                    'lot_code': 'MEMORY-ONLY',
                    'hybrid': 'H59',
                    'stage_code': 'DCS',
                    'revision': 0,
                    'method_code': 'SAND_25C',
                    'method_name': 'Germinasi Pasir 25 C',
                    'replicate_counts': [2, 4],
                    'can_edit': editable,
                    'content': content,
                  },
                  saveDraft: (args) async {
                    writes++;
                    payload = args;
                    return {'revision': 1, 'status': 'DRAFT'};
                  },
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), null);
            expect(find.text('Jenis uji: Pengujian awal'), findsOneWidget);
            if (editable) {
              if (replicates == 4) {
                final choice = find.byKey(
                  const ValueKey('routine-replicates-2-0'),
                );
                await tester.scrollUntilVisible(
                  choice,
                  250,
                  scrollable: find.byType(Scrollable).first,
                );
                await tester.tap(choice);
                await tester.pumpAndSettle();
                await tester.tap(find.text('4 × 100 benih').last);
                await tester.pumpAndSettle();
              }
              final sample = find.byKey(
                const ValueKey('routine-sample-reference'),
              );
              await tester.scrollUntilVisible(
                find.text('Isi manual'),
                200,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.ensureVisible(find.text('Isi manual'));
              await tester.pumpAndSettle();
              await tester.tap(find.text('Isi manual'));
              await tester.pumpAndSettle();
              await tester.scrollUntilVisible(
                sample,
                250,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.enterText(sample, 'Actual label');
              await tester.pumpAndSettle();
              final save = find.byKey(const ValueKey('routine-save-draft'));
              await tester.scrollUntilVisible(
                save,
                350,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.ensureVisible(save);
              await tester.pumpAndSettle();
              await tester.tap(save);
              await tester.pumpAndSettle();
              expect(writes, 1);
              expect(payload!['p_content']['sample_reference'], 'Actual label');
              expect(
                payload!['p_content']['observations'][0]['final_normal'],
                null,
              );
              expect(payload!['p_content']['started_at'], null);
              expect(payload!['p_content']['replicate_count'], replicates);
              expect(
                (payload!['p_content']['observations'] as List).length,
                replicates * 2,
              );
              expect(payload!['p_action_id'], isNotEmpty);
            } else {
              expect(
                find.widgetWithText(FilledButton, 'Simpan draft'),
                findsNothing,
              );
              expect(writes, 0);
            }
            expect(tester.takeException(), null);
          },
        );
      }
    }
  }
}
