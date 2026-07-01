// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'edit_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 编辑页状态机。`changeXxx` 仅改本地 `state`；落库统一走 [autoSave]（新建 insert、
/// 其余 update）。无手动保存、无草稿概念——创建即落盘。

@ProviderFor(EditController)
final editControllerProvider = EditControllerFamily._();

/// 编辑页状态机。`changeXxx` 仅改本地 `state`；落库统一走 [autoSave]（新建 insert、
/// 其余 update）。无手动保存、无草稿概念——创建即落盘。
final class EditControllerProvider
    extends $AsyncNotifierProvider<EditController, Diary> {
  /// 编辑页状态机。`changeXxx` 仅改本地 `state`；落库统一走 [autoSave]（新建 insert、
  /// 其余 update）。无手动保存、无草稿概念——创建即落盘。
  EditControllerProvider._({
    required EditControllerFamily super.from,
    required (String?, {DiaryType? defaultType}) super.argument,
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

String _$editControllerHash() => r'4223732a21fa9c12fd2b56eaea6cfa33cd5c3b7e';

/// 编辑页状态机。`changeXxx` 仅改本地 `state`；落库统一走 [autoSave]（新建 insert、
/// 其余 update）。无手动保存、无草稿概念——创建即落盘。

final class EditControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          EditController,
          AsyncValue<Diary>,
          Diary,
          FutureOr<Diary>,
          (String?, {DiaryType? defaultType})
        > {
  EditControllerFamily._()
    : super(
        retry: null,
        name: r'editControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 编辑页状态机。`changeXxx` 仅改本地 `state`；落库统一走 [autoSave]（新建 insert、
  /// 其余 update）。无手动保存、无草稿概念——创建即落盘。

  EditControllerProvider call(String? diaryId, {DiaryType? defaultType}) =>
      EditControllerProvider._(
        argument: (diaryId, defaultType: defaultType),
        from: this,
      );

  @override
  String toString() => r'editControllerProvider';
}

/// 编辑页状态机。`changeXxx` 仅改本地 `state`；落库统一走 [autoSave]（新建 insert、
/// 其余 update）。无手动保存、无草稿概念——创建即落盘。

abstract class _$EditController extends $AsyncNotifier<Diary> {
  late final _$args = ref.$arg as (String?, {DiaryType? defaultType});
  String? get diaryId => _$args.$1;
  DiaryType? get defaultType => _$args.defaultType;

  FutureOr<Diary> build(String? diaryId, {DiaryType? defaultType});
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
      () => build(_$args.$1, defaultType: _$args.defaultType),
    );
  }
}
