import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plant_lab/plant_lab_app.dart';

void main() {
  testWidgets('App initializes correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: PlantLabApp(),
      ),
    );
    expect(find.byType(PlantLabApp), findsOneWidget);
  });
}
