import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_lab/app/theme/lab_theme.dart';
import 'package:plant_lab/features/lab_request/presentation/lab_workspace_widgets.dart';

void main() {
  testWidgets('help is opt-in and shortcut scrolls without submitting', (
    tester,
  ) async {
    final section = GlobalKey();
    const guidance = 'Penjelasan hanya terlihat jika bantuan dibuka.';
    int saves = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: LabTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                LabFormSections(
                  sections: const ['Ke tombol simpan'],
                  targets: [section],
                ),
                const LabHelp(text: guidance),
                const SizedBox(height: 1300),
                FilledButton(
                  key: section,
                  onPressed: () => saves++,
                  child: const Text('Simpan draft'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text(guidance), findsNothing);
    await tester.tap(find.text('Bantuan singkat'));
    await tester.pumpAndSettle();
    expect(find.text(guidance), findsOneWidget);
    await tester.tap(find.text('Tutup bantuan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ke tombol simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Simpan draft').hitTestable(), findsOneWidget);
    expect(saves, isZero);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'number grid keeps zero and blank when reflowing for large text',
    (tester) async {
      final width = ValueNotifier<double>(372);
      final scale = ValueNotifier<double>(1);
      addTearDown(width.dispose);
      addTearDown(scale.dispose);
      const first = ValueKey('first-reading');
      const second = ValueKey('second-reading');
      await tester.pumpWidget(
        MaterialApp(
          theme: LabTheme.light,
          home: Scaffold(
            body: Center(
              child: ListenableBuilder(
                listenable: Listenable.merge([width, scale]),
                builder: (context, _) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale.value)),
                  child: SizedBox(
                    width: width.value,
                    child: const LabFormCard(
                      title: 'Pengamatan',
                      icon: Icons.grass_outlined,
                      children: [
                        LabFieldGrid(
                          fields: [
                            TextField(
                              key: first,
                              keyboardType: TextInputType.number,
                            ),
                            TextField(
                              key: second,
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final a = find.byKey(first);
      final b = find.byKey(second);
      expect(tester.getTopLeft(a).dy, tester.getTopLeft(b).dy);
      await tester.enterText(a, '0');
      width.value = 288;
      scale.value = 1.5;
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(a).dy, lessThan(tester.getTopLeft(b).dy));
      final editors = find.byType(EditableText);
      expect(tester.widget<EditableText>(editors.at(0)).controller.text, '0');
      expect(
        tester.widget<EditableText>(editors.at(1)).controller.text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
