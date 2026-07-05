// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 订阅 [CategoryRepository.categoryEvents]，按事件原地增量更新，无需重查库。

@ProviderFor(CategoryController)
final categoryControllerProvider = CategoryControllerProvider._();

/// 订阅 [CategoryRepository.categoryEvents]，按事件原地增量更新，无需重查库。
final class CategoryControllerProvider
    extends $AsyncNotifierProvider<CategoryController, List<Category>> {
  /// 订阅 [CategoryRepository.categoryEvents]，按事件原地增量更新，无需重查库。
  CategoryControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoryControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoryControllerHash();

  @$internal
  @override
  CategoryController create() => CategoryController();
}

String _$categoryControllerHash() =>
    r'207fc4b52b84e3407b55feaaa4f5bbdd8b3d4d82';

/// 订阅 [CategoryRepository.categoryEvents]，按事件原地增量更新，无需重查库。

abstract class _$CategoryController extends $AsyncNotifier<List<Category>> {
  FutureOr<List<Category>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Category>>, List<Category>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Category>>, List<Category>>,
              AsyncValue<List<Category>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// [categoryControllerProvider] 的用户自定义顺序视图（[MoodiaryKVs.categoryOrder]，
/// 本机偏好）：KV 序优先，KV 外的（新建 / 远端拉下）按 id 序追加尾部。首页筛选条 /
/// 切换面板 / 分类管理页等展示面消费它；按 id 查询的 provider 不受影响。

@ProviderFor(orderedCategories)
final orderedCategoriesProvider = OrderedCategoriesProvider._();

/// [categoryControllerProvider] 的用户自定义顺序视图（[MoodiaryKVs.categoryOrder]，
/// 本机偏好）：KV 序优先，KV 外的（新建 / 远端拉下）按 id 序追加尾部。首页筛选条 /
/// 切换面板 / 分类管理页等展示面消费它；按 id 查询的 provider 不受影响。

final class OrderedCategoriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Category>>,
          AsyncValue<List<Category>>,
          AsyncValue<List<Category>>
        >
    with $Provider<AsyncValue<List<Category>>> {
  /// [categoryControllerProvider] 的用户自定义顺序视图（[MoodiaryKVs.categoryOrder]，
  /// 本机偏好）：KV 序优先，KV 外的（新建 / 远端拉下）按 id 序追加尾部。首页筛选条 /
  /// 切换面板 / 分类管理页等展示面消费它；按 id 查询的 provider 不受影响。
  OrderedCategoriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'orderedCategoriesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$orderedCategoriesHash();

  @$internal
  @override
  $ProviderElement<AsyncValue<List<Category>>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AsyncValue<List<Category>> create(Ref ref) {
    return orderedCategories(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<List<Category>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<List<Category>>>(value),
    );
  }
}

String _$orderedCategoriesHash() => r'8530cfec8547fe7adba9d813b3fc808e7fbc5b25';

/// 各分类下「可见」日记数 + 可见总数（含未分类），供分类管理页 / 切换面板展示。
/// 订阅日记事件流自失效（debounce 合并连发；分类增删不影响计数，缺项回退 0）。

@ProviderFor(categoryDiaryCounts)
final categoryDiaryCountsProvider = CategoryDiaryCountsProvider._();

/// 各分类下「可见」日记数 + 可见总数（含未分类），供分类管理页 / 切换面板展示。
/// 订阅日记事件流自失效（debounce 合并连发；分类增删不影响计数，缺项回退 0）。

final class CategoryDiaryCountsProvider
    extends
        $FunctionalProvider<
          AsyncValue<({Map<String, int> byCategory, int total})>,
          ({Map<String, int> byCategory, int total}),
          FutureOr<({Map<String, int> byCategory, int total})>
        >
    with
        $FutureModifier<({Map<String, int> byCategory, int total})>,
        $FutureProvider<({Map<String, int> byCategory, int total})> {
  /// 各分类下「可见」日记数 + 可见总数（含未分类），供分类管理页 / 切换面板展示。
  /// 订阅日记事件流自失效（debounce 合并连发；分类增删不影响计数，缺项回退 0）。
  CategoryDiaryCountsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoryDiaryCountsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoryDiaryCountsHash();

  @$internal
  @override
  $FutureProviderElement<({Map<String, int> byCategory, int total})>
  $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<({Map<String, int> byCategory, int total})> create(Ref ref) {
    return categoryDiaryCounts(ref);
  }
}

String _$categoryDiaryCountsHash() =>
    r'928b55e44ab6f84967d4423aeafcbb7dfa79b1a1';

@ProviderFor(getCategory)
final getCategoryProvider = GetCategoryFamily._();

final class GetCategoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<Category?>,
          Category?,
          FutureOr<Category?>
        >
    with $FutureModifier<Category?>, $FutureProvider<Category?> {
  GetCategoryProvider._({
    required GetCategoryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'getCategoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$getCategoryHash();

  @override
  String toString() {
    return r'getCategoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Category?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Category?> create(Ref ref) {
    final argument = this.argument as String;
    return getCategory(ref, id: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GetCategoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$getCategoryHash() => r'62406365bf60de3d165fd335cfa21689a01f869d';

final class GetCategoryFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Category?>, String> {
  GetCategoryFamily._()
    : super(
        retry: null,
        name: r'getCategoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GetCategoryProvider call({required String id}) =>
      GetCategoryProvider._(argument: id, from: this);

  @override
  String toString() => r'getCategoryProvider';
}

@ProviderFor(categoryById)
final categoryByIdProvider = CategoryByIdFamily._();

final class CategoryByIdProvider
    extends $FunctionalProvider<Category?, Category?, Category?>
    with $Provider<Category?> {
  CategoryByIdProvider._({
    required CategoryByIdFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'categoryByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$categoryByIdHash();

  @override
  String toString() {
    return r'categoryByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<Category?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Category? create(Ref ref) {
    final argument = this.argument as String?;
    return categoryById(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Category? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Category?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CategoryByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$categoryByIdHash() => r'66ccadc3fad7f339609b35618dabbc41de2955c2';

final class CategoryByIdFamily extends $Family
    with $FunctionalFamilyOverride<Category?, String?> {
  CategoryByIdFamily._()
    : super(
        retry: null,
        name: r'categoryByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CategoryByIdProvider call(String? id) =>
      CategoryByIdProvider._(argument: id, from: this);

  @override
  String toString() => r'categoryByIdProvider';
}
