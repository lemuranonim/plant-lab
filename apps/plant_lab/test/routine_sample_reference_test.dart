import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_lab/app/theme/app_theme.dart';
import 'package:plant_lab/features/lab_request/presentation/routine_lab_screen.dart';
import 'package:plant_lab/features/lab_request/presentation/routine_sample_reference.dart';

Map<String, dynamic> refs({
  String label = 'LAB-014',
  int offset = 0,
  bool more = false,
}) => {
  'references': [
    {'reference': label, 'sample_code': 'SMP-014', 'source_kind': 'RECEIVED'},
    {'reference': 'DRAFT-015', 'sample_code': null, 'source_kind': 'DRAFT'},
  ],
  'offset': offset,
  'total': more ? 51 : 2,
  'has_more': more,
};

void main() {
  testWidgets('search and explicit selection fill reference only in editor', (
    tester,
  ) async {
    final calls = <(String, int)>[];
    Map<String, dynamic>? saved;
    final content = emptyRoutineContent('SAND_25C', 2);
    await tester.pumpWidget(
      MaterialApp(
        home: RoutineDraftEditor(
          labSiteId: 'lab-only',
          record: {
            'id': 'draft',
            'revision': 0,
            'lot_id': 'lot-only',
            'lot_code': 'LOT',
            'method_code': 'SAND_25C',
            'replicate_counts': [2, 4],
            'can_edit': true,
            'content': content,
          },
          loadSampleReferences: (term, offset) async {
            calls.add((term, offset));
            return refs();
          },
          saveDraft: (args) async {
            saved = args;
            return {'revision': 1};
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Pilih label tercatat'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Pilih label tercatat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih label tercatat'));
    await tester.pumpAndSettle();
    expect(calls, [('', 0)]);
    expect(find.text('Label dari draft · belum diverifikasi'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('routine-reference-search')),
      ' lab-014 ',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(calls.last, ('lab-014', 0));
    await tester.tap(find.text('LAB-014'));
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
    expect(saved!['p_content']['sample_reference'], 'LAB-014');
    expect(saved!['p_content']['received_at'], null);
    expect(saved!['p_content']['started_at'], null);
    expect(saved!['p_content']['observations'][0]['final_normal'], null);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'manual fallback and pagination 320px 150% ${dark ? 'dark' : 'light'}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = TextEditingController(text: 'KEEP-LABEL');
        addTearDown(controller.dispose);
        final calls = <(String, int)>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark : AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: RoutineSampleReferenceField(
                  controller: controller,
                  enabled: true,
                  locked: false,
                  loadReferences: (term, offset) async {
                    calls.add((term, offset));
                    return refs(offset: offset, more: offset == 0);
                  },
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Pilih label tercatat'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('routine-reference-search')),
          '014',
        );
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('routine-reference-search')),
          'unsent-search',
        );
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Berikutnya'),
          200,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('routine-reference-list')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.ensureVisible(
          find.widgetWithText(OutlinedButton, 'Berikutnya'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Berikutnya'));
        await tester.pumpAndSettle();
        expect(calls.last, ('014', 50));
        await tester.scrollUntilVisible(
          find.text('Tidak ada di daftar · isi manual'),
          -200,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('routine-reference-list')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.ensureVisible(
          find.text('Tidak ada di daftar · isi manual'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tidak ada di daftar · isi manual'));
        await tester.pumpAndSettle();
        expect(controller.text, 'KEEP-LABEL');
        await tester.enterText(
          find.byKey(const ValueKey('routine-sample-reference')),
          'ACTUAL-MANUAL',
        );
        expect(controller.text, 'ACTUAL-MANUAL');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'load failure and cancel preserve label; late response is discarded',
    (tester) async {
      final controller = TextEditingController(text: 'KEEP');
      addTearDown(controller.dispose);
      final pending = Completer<Map<String, dynamic>>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoutineSampleReferenceField(
              controller: controller,
              enabled: true,
              locked: false,
              loadReferences: (_, _) => pending.future,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Pilih label tercatat'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      pending.completeError(Exception('Disconnected'));
      await tester.pumpAndSettle();
      expect(controller.text, 'KEEP');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('retest is locked and never loads suggestions', (tester) async {
    final controller = TextEditingController(text: 'ORIGINAL');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoutineSampleReferenceField(
            controller: controller,
            enabled: true,
            locked: true,
            loadReferences: (_, _) async =>
                throw StateError('Must not load for retest'),
          ),
        ),
      ),
    );
    expect(find.text('Pilih label tercatat'), findsNothing);
    expect(find.text('Isi manual'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    expect(controller.text, 'ORIGINAL');
  });
}
