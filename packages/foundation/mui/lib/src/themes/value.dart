import 'package:flutter/foundation.dart';

/// 值语义的公共实现：[props] 是字段清单的唯一真源，`==` 与 `hashCode` 都从它派生。
///
/// 手写两份相等实现迟早会漂，而漏字段的症状是「改了主题某项却不重建」——不报错、
/// 不崩、测试也难覆盖。收成一处后只剩「新增字段忘了进 props」一种漏法，由
/// `theme_field_coverage_test.dart` 逐类钉住 props 长度。
///
/// 元素级比较对 `Map` / `List` 做一层展开：Dart 的集合相等是**身份**比较，
/// 直接扔进 `listEquals` 会让结构相同的两份主题判不相等，进而让
/// `ThemeData` 每次都判定为变了、`AnimatedTheme` 每次都重启补间。
mixin MuiValue {
  List<Object?> get props;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other.runtimeType == runtimeType &&
          other is MuiValue &&
          _listEq(other.props, props);

  @override
  int get hashCode =>
      Object.hash(runtimeType, Object.hashAll(props.map(_hash)));

  static bool _listEq(List<Object?> a, List<Object?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_eq(a[i], b[i])) return false;
    }
    return true;
  }

  static bool _eq(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is Map && b is Map) return mapEquals(a, b);
    if (a is List && b is List) return listEquals(a, b);
    return a == b;
  }

  static Object _hash(Object? v) => switch (v) {
    final Map<Object?, Object?> m => Object.hashAllUnordered(
      m.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    final List<Object?> l => Object.hashAll(l),
    _ => v ?? 0,
  };
}
