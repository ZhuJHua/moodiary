part of '../model.dart';

/// A deterministic content-expression state. Unknown opaque blocks occupy the
/// block group without exposing or changing their private schema.
class ContentMatch {
  ContentMatch._(this.schema, this.validEnd);
  final Schema schema;
  final bool validEnd;
  final List<(String, ContentMatch)> next = [];
  static final _treeMatches = Expando<Map<ContentMatch, ContentMatch?>>();

  ContentMatch? matchType(String type) {
    final name = schema.nodes.containsKey(type) ? type : '@opaque';
    for (final edge in next) {
      if (edge.$1 == name) return edge.$2;
    }
    return null;
  }

  ContentMatch? matchFragment(Fragment fragment, {int start = 0, int? end}) {
    end ??= fragment.length;
    if (fragment.blocks != null) {
      ContentMatch? walk(_Tree? tree, ContentMatch state) {
        if (tree == null) return state;
        final cache = _treeMatches[tree] ??= {};
        if (cache.containsKey(state)) return cache[state];
        ContentMatch? result;
        if (tree.node != null) {
          result = state.matchType(tree.node!.type);
        } else {
          final left = walk(tree.left, state);
          result = left == null ? null : walk(tree.right, left);
        }
        cache[state] = result;
        return result;
      }

      return walk(fragment.blocks!.slice(start, end)._root, this);
    }
    ContentMatch? state = this;
    for (var i = start; i < end && state != null; i++) {
      state = state.matchType(fragment[i].type);
    }
    return state;
  }

  Fragment? fillBefore(Fragment after, {bool toEnd = false, int start = 0}) {
    final seen = <ContentMatch>{this};
    Fragment? search(ContentMatch match, List<String> types) {
      final finished = match.matchFragment(after, start: start);
      if (finished != null && (!toEnd || finished.validEnd)) {
        return Fragment(types.map((type) => schema.createAndFill(type)!));
      }
      for (final (type, next) in match.next) {
        if (type == '@opaque' || type == 'text' || seen.contains(next)) {
          continue;
        }
        seen.add(next);
        final found = search(next, [...types, type]);
        if (found != null) return found;
      }
      return null;
    }

    return search(this, const []);
  }

  List<String>? findWrapping(String target) {
    final queue = <(ContentMatch, List<String>)>[(this, const [])];
    final seen = <String>{};
    for (var i = 0; i < queue.length; i++) {
      final (match, via) = queue[i];
      if (match.matchType(target) != null) return via;
      for (final (type, next) in match.next) {
        final spec = schema.nodes[type];
        if (spec == null ||
            spec.leaf ||
            !seen.add(type) ||
            (via.isNotEmpty && !next.validEnd)) {
          continue;
        }
        queue.add((schema.contentMatch(type), [...via, type]));
      }
    }
    return null;
  }

  static ContentMatch _compile(Schema schema, String expression) {
    // Expressions are concatenations of named types/groups with ?, * or +.
    final tokens = expression.split(' ').where((s) => s.isNotEmpty).toList();
    final edges = <List<(String?, int)>>[[]];
    int state() {
      edges.add([]);
      return edges.length - 1;
    }

    var current = 0;
    for (final token in tokens) {
      final suffix = token[token.length - 1];
      final quantifier = '*+?'.contains(suffix) ? suffix : '';
      final name = quantifier.isEmpty
          ? token
          : token.substring(0, token.length - 1);
      final end = state();
      final names = schema.nodes.containsKey(name)
          ? [name]
          : [
              ...schema.nodes.entries
                  .where((e) => e.value.group.split(' ').contains(name))
                  .map((e) => e.key),
              if (name == 'block') '@opaque',
            ];
      if (names.isEmpty) throw ArgumentError('Unknown content group $name');
      if (quantifier == '*' || quantifier == '?') {
        edges[current].add((null, end));
      }
      for (final type in names) {
        edges[current].add((type, end));
        if (quantifier == '*' || quantifier == '+') edges[end].add((type, end));
      }
      current = end;
    }
    Set<int> closure(Iterable<int> input) {
      final set = input.toSet(), todo = input.toList();
      while (todo.isNotEmpty) {
        for (final (label, target) in edges[todo.removeLast()]) {
          if (label == null && set.add(target)) todo.add(target);
        }
      }
      return set;
    }

    final matches = <String, ContentMatch>{};
    ContentMatch explore(Set<int> states) {
      final sorted = states.toList()..sort();
      final key = sorted.join(',');
      if (matches[key] case final found?) return found;
      final result = ContentMatch._(schema, states.contains(current));
      matches[key] = result;
      final transitions = <String, Set<int>>{};
      for (final index in sorted) {
        for (final (label, target) in edges[index]) {
          if (label != null) (transitions[label] ??= {}).add(target);
        }
      }
      for (final entry in transitions.entries) {
        result.next.add((entry.key, explore(closure(entry.value))));
      }
      return result;
    }

    return explore(closure([0]));
  }
}
