// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'storage_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(kvStorage)
final kvStorageProvider = KvStorageProvider._();

final class KvStorageProvider
    extends $FunctionalProvider<IKVStorage, IKVStorage, IKVStorage>
    with $Provider<IKVStorage> {
  KvStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'kvStorageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$kvStorageHash();

  @$internal
  @override
  $ProviderElement<IKVStorage> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  IKVStorage create(Ref ref) {
    return kvStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IKVStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IKVStorage>(value),
    );
  }
}

String _$kvStorageHash() => r'6a61d647369b3f5064d07fe4908b0f13aad3f7f3';

@ProviderFor(secureKvStorage)
final secureKvStorageProvider = SecureKvStorageProvider._();

final class SecureKvStorageProvider
    extends
        $FunctionalProvider<
          ISecureKVStorage,
          ISecureKVStorage,
          ISecureKVStorage
        >
    with $Provider<ISecureKVStorage> {
  SecureKvStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'secureKvStorageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$secureKvStorageHash();

  @$internal
  @override
  $ProviderElement<ISecureKVStorage> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ISecureKVStorage create(Ref ref) {
    return secureKvStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ISecureKVStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ISecureKVStorage>(value),
    );
  }
}

String _$secureKvStorageHash() => r'f35b7e033bd733c4b857ed7074a14206841982c2';

@ProviderFor(kvValue)
final kvValueProvider = KvValueFamily._();

final class KvValueProvider<T extends Object>
    extends $FunctionalProvider<T, T, T>
    with $Provider<T> {
  KvValueProvider._({
    required KvValueFamily super.from,
    required MoodiaryKVs<T> super.argument,
  }) : super(
         retry: null,
         name: r'kvValueProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$kvValueHash();

  @override
  String toString() {
    return r'kvValueProvider'
        '<${T}>'
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<T> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  T create(Ref ref) {
    final argument = this.argument as MoodiaryKVs<T>;
    return kvValue<T>(ref, argument);
  }

  $R _captureGenerics<$R>($R Function<T extends Object>() cb) {
    return cb<T>();
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(T value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<T>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is KvValueProvider &&
        other.runtimeType == runtimeType &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return Object.hash(runtimeType, argument);
  }
}

String _$kvValueHash() => r'9f3f9c032b2262beeb81217c2fdbf69b86d81448';

final class KvValueFamily extends $Family {
  KvValueFamily._()
    : super(
        retry: null,
        name: r'kvValueProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  KvValueProvider<T> call<T extends Object>(MoodiaryKVs<T> key) =>
      KvValueProvider<T>._(argument: key, from: this);

  @override
  String toString() => r'kvValueProvider';

  /// {@macro riverpod.override_with}
  Override overrideWith(
    T Function<T extends Object>(Ref ref, MoodiaryKVs<T> args) create,
  ) => $FamilyOverride(
    from: this,
    createElement: (pointer) {
      final provider = pointer.origin as KvValueProvider;
      return provider._captureGenerics(<T extends Object>() {
        provider as KvValueProvider<T>;
        final argument = provider.argument as MoodiaryKVs<T>;
        return provider
            .$view(create: (ref) => create(ref, argument))
            .$createElement(pointer);
      });
    },
  );
}

@ProviderFor(kvValueOr)
final kvValueOrProvider = KvValueOrFamily._();

final class KvValueOrProvider<T extends Object>
    extends $FunctionalProvider<T, T, T>
    with $Provider<T> {
  KvValueOrProvider._({
    required KvValueOrFamily super.from,
    required (MoodiaryKVs<T>, T) super.argument,
  }) : super(
         retry: null,
         name: r'kvValueOrProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$kvValueOrHash();

  @override
  String toString() {
    return r'kvValueOrProvider'
        '<${T}>'
        '$argument';
  }

  @$internal
  @override
  $ProviderElement<T> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  T create(Ref ref) {
    final argument = this.argument as (MoodiaryKVs<T>, T);
    return kvValueOr<T>(ref, argument.$1, argument.$2);
  }

  $R _captureGenerics<$R>($R Function<T extends Object>() cb) {
    return cb<T>();
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(T value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<T>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is KvValueOrProvider &&
        other.runtimeType == runtimeType &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return Object.hash(runtimeType, argument);
  }
}

String _$kvValueOrHash() => r'93dfe77f3bebdf3034a4a60d1dd559b7a4a6408d';

final class KvValueOrFamily extends $Family {
  KvValueOrFamily._()
    : super(
        retry: null,
        name: r'kvValueOrProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  KvValueOrProvider<T> call<T extends Object>(MoodiaryKVs<T> key, T fallback) =>
      KvValueOrProvider<T>._(argument: (key, fallback), from: this);

  @override
  String toString() => r'kvValueOrProvider';

  /// {@macro riverpod.override_with}
  Override overrideWith(
    T Function<T extends Object>(Ref ref, (MoodiaryKVs<T>, T) args) create,
  ) => $FamilyOverride(
    from: this,
    createElement: (pointer) {
      final provider = pointer.origin as KvValueOrProvider;
      return provider._captureGenerics(<T extends Object>() {
        provider as KvValueOrProvider<T>;
        final argument = provider.argument as (MoodiaryKVs<T>, T);
        return provider
            .$view(create: (ref) => create(ref, argument))
            .$createElement(pointer);
      });
    },
  );
}

@ProviderFor(appLockEnabled)
final appLockEnabledProvider = AppLockEnabledProvider._();

final class AppLockEnabledProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  AppLockEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appLockEnabledProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appLockEnabledHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return appLockEnabled(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$appLockEnabledHash() => r'24658be5c92cd6183c6dcbbb55dc9db5a5c6882f';
