import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_lab/app/theme/app_theme.dart';
import 'package:plant_lab/features/lab_request/presentation/soft_launch_guide_screen.dart';
import 'package:plant_lab/features/lab_request/presentation/workflow_presentation.dart';

void main() {
  test(
    'report is explicit unsent text with report time, not a physical test event',
    () {
      final text = softLaunchReport(
        plant: true,
        roles: ['PLANT_OPERATOR'],
        sites: 'PRASAD',
        priority: 'P0 - Risiko data / akses',
        lot: ' DEMO-RR-0002 ',
        request: '',
        steps: 'periksa tampilan',
        expected: 'angka asli',
        actual: 'perlu diperiksa',
        reportedAt: DateTime.utc(2026, 11, 12, 1, 2),
      );
      expect(text, contains('Lot: DEMO-RR-0002'));
      expect(text, contains('Batch: SL-20261112'));
      expect(text, contains('Waktu laporan: 2026-11-12T01:02:00.000Z'));
      expect(text, contains('belum dikirim atau disimpan ke server'));
      expect(text, isNot(contains('started_at')));
      expect(text, isNot(contains('@advantaindonesia.com')));
    },
  );
  for (final role in [
    'PLANT_OPERATOR',
    'PLANT_SPV',
    'PLANT_PI',
    'LAB_ANALYST',
    'LAB_QA_APPROVER',
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        'guide $role narrow 150% ${dark ? 'dark' : 'light'} prepares local report only',
        (tester) async {
          tester.view.physicalSize = const Size(320, 850);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          String? copied;
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            (call) async {
              if (call.method == 'Clipboard.setData') {
                copied = (call.arguments as Map)['text'] as String;
              }
              return null;
            },
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(SystemChannels.platform, null),
          );
          final plant = role.startsWith('PLANT');
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.dark : AppTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.5)),
                child: child!,
              ),
              home: SoftLaunchGuideScreen(
                plant: plant,
                roles: [role],
                sites: plant ? 'PRASAD' : 'LAB-PASURUAN',
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(workflowRoleGuide(plant, [role]).title),
            findsOneWidget,
          );
          final lot = find.byWidgetPredicate(
            (w) =>
                w is TextField && w.decoration?.labelText == 'Kode lot terkait',
          );
          await tester.scrollUntilVisible(
            lot,
            300,
            maxScrolls: 150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.enterText(lot, 'MEMORY-REPORT-ONLY');
          final copy = find.text('Salin laporan kendala');
          await tester.scrollUntilVisible(
            copy,
            200,
            maxScrolls: 150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(copy);
          await tester.pumpAndSettle();
          expect(copied, contains('MEMORY-REPORT-ONLY'));
          expect(copied, contains('belum dikirim atau disimpan ke server'));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
