// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plant_plan_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$plantPlanRepositoryHash() =>
    r'f1b152bb21fb46d13fc4f06ee4622ed0a62fc135';

/// See also [plantPlanRepository].
@ProviderFor(plantPlanRepository)
final plantPlanRepositoryProvider =
    AutoDisposeProvider<PlantPlanRepository>.internal(
      plantPlanRepository,
      name: r'plantPlanRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$plantPlanRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PlantPlanRepositoryRef = AutoDisposeProviderRef<PlantPlanRepository>;
String _$plantPlanDetailHash() => r'4d416ca5cff3267f783471bcf296159522f7080d';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [plantPlanDetail].
@ProviderFor(plantPlanDetail)
const plantPlanDetailProvider = PlantPlanDetailFamily();

/// See also [plantPlanDetail].
class PlantPlanDetailFamily extends Family<AsyncValue<PlantPlan>> {
  /// See also [plantPlanDetail].
  const PlantPlanDetailFamily();

  /// See also [plantPlanDetail].
  PlantPlanDetailProvider call(String planId) {
    return PlantPlanDetailProvider(planId);
  }

  @override
  PlantPlanDetailProvider getProviderOverride(
    covariant PlantPlanDetailProvider provider,
  ) {
    return call(provider.planId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'plantPlanDetailProvider';
}

/// See also [plantPlanDetail].
class PlantPlanDetailProvider extends AutoDisposeFutureProvider<PlantPlan> {
  /// See also [plantPlanDetail].
  PlantPlanDetailProvider(String planId)
    : this._internal(
        (ref) => plantPlanDetail(ref as PlantPlanDetailRef, planId),
        from: plantPlanDetailProvider,
        name: r'plantPlanDetailProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$plantPlanDetailHash,
        dependencies: PlantPlanDetailFamily._dependencies,
        allTransitiveDependencies:
            PlantPlanDetailFamily._allTransitiveDependencies,
        planId: planId,
      );

  PlantPlanDetailProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.planId,
  }) : super.internal();

  final String planId;

  @override
  Override overrideWith(
    FutureOr<PlantPlan> Function(PlantPlanDetailRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PlantPlanDetailProvider._internal(
        (ref) => create(ref as PlantPlanDetailRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        planId: planId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<PlantPlan> createElement() {
    return _PlantPlanDetailProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PlantPlanDetailProvider && other.planId == planId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, planId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PlantPlanDetailRef on AutoDisposeFutureProviderRef<PlantPlan> {
  /// The parameter `planId` of this provider.
  String get planId;
}

class _PlantPlanDetailProviderElement
    extends AutoDisposeFutureProviderElement<PlantPlan>
    with PlantPlanDetailRef {
  _PlantPlanDetailProviderElement(super.provider);

  @override
  String get planId => (origin as PlantPlanDetailProvider).planId;
}

String _$plantProcessStepsHash() => r'041d71b41e0c1900e1f9f01248114fa656754e0a';

/// See also [plantProcessSteps].
@ProviderFor(plantProcessSteps)
const plantProcessStepsProvider = PlantProcessStepsFamily();

/// See also [plantProcessSteps].
class PlantProcessStepsFamily
    extends Family<AsyncValue<List<PlantProcessStep>>> {
  /// See also [plantProcessSteps].
  const PlantProcessStepsFamily();

  /// See also [plantProcessSteps].
  PlantProcessStepsProvider call(String planId) {
    return PlantProcessStepsProvider(planId);
  }

  @override
  PlantProcessStepsProvider getProviderOverride(
    covariant PlantProcessStepsProvider provider,
  ) {
    return call(provider.planId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'plantProcessStepsProvider';
}

/// See also [plantProcessSteps].
class PlantProcessStepsProvider
    extends AutoDisposeFutureProvider<List<PlantProcessStep>> {
  /// See also [plantProcessSteps].
  PlantProcessStepsProvider(String planId)
    : this._internal(
        (ref) => plantProcessSteps(ref as PlantProcessStepsRef, planId),
        from: plantProcessStepsProvider,
        name: r'plantProcessStepsProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$plantProcessStepsHash,
        dependencies: PlantProcessStepsFamily._dependencies,
        allTransitiveDependencies:
            PlantProcessStepsFamily._allTransitiveDependencies,
        planId: planId,
      );

  PlantProcessStepsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.planId,
  }) : super.internal();

  final String planId;

  @override
  Override overrideWith(
    FutureOr<List<PlantProcessStep>> Function(PlantProcessStepsRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PlantProcessStepsProvider._internal(
        (ref) => create(ref as PlantProcessStepsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        planId: planId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<PlantProcessStep>> createElement() {
    return _PlantProcessStepsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PlantProcessStepsProvider && other.planId == planId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, planId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PlantProcessStepsRef
    on AutoDisposeFutureProviderRef<List<PlantProcessStep>> {
  /// The parameter `planId` of this provider.
  String get planId;
}

class _PlantProcessStepsProviderElement
    extends AutoDisposeFutureProviderElement<List<PlantProcessStep>>
    with PlantProcessStepsRef {
  _PlantProcessStepsProviderElement(super.provider);

  @override
  String get planId => (origin as PlantProcessStepsProvider).planId;
}

String _$plantPlanListNotifierHash() =>
    r'84ad0f11f817400f9754127014a19c9c2a25a72a';

/// See also [PlantPlanListNotifier].
@ProviderFor(PlantPlanListNotifier)
final plantPlanListNotifierProvider =
    AutoDisposeAsyncNotifierProvider<
      PlantPlanListNotifier,
      List<PlantPlanSummary>
    >.internal(
      PlantPlanListNotifier.new,
      name: r'plantPlanListNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$plantPlanListNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$PlantPlanListNotifier =
    AutoDisposeAsyncNotifier<List<PlantPlanSummary>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
