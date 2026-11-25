// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(moodiaryDatabaseAsync)
final moodiaryDatabaseAsyncProvider = MoodiaryDatabaseAsyncProvider._();

final class MoodiaryDatabaseAsyncProvider
    extends
        $FunctionalProvider<
          AsyncValue<MoodiaryDatabase>,
          MoodiaryDatabase,
          FutureOr<MoodiaryDatabase>
        >
    with $FutureModifier<MoodiaryDatabase>, $FutureProvider<MoodiaryDatabase> {
  MoodiaryDatabaseAsyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'moodiaryDatabaseAsyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$moodiaryDatabaseAsyncHash();

  @$internal
  @override
  $FutureProviderElement<MoodiaryDatabase> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MoodiaryDatabase> create(Ref ref) {
    return moodiaryDatabaseAsync(ref);
  }
}

String _$moodiaryDatabaseAsyncHash() =>
    r'd74635968c8b2be462c336e330cee678f162391a';

@ProviderFor(moodiaryDatabase)
final moodiaryDatabaseProvider = MoodiaryDatabaseProvider._();

final class MoodiaryDatabaseProvider
    extends
        $FunctionalProvider<
          MoodiaryDatabase,
          MoodiaryDatabase,
          MoodiaryDatabase
        >
    with $Provider<MoodiaryDatabase> {
  MoodiaryDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'moodiaryDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$moodiaryDatabaseHash();

  @$internal
  @override
  $ProviderElement<MoodiaryDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MoodiaryDatabase create(Ref ref) {
    return moodiaryDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MoodiaryDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MoodiaryDatabase>(value),
    );
  }
}

String _$moodiaryDatabaseHash() => r'd443de6363fe6a7b97e78df11faa8fe526368dff';
