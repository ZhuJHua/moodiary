// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'edit_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(EditController)
final editControllerProvider = EditControllerFamily._();

final class EditControllerProvider
    extends $AsyncNotifierProvider<EditController, Diary> {
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

String _$editControllerHash() => r'51a8100c8469b3c9479dd97f2b370797694a4887';

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
