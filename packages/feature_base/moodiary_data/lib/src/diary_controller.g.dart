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
    extends $AsyncNotifierProvider<DiaryController, List<Diary>> {
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

String _$diaryControllerHash() => r'1ec0634998c20f62d500c52cc888e8bf45feb524';

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

String _$recycleBinDiariesHash() => r'1da1572e21567036a215095dd7ccea7cb42f7fd6';

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
