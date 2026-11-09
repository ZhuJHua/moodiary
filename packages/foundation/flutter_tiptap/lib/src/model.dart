import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:characters/characters.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

part 'model/schema.dart';
part 'model/html.dart';
part 'model/content.dart';
part 'model/replace.dart';
part 'model/fitter.dart';
part 'model/structure.dart';
part 'model/tree.dart';
part 'model/node.dart';
part 'model/selection.dart';
part 'model/step.dart';
part 'model/state.dart';
part 'model/history.dart';
part 'model/commands.dart';
part 'model/media.dart';
part 'model/links.dart';
part 'model/references.dart';
part 'model/paste.dart';
part 'model/tables.dart';
part 'model/search.dart';

Object? _freeze(Object? value) => switch (value) {
  Map() => Map<String, Object?>.unmodifiable(
    value.map((k, v) => MapEntry(k as String, _freeze(v))),
  ),
  List() => List<Object?>.unmodifiable(value.map(_freeze)),
  _ => value,
};

Map<String, Object?> _attrs(
  Map<String, Object?> defaults,
  Map<String, Object?>? attrs,
) => _freeze({...defaults, ...?attrs})! as Map<String, Object?>;

bool _equal(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((k) => b.containsKey(k) && _equal(a[k], b[k]));
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        Iterable<int>.generate(a.length).every((i) => _equal(a[i], b[i]));
  }
  return a == b;
}
