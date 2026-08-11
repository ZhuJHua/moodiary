// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diary_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 按 [categoryId] 维度的日记列表（`categoryId == null` 表示「全部分类」）。
/// 订阅 [DiaryRepository.diaryEvents] 按事件原地增量更新，无需重查库。

@ProviderFor(DiaryController)
final diaryControllerProvider = DiaryControllerFamily._();

/// 按 [categoryId] 维度的日记列表（`categoryId == null` 表示「全部分类」）。
/// 订阅 [DiaryRepository.diaryEvents] 按事件原地增量更新，无需重查库。
final class DiaryControllerProvider
    extends $AsyncNotifierProvider<DiaryController, List<Diary>> {
  /// 按 [categoryId] 维度的日记列表（`categoryId == null` 表示「全部分类」）。
  /// 订阅 [DiaryRepository.diaryEvents] 按事件原地增量更新，无需重查库。
  DiaryControllerProvider._({
    required DiaryControllerFamily super.from,
    required ({String? categoryId, bool uncategorized}) super.argument,
  }) : super(
         retry: null,
         name: r'diaryControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$diaryControllerHash();

  @override
  String toString() {
    return r'diaryControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  DiaryController create() => DiaryController();

  @override
  bool operator ==(Object other) {
    return other is DiaryControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$diaryControllerHash() => r'2d73f9d6641f6b9de29ac8fc4835d16590b6082c';

/// 按 [categoryId] 维度的日记列表（`categoryId == null` 表示「全部分类」）。
/// 订阅 [DiaryRepository.diaryEvents] 按事件原地增量更新，无需重查库。

final class DiaryControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          DiaryController,
          AsyncValue<List<Diary>>,
          List<Diary>,
          FutureOr<List<Diary>>,
          ({String? categoryId, bool uncategorized})
        > {
  DiaryControllerFamily._()
    : super(
        retry: null,
        name: r'diaryControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 按 [categoryId] 维度的日记列表（`categoryId == null` 表示「全部分类」）。
  /// 订阅 [DiaryRepository.diaryEvents] 按事件原地增量更新，无需重查库。

  DiaryControllerProvider call({
    String? categoryId,
    bool uncategorized = false,
  }) => DiaryControllerProvider._(
    argument: (categoryId: categoryId, uncategorized: uncategorized),
    from: this,
  );

  @override
  String toString() => r'diaryControllerProvider';
}

/// 按 [categoryId] 维度的日记列表（`categoryId == null` 表示「全部分类」）。
/// 订阅 [DiaryRepository.diaryEvents] 按事件原地增量更新，无需重查库。

abstract class _$DiaryController extends $AsyncNotifier<List<Diary>> {
  late final _$args = ref.$arg as ({String? categoryId, bool uncategorized});
  String? get categoryId => _$args.categoryId;
  bool get uncategorized => _$args.uncategorized;

  FutureOr<List<Diary>> build({String? categoryId, bool uncategorized = false});
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Diary>>, List<Diary>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Diary>>, List<Diary>>,
              AsyncValue<List<Diary>>,
              Object?,
              Object?
            >;
    return element.handleCreate(
      ref,
      () => build(
        categoryId: _$args.categoryId,
        uncategorized: _$args.uncategorized,
      ),
    );
  }
}

/// 回收站列表（按时间倒序的所有 `show == false` 的日记）。

@ProviderFor(RecycleBinDiaries)
final recycleBinDiariesProvider = RecycleBinDiariesProvider._();

/// 回收站列表（按时间倒序的所有 `show == false` 的日记）。
final class RecycleBinDiariesProvider
    extends $AsyncNotifierProvider<RecycleBinDiaries, List<Diary>> {
  /// 回收站列表（按时间倒序的所有 `show == false` 的日记）。
  RecycleBinDiariesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recycleBinDiariesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recycleBinDiariesHash();

  @$internal
  @override
  RecycleBinDiaries create() => RecycleBinDiaries();
}

String _$recycleBinDiariesHash() => r'8d224e8f5176732c3c59183eaa0e36b4cef69895';

/// 回收站列表（按时间倒序的所有 `show == false` 的日记）。

abstract class _$RecycleBinDiaries extends $AsyncNotifier<List<Diary>> {
  FutureOr<List<Diary>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Diary>>, List<Diary>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Diary>>, List<Diary>>,
              AsyncValue<List<Diary>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 取单条日记的「活动流」：实时跟随 [DiaryRepository.watchDiary]，彻底删除时发出 `null`。
/// id 为空发出空模板用于「新建」，此时务必显式传 [defaultType]，否则无法确定 markdown /
/// richText。

@ProviderFor(getDiary)
final getDiaryProvider = GetDiaryFamily._();

/// 取单条日记的「活动流」：实时跟随 [DiaryRepository.watchDiary]，彻底删除时发出 `null`。
/// id 为空发出空模板用于「新建」，此时务必显式传 [defaultType]，否则无法确定 markdown /
/// richText。

final class GetDiaryProvider
    extends $FunctionalProvider<AsyncValue<Diary?>, Diary?, Stream<Diary?>>
    with $FutureModifier<Diary?>, $StreamProvider<Diary?> {
  /// 取单条日记的「活动流」：实时跟随 [DiaryRepository.watchDiary]，彻底删除时发出 `null`。
  /// id 为空发出空模板用于「新建」，此时务必显式传 [defaultType]，否则无法确定 markdown /
  /// richText。
  GetDiaryProvider._({
    required GetDiaryFamily super.from,
    required ({String? id, DiaryType? defaultType, String? defaultCategoryId})
    super.argument,
  }) : super(
         retry: null,
         name: r'getDiaryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$getDiaryHash();

  @override
  String toString() {
    return r'getDiaryProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<Diary?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Diary?> create(Ref ref) {
    final argument =
        this.argument
            as ({
              String? id,
              DiaryType? defaultType,
              String? defaultCategoryId,
            });
    return getDiary(
      ref,
      id: argument.id,
      defaultType: argument.defaultType,
      defaultCategoryId: argument.defaultCategoryId,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GetDiaryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$getDiaryHash() => r'de135055669617d1afc970274b85806e5acd4117';

/// 取单条日记的「活动流」：实时跟随 [DiaryRepository.watchDiary]，彻底删除时发出 `null`。
/// id 为空发出空模板用于「新建」，此时务必显式传 [defaultType]，否则无法确定 markdown /
/// richText。

final class GetDiaryFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<Diary?>,
          ({String? id, DiaryType? defaultType, String? defaultCategoryId})
        > {
  GetDiaryFamily._()
    : super(
        retry: null,
        name: r'getDiaryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 取单条日记的「活动流」：实时跟随 [DiaryRepository.watchDiary]，彻底删除时发出 `null`。
  /// id 为空发出空模板用于「新建」，此时务必显式传 [defaultType]，否则无法确定 markdown /
  /// richText。

  GetDiaryProvider call({
    String? id,
    DiaryType? defaultType,
    String? defaultCategoryId,
  }) => GetDiaryProvider._(
    argument: (
      id: id,
      defaultType: defaultType,
      defaultCategoryId: defaultCategoryId,
    ),
    from: this,
  );

  @override
  String toString() => r'getDiaryProvider';
}
