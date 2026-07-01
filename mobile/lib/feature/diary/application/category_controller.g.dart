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

String _$getCategoryHash() => r'f1e52390dc0b4576e8a4d68b10db6f7c40b9d8d5';

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
