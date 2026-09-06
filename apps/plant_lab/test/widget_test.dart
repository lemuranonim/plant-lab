import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plant_lab/plant_lab_app.dart';
import 'package:plant_lab/core/config/app_variant.dart';

void main() {
  testWidgets('App initializes correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appVariantProvider.overrideWithValue(AppVariant.lab)],
        child: const PlantLabApp(),
      ),
    );
    expect(find.byType(PlantLabApp), findsOneWidget);
  });
}
