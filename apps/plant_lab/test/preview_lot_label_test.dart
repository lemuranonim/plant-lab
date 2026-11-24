import 'package:flutter_test/flutter_test.dart';
import 'package:plant_lab/features/lab_request/presentation/standalone_request_actions.dart';

void main() {
  test('short lot codes are not changed', () {
    expect(compactPreviewLotCode('PLN1B1003'), 'PLN1B1003');
  });

  test('long demo lot labels keep the distinguishing suffix', () {
    const original = 'TEST-HTTP-8c771ae2-f777-4b2c-837e-13da14408e87';
    final base = compactPreviewLotCode(original);
    final write = compactPreviewLotCode('$original-WRITE');
    expect(base, endsWith('14408e87'));
    expect(write, endsWith('14408e87-WRITE'));
    expect(write, isNot(base));
    expect(write.runes.length, lessThanOrEqualTo(24));
  });
}
