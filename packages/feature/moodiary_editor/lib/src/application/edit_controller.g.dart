// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'edit_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 编辑页状态机。`changeXxx` 改本地 `state`，落库走 [autoSave]。新建延迟落库：
/// 空白不创建，有内容才 insert，写了又清空则丢弃。

@ProviderFor(EditController)
final editControllerProvider = EditControllerFamily._();

/// 编辑页状态机。`changeXxx` 改本地 `state`，落库走 [autoSave]。新建延迟落库：
/// 空白不创建，有内容才 insert，写了又清空则丢弃。
final class EditControllerProvider
    extends $AsyncNotifierProvider<EditController, Diary> {
  /// 编辑页状态机。`changeXxx` 改本地 `state`，落库走 [autoSave]。新建延迟落库：
  /// 空白不创建，有内容才 insert，写了又清空则丢弃。
  EditControllerProvider._({
    required EditControllerFamily super.from,
    required (String?, {DiaryType? defaultType, String? defaultCategoryId})
    super.argument,
  }) : super(
         retry: null,
         name: r'editControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$editControllerHash();

  @override
  String toString() {
    return r'editControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  EditController create() => EditController();

  @override
  bool operator ==(Object other) {
    return other is EditControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$editControllerHash() => r'ddd3e9eb0838c5d8b62af5f1a6a709a1776994fc';

/// 编辑页状态机。`changeXxx` 改本地 `state`，落库走 [autoSave]。新建延迟落库：
/// 空白不创建，有内容才 insert，写了又清空则丢弃。

final class EditControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          EditController,
          AsyncValue<Diary>,
          Diary,
          FutureOr<Diary>,
          (String?, {DiaryType? defaultType, String? defaultCategoryId})
        > {
  EditControllerFamily._()
    : super(
        retry: null,
        name: r'editControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 编辑页状态机。`changeXxx` 改本地 `state`，落库走 [autoSave]。新建延迟落库：
  /// 空白不创建，有内容才 insert，写了又清空则丢弃。

  EditControllerProvider call(
    String? diaryId, {
    DiaryType? defaultType,
    String? defaultCategoryId,
  }) => EditControllerProvider._(
    argument: (
      diaryId,
      defaultType: defaultType,
      defaultCategoryId: defaultCategoryId,
    ),
    from: this,
  );

  @override
  String toString() => r'editControllerProvider';
}

/// 编辑页状态机。`changeXxx` 改本地 `state`，落库走 [autoSave]。新建延迟落库：
/// 空白不创建，有内容才 insert，写了又清空则丢弃。

abstract class _$EditController extends $AsyncNotifier<Diary> {
  late final _$args =
      ref.$arg
          as (String?, {DiaryType? defaultType, String? defaultCategoryId});
  String? get diaryId => _$args.$1;
  DiaryType? get defaultType => _$args.defaultType;
  String? get defaultCategoryId => _$args.defaultCategoryId;

  FutureOr<Diary> build(
    String? diaryId, {
    DiaryType? defaultType,
    String? defaultCategoryId,
  });
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Diary>, Diary>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Diary>, Diary>,
              AsyncValue<Diary>,
              Object?,
              Object?
            >;
    return element.handleCreate(
      ref,
      () => build(
        _$args.$1,
        defaultType: _$args.defaultType,
        defaultCategoryId: _$args.defaultCategoryId,
      ),
    );
  }
}
