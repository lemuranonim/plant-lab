import 'package:flutter_test/flutter_test.dart';
import 'package:plant_lab/core/config/app_config.dart';

void main() {
  test('operational writes are disabled by default', () {
    expect(AppConfig.operationalWritesEnabled, isFalse);
    expect(
      AppConfig.requireOperationalWritesEnabled,
      throwsA(isA<StateError>()),
    );
  });
}
