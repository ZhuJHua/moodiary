import 'package:flutter/foundation.dart';

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
