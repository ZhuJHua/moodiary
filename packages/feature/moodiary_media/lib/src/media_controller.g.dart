// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MediaItems)
final mediaItemsProvider = MediaItemsFamily._();

final class MediaItemsProvider
    extends $AsyncNotifierProvider<MediaItems, List<MediaItem>> {
  MediaItemsProvider._({
    required MediaItemsFamily super.from,
    required MediaType super.argument,
  }) : super(
         retry: null,
         name: r'mediaItemsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mediaItemsHash();

  @override
  String toString() {
    return r'mediaItemsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MediaItems create() => MediaItems();

  @override
  bool operator ==(Object other) {
    return other is MediaItemsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mediaItemsHash() => r'edbb801306abd0254b08319471e4057f6fb0584b';

final class MediaItemsFamily extends $Family
    with
        $ClassFamilyOverride<
          MediaItems,
          AsyncValue<List<MediaItem>>,
          List<MediaItem>,
          FutureOr<List<MediaItem>>,
          MediaType
        > {
  MediaItemsFamily._()
    : super(
        retry: null,
        name: r'mediaItemsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MediaItemsProvider call({required MediaType type}) =>
      MediaItemsProvider._(argument: type, from: this);

  @override
  String toString() => r'mediaItemsProvider';
}

abstract class _$MediaItems extends $AsyncNotifier<List<MediaItem>> {
  late final _$args = ref.$arg as MediaType;
  MediaType get type => _$args;

  FutureOr<List<MediaItem>> build({required MediaType type});
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<MediaItem>>, List<MediaItem>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<MediaItem>>, List<MediaItem>>,
              AsyncValue<List<MediaItem>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(type: _$args));
  }
}

@ProviderFor(MediaCleanupController)
final mediaCleanupControllerProvider = MediaCleanupControllerProvider._();

final class MediaCleanupControllerProvider
    extends $NotifierProvider<MediaCleanupController, void> {
  MediaCleanupControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaCleanupControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaCleanupControllerHash();

  @$internal
  @override
  MediaCleanupController create() => MediaCleanupController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$mediaCleanupControllerHash() =>
    r'64e5cff97a19df503a65ea26778e9bf4552d846a';

abstract class _$MediaCleanupController extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
