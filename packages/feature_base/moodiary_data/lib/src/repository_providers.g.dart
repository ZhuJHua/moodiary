// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'repository_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 仓储的薄 provider 桥。仓储本体仍是进程级静态单例（刻意不进容器，见本包
/// CLAUDE.md），这一层是测试 override 的唯一抓手：
/// `diaryRepositoryProvider.overrideWithValue(DiaryRepository.forTesting(isar))`。
/// controller / provider 一律经这里取仓储，别再直接 `XxxRepository.get()`。

@ProviderFor(diaryRepository)
final diaryRepositoryProvider = DiaryRepositoryProvider._();

/// 仓储的薄 provider 桥。仓储本体仍是进程级静态单例（刻意不进容器，见本包
/// CLAUDE.md），这一层是测试 override 的唯一抓手：
/// `diaryRepositoryProvider.overrideWithValue(DiaryRepository.forTesting(isar))`。
/// controller / provider 一律经这里取仓储，别再直接 `XxxRepository.get()`。

final class DiaryRepositoryProvider
    extends
        $FunctionalProvider<DiaryRepository, DiaryRepository, DiaryRepository>
    with $Provider<DiaryRepository> {
  /// 仓储的薄 provider 桥。仓储本体仍是进程级静态单例（刻意不进容器，见本包
  /// CLAUDE.md），这一层是测试 override 的唯一抓手：
  /// `diaryRepositoryProvider.overrideWithValue(DiaryRepository.forTesting(isar))`。
  /// controller / provider 一律经这里取仓储，别再直接 `XxxRepository.get()`。
  DiaryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'diaryRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$diaryRepositoryHash();

  @$internal
  @override
  $ProviderElement<DiaryRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DiaryRepository create(Ref ref) {
    return diaryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DiaryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DiaryRepository>(value),
    );
  }
}

String _$diaryRepositoryHash() => r'0a8f69e891db403433805efcbc87f4baaa4c91dc';

@ProviderFor(categoryRepository)
final categoryRepositoryProvider = CategoryRepositoryProvider._();

final class CategoryRepositoryProvider
    extends
        $FunctionalProvider<
          CategoryRepository,
          CategoryRepository,
          CategoryRepository
        >
    with $Provider<CategoryRepository> {
  CategoryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoryRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoryRepositoryHash();

  @$internal
  @override
  $ProviderElement<CategoryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CategoryRepository create(Ref ref) {
    return categoryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CategoryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CategoryRepository>(value),
    );
  }
}

String _$categoryRepositoryHash() =>
    r'41d7a2e0008d369402d968cb7a9b71cab64da2ba';

@ProviderFor(mediaInfoRepository)
final mediaInfoRepositoryProvider = MediaInfoRepositoryProvider._();

final class MediaInfoRepositoryProvider
    extends
        $FunctionalProvider<
          MediaInfoRepository,
          MediaInfoRepository,
          MediaInfoRepository
        >
    with $Provider<MediaInfoRepository> {
  MediaInfoRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaInfoRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaInfoRepositoryHash();

  @$internal
  @override
  $ProviderElement<MediaInfoRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MediaInfoRepository create(Ref ref) {
    return mediaInfoRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MediaInfoRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MediaInfoRepository>(value),
    );
  }
}

String _$mediaInfoRepositoryHash() =>
    r'267bb10ce80855048e3a911ecf330b5384086f69';

@ProviderFor(fontRepository)
final fontRepositoryProvider = FontRepositoryProvider._();

final class FontRepositoryProvider
    extends $FunctionalProvider<FontRepository, FontRepository, FontRepository>
    with $Provider<FontRepository> {
  FontRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fontRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fontRepositoryHash();

  @$internal
  @override
  $ProviderElement<FontRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FontRepository create(Ref ref) {
    return fontRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FontRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FontRepository>(value),
    );
  }
}

String _$fontRepositoryHash() => r'b83e5e0e3f34fa9b83d91d37fff83846a3b4187d';

@ProviderFor(tombstoneRepository)
final tombstoneRepositoryProvider = TombstoneRepositoryProvider._();

final class TombstoneRepositoryProvider
    extends
        $FunctionalProvider<
          TombstoneRepository,
          TombstoneRepository,
          TombstoneRepository
        >
    with $Provider<TombstoneRepository> {
  TombstoneRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tombstoneRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tombstoneRepositoryHash();

  @$internal
  @override
  $ProviderElement<TombstoneRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TombstoneRepository create(Ref ref) {
    return tombstoneRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TombstoneRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TombstoneRepository>(value),
    );
  }
}

String _$tombstoneRepositoryHash() =>
    r'1dfbe81b81f9755daf2fcea7480bd1c363df40dc';
