// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lot_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$lotRepositoryHash() => r'35049570f82a59f14b615283e6c671148d1ff076';

/// See also [lotRepository].
@ProviderFor(lotRepository)
final lotRepositoryProvider = AutoDisposeProvider<LotRepository>.internal(
  lotRepository,
  name: r'lotRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$lotRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LotRepositoryRef = AutoDisposeProviderRef<LotRepository>;
String _$lotDetailHash() => r'051750c6a512259336cb5036a117d276b739cd02';

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

/// See also [lotDetail].
@ProviderFor(lotDetail)
const lotDetailProvider = LotDetailFamily();

/// See also [lotDetail].
class LotDetailFamily extends Family<AsyncValue<Lot>> {
  /// See also [lotDetail].
  const LotDetailFamily();

  /// See also [lotDetail].
  LotDetailProvider call(String lotId) {
    return LotDetailProvider(lotId);
  }

  @override
  LotDetailProvider getProviderOverride(covariant LotDetailProvider provider) {
    return call(provider.lotId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'lotDetailProvider';
}

/// See also [lotDetail].
class LotDetailProvider extends AutoDisposeFutureProvider<Lot> {
  /// See also [lotDetail].
  LotDetailProvider(String lotId)
    : this._internal(
        (ref) => lotDetail(ref as LotDetailRef, lotId),
        from: lotDetailProvider,
        name: r'lotDetailProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$lotDetailHash,
        dependencies: LotDetailFamily._dependencies,
        allTransitiveDependencies: LotDetailFamily._allTransitiveDependencies,
        lotId: lotId,
      );

  LotDetailProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.lotId,
  }) : super.internal();

  final String lotId;

  @override
  Override overrideWith(FutureOr<Lot> Function(LotDetailRef provider) create) {
    return ProviderOverride(
      origin: this,
      override: LotDetailProvider._internal(
        (ref) => create(ref as LotDetailRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        lotId: lotId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Lot> createElement() {
    return _LotDetailProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LotDetailProvider && other.lotId == lotId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, lotId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin LotDetailRef on AutoDisposeFutureProviderRef<Lot> {
  /// The parameter `lotId` of this provider.
  String get lotId;
}

class _LotDetailProviderElement extends AutoDisposeFutureProviderElement<Lot>
    with LotDetailRef {
  _LotDetailProviderElement(super.provider);

  @override
  String get lotId => (origin as LotDetailProvider).lotId;
}

String _$lotListNotifierHash() => r'4605f54a17d3d02d7d6c2a7247c3e0d67b4e340d';

/// See also [LotListNotifier].
@ProviderFor(LotListNotifier)
final lotListNotifierProvider =
    AutoDisposeAsyncNotifierProvider<
      LotListNotifier,
      List<LotSummary>
    >.internal(
      LotListNotifier.new,
      name: r'lotListNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$lotListNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$LotListNotifier = AutoDisposeAsyncNotifier<List<LotSummary>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
