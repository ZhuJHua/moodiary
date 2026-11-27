// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diary_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DiaryController)
final diaryControllerProvider = DiaryControllerFamily._();

final class DiaryControllerProvider
    extends $AsyncNotifierProvider<DiaryController, DiaryListState> {
  DiaryControllerProvider._({
    required DiaryControllerFamily super.from,
    required ({String? categoryId, bool uncategorized, String? tagName})
    super.argument,
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

String _$diaryControllerHash() => r'a1d5dc4c047a19242a844d768fef2b7186c99e2e';

final class DiaryControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          DiaryController,
          AsyncValue<DiaryListState>,
          DiaryListState,
          FutureOr<DiaryListState>,
          ({String? categoryId, bool uncategorized, String? tagName})
        > {
  DiaryControllerFamily._()
    : super(
        retry: null,
        name: r'diaryControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  DiaryControllerProvider call({
    String? categoryId,
    bool uncategorized = false,
    String? tagName,
  }) => DiaryControllerProvider._(
    argument: (
      categoryId: categoryId,
      uncategorized: uncategorized,
      tagName: tagName,
    ),
    from: this,
  );

  @override
  String toString() => r'diaryControllerProvider';
}

abstract class _$DiaryController extends $AsyncNotifier<DiaryListState> {
  late final _$args =
      ref.$arg as ({String? categoryId, bool uncategorized, String? tagName});
  String? get categoryId => _$args.categoryId;
  bool get uncategorized => _$args.uncategorized;
  String? get tagName => _$args.tagName;

  FutureOr<DiaryListState> build({
    String? categoryId,
    bool uncategorized = false,
    String? tagName,
  });
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<DiaryListState>, DiaryListState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<DiaryListState>, DiaryListState>,
              AsyncValue<DiaryListState>,
              Object?,
              Object?
            >;
    return element.handleCreate(
      ref,
      () => build(
        categoryId: _$args.categoryId,
        uncategorized: _$args.uncategorized,
        tagName: _$args.tagName,
      ),
    );
  }
}

@ProviderFor(RecycleBinDiaries)
final recycleBinDiariesProvider = RecycleBinDiariesProvider._();

final class RecycleBinDiariesProvider
    extends $AsyncNotifierProvider<RecycleBinDiaries, List<Diary>> {
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

String _$recycleBinDiariesHash() => r'd99666be68513cffa2958779cc7d4f09a99a9636';

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
