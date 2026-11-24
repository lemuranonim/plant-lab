import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_lab/app/theme/app_theme.dart';
import 'package:plant_lab/features/plant_inspection/presentation/pi_quality_screen.dart';
import 'package:plant_lab/features/plant_inspection/presentation/pi_tsw_weights.dart';
import 'pi_quality_test.dart' show options, record, reveal;

void main() {
  test('TSW workbook population CV,8x100basis, unknown and zero', () {
    final r = previewTsw([21.3, 20.9, 21.9, 22, 21.7, 21.5, 22.1, 22]);
    expect(r['tsw_g'], closeTo(216.75, 1e-10));
    expect(r['kernel_per_kg'], closeTo(1000000 / 216.75, 1e-8));
    expect(
      previewTsw([19.2, 19.2, 19.2, 19.2, 20.8, 20.8, 20.8, 20.8])['tsw_g'],
      200,
    );
    expect(
      previewTsw([
        19.1999999,
        19.1999999,
        19.1999999,
        19.1999999,
        20.8000001,
        20.8000001,
        20.8000001,
        20.8000001,
      ])['tsw_g'],
      isNull,
    );
    expect(
      previewTsw([20, 20, 20, 20, 20, 20, 20, null])['mean_100_g'],
      isNull,
    );
    expect(previewTsw(List.filled(8, 0))['calculation_state'], 'ZERO_MEAN');
    expect(tswNumber(100), '100');
    expect(tswNumber(null), 'Belum tersedia');
  });
  for (final dark in [false, true]) {
    testWidgets(
      'TSW8x100320px150percent ${dark ? 'dark' : 'light'} server draft retry',
      (tester) async {
        tester.view.physicalSize = const Size(320, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final calls = <Map<String, dynamic>>[],
            r = {
              ...record('TSW'),
              'tsw_raw': previewTsw([20, 20, 20, 20, 20, 20, 20, null]),
            };
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark : AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: PiTestForm(
              options: options(),
              record: r,
              saveAction: (payload) async {
                calls.add(Map.of(payload));
                if (calls.length == 1) throw Exception('offline');
                return {
                  ...r,
                  'row_version': 2,
                  'tsw_raw': previewTsw(List.filled(8, 20)),
                };
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        final field = find.widgetWithText(
          TextField,
          'Ulangan 8 · berat 100 benih (g)',
        );
        await reveal(tester, field);
        await tester.enterText(field, '20');
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(TextField, 'Nilai terukur (g per 1.000 benih)'),
          findsNothing,
        );
        final save = find.widgetWithText(OutlinedButton, 'Simpan draft PI');
        await reveal(tester, save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        await reveal(tester, save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(calls.length, 2);
        expect(calls[0], calls[1]);
        expect(calls.last['numeric_value'], isNull);
        expect(calls.last['tsw_weights'], List.filled(8, 20));
        expect(calls.last['seed_count'], 1000);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('TSW revision does not copy raw readings or actual time', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PiTestForm(
          options: options(),
          revision: true,
          record: {...record('TSW'), 'tsw_raw': previewTsw(List.filled(8, 20))},
        ),
      ),
    );
    final field = find.widgetWithText(
      TextField,
      'Ulangan 8 · berat 100 benih (g)',
    );
    await reveal(tester, field);
    final inputs = tester
        .widgetList<TextField>(find.byType(TextField))
        .where((w) => w.decoration?.labelText?.startsWith('Ulangan ') == true)
        .toList();
    expect(inputs.length, 8);
    expect(inputs.every((w) => w.controller!.text.isEmpty), isTrue);
    await reveal(
      tester,
      find.text('Pilih waktu pengukuran nyata'),
      delta: -250,
    );
    expect(find.text('Pilih waktu pengukuran nyata'), findsOneWidget);
  });
}
