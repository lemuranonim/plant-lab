import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../access/access_context.dart';

enum AppVariant {
  plant,
  lab;

  String get code => switch (this) {
    AppVariant.plant => 'PLANT',
    AppVariant.lab => 'LAB',
  };

  String get appName => switch (this) {
    AppVariant.plant => 'Advanta Plant',
    AppVariant.lab => 'Advanta Lab',
  };

  String get moduleName => switch (this) {
    AppVariant.plant => 'Plant',
    AppVariant.lab => 'Lab',
  };

  String get tagline => switch (this) {
    AppVariant.plant => 'Plant Quality Operations',
    AppVariant.lab => 'Laboratory Quality Operations',
  };

  bool get isPlant => this == AppVariant.plant;
  bool get isLab => this == AppVariant.lab;

  bool allows(AccessContext access) => switch (this) {
    AppVariant.plant => access.canAccessPlant,
    AppVariant.lab => access.canAccessLab,
  };
}

final appVariantProvider = Provider<AppVariant>((ref) {
  throw StateError('An explicit Plant or Lab application variant is required.');
});
