// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 该月可见日记（show=true 且非软删），按时间倒序。

@ProviderFor(monthDiaries)
final monthDiariesProvider = MonthDiariesFamily._();

/// 该月可见日记（show=true 且非软删），按时间倒序。

final class MonthDiariesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Diary>>,
          List<Diary>,
          FutureOr<List<Diary>>
        >
    with $FutureModifier<List<Diary>>, $FutureProvider<List<Diary>> {
  /// 该月可见日记（show=true 且非软删），按时间倒序。
  MonthDiariesProvider._({
    required MonthDiariesFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'monthDiariesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$monthDiariesHash();

  @override
  String toString() {
    return r'monthDiariesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Diary>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Diary>> create(Ref ref) {
    final argument = this.argument as DateTime;
    return monthDiaries(ref, month: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MonthDiariesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$monthDiariesHash() => r'72f19dd2593b557c3269bf9e78569b552dd6af45';

/// 该月可见日记（show=true 且非软删），按时间倒序。

final class MonthDiariesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Diary>>, DateTime> {
  MonthDiariesFamily._()
    : super(
        retry: null,
        name: r'monthDiariesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 该月可见日记（show=true 且非软删），按时间倒序。

  MonthDiariesProvider call({required DateTime month}) =>
      MonthDiariesProvider._(argument: month, from: this);

  @override
  String toString() => r'monthDiariesProvider';
}
