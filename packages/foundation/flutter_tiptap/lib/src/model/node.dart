part of '../model.dart';

class Fragment extends Iterable<Node> {
  Fragment(Iterable<Node> nodes) : this._inline(_normalize(nodes));
  Fragment._inline(List<Node> nodes)
    : _nodes = nodes,
      blocks = null,
      size = nodes.fold(0, (n, c) => n + c.nodeSize),
      textLength = nodes.fold(0, (n, c) => n + c.textLength);
  Fragment.blocks(Iterable<Node> nodes) : this._blocks(BlockTree(nodes));
  Fragment._blocks(BlockTree tree)
    : blocks = tree,
      _nodes = null,
      size = tree.summary.nodeSize,
      textLength = tree.summary.textLength;
  static final empty = Fragment(const []);
  final List<Node>? _nodes;
  final BlockTree? blocks;
  final int size;
  final int textLength;
  @override
  int get length => blocks?.length ?? _nodes!.length;
  @override
  bool get isEmpty => length == 0;
  @override
  Node get first => isEmpty ? throw StateError('No element') : this[0];
  @override
  Node get last => isEmpty ? throw StateError('No element') : this[length - 1];
  @override
  Node elementAt(int index) => this[index];
  Node operator [](int index) => blocks?[index] ?? _nodes![index];
  @override
  Iterator<Node> get iterator => blocks?.iterator ?? _nodes!.iterator;

  static List<Node> _normalize(Iterable<Node> nodes) {
    final result = <Node>[];
    for (final node in nodes) {
      if (node.isText &&
          result.isNotEmpty &&
          result.last.isText &&
          _equal(node.marks, result.last.marks) &&
          _equal(node.attrs, result.last.attrs)) {
        final prev = result.removeLast();
        result.add(prev.withText('${prev.text}${node.text}'));
      } else {
        result.add(node);
      }
    }
    return List.unmodifiable(result);
  }

  Fragment cut(int from, [int? to]) {
    to ??= size;
    RangeError.checkValueInInterval(from, 0, size, 'from');
    RangeError.checkValueInInterval(to, from, size, 'to');
    if (from == 0 && to == size) return this;
    if (blocks != null) {
      if (from == to) return Fragment._blocks(const BlockTree._(null));
      final a = indexAt(from), b = indexAt(to - 1);
      final start = positionAt(a), end = positionAt(b + 1);
      var result = cutByIndex(a, b + 1);
      if (from > start) {
        final first = result.first;
        result = result.replaceChild(
          0,
          first.copy(
            first.content.cut(
              from - start - 1,
              b == a
                  ? (to - start - 1).clamp(0, first.content.size)
                  : first.content.size,
            ),
          ),
        );
      }
      if (to < end && (a != b || from == start)) {
        final last = result.last;
        result = result.replaceChild(
          result.length - 1,
          last.copy(
            last.content.cut(
              0,
              (to - positionAt(b) - 1).clamp(0, last.content.size),
            ),
          ),
        );
      }
      return result;
    }
    final result = <Node>[];
    var pos = 0;
    for (final node in this) {
      final end = pos + node.nodeSize;
      if (pos >= to) break;
      if (end > from) {
        if (from <= pos && to >= end) {
          result.add(node);
        } else if (node.isText) {
          result.add(
            node.withText(
              node.text!.substring(
                math.max(0, from - pos),
                math.min(node.nodeSize, to - pos),
              ),
            ),
          );
        } else if (!node.isLeaf) {
          result.add(
            node.copy(
              node.content.cut(
                math.max(0, from - pos - 1),
                math.min(node.content.size, to - pos - 1),
              ),
            ),
          );
        }
      }
      pos = end;
    }
    return Fragment(result);
  }

  bool eq(Fragment other) =>
      identical(this, other) ||
      length == other.length &&
          Iterable<int>.generate(length).every((i) => this[i].eq(other[i]));
  Fragment append(Fragment other) {
    if (isEmpty) return other;
    if (other.isEmpty) return this;
    if (blocks != null || other.blocks != null) {
      return Fragment._blocks(
        BlockTree._(_join(BlockTree(this)._root, BlockTree(other)._root)),
      );
    }
    return Fragment([...this, ...other]);
  }

  int indexAt(int pos) {
    if (blocks != null) return blocks!.indexAt(pos);
    var offset = 0;
    for (var i = 0; i < length; i++) {
      if (offset + this[i].nodeSize > pos) return i;
      offset += this[i].nodeSize;
    }
    return length;
  }

  int positionAt(int index) =>
      blocks?.positionAt(index) ??
      _nodes!.take(index).fold(0, (n, c) => n + c.nodeSize);
  Fragment cutByIndex(int from, int to) => blocks != null
      ? Fragment._blocks(blocks!.slice(from, to))
      : Fragment(_nodes!.sublist(from, to));
  Fragment replaceChild(int index, Node node) => blocks != null
      ? Fragment._blocks(blocks!.replace(index, index + 1, [node]))
      : Fragment([..._nodes!.take(index), node, ..._nodes.skip(index + 1)]);
}

int _rawSize(Map raw) {
  if (raw['type'] == 'text') return (raw['text'] as String).length;
  final content = raw['content'] as List?;
  return content == null
      ? 1
      : 2 + content.fold<int>(0, (s, n) => s + _rawSize(n as Map));
}

int _rawTextLength(Map raw) => raw['text'] is String
    ? (raw['text'] as String).length
    : (raw['content'] as List? ?? const []).fold(
        0,
        (s, n) => s + _rawTextLength(n as Map),
      );

/// An immutable document node with attributes, marks and persistent child content.
class Node {
  Node._(
    this.schema,
    this.type,
    this.attrs,
    this.content,
    this.text,
    this.marks,
    this._raw,
  ) : _opaqueSize = _raw == null
          ? 0
          : schema.opaqueAtomTypes.contains(type)
          ? 1
          : _rawSize(_raw),
      _opaqueTextLength = _raw == null ? 0 : _rawTextLength(_raw);
  factory Node.fromJson(Map<String, dynamic> json, {Schema? schema}) =>
      (schema ?? Schema.standard()).fromJson(json);
  final Schema schema;
  final String type;
  final Map<String, Object?> attrs;
  final Fragment content;
  final String? text;
  final List<Mark> marks;
  final Map<String, Object?>? _raw;
  final int _opaqueSize;
  final int _opaqueTextLength;
  late final _MarkCoverage _markCoverage = isOpaque
      ? _MarkCoverage.zero
      : isTextblock
      ? _coverage(0, content.size)
      : isText || marks.isNotEmpty
      ? _MarkCoverage(
          nodeSize,
          Map.unmodifiable({for (final mark in marks) mark.type: nodeSize}),
        )
      : content.blocks?.summary._marks ??
            content.fold(_MarkCoverage.zero, (a, n) => a + n._markCoverage);
  _MarkCoverage _coverage(int from, int to) {
    if (!isTextblock && !isLeaf) {
      if (from >= to) return _MarkCoverage.zero;
      if (from == 0 && to == content.size) return _markCoverage;
      final a = content.indexAt(from), b = content.indexAt(to - 1);
      _MarkCoverage edge(int i) {
        final child = content[i], start = content.positionAt(i) + 1;
        if (child.isLeaf) return _MarkCoverage.zero;
        return child._coverage(
          (from - start).clamp(0, child.content.size),
          (to - start).clamp(0, child.content.size),
        );
      }

      var result = edge(a);
      if (b > a) {
        result +=
            content.blocks?.summaryBetween(a + 1, b)._marks ??
            content
                .skip(a + 1)
                .take(b - a - 1)
                .fold(_MarkCoverage.zero, (a, n) => a + n._markCoverage);
        result += edge(b);
      }
      return result;
    }
    var result = _MarkCoverage.zero;
    var position = 0;
    for (final node in content) {
      final length = math.max<int>(
        0,
        math.min<int>(to, position + node.nodeSize) -
            math.max<int>(from, position),
      );
      if (length > 0 && (node.isText || node.marks.isNotEmpty)) {
        result += _MarkCoverage(
          length,
          Map.unmodifiable({for (final mark in node.marks) mark.type: length}),
        );
      }
      position += node.nodeSize;
      if (position >= to) break;
    }
    return result;
  }

  /// Visual rows are textblocks and opaque/atom blocks, never containers.
  late final int rowCount =
      isTextblock ||
          type == 'tableRow' ||
          (isLeaf && !isText && schema.nodes[type]?.inline != true)
      ? 1
      : content.blocks?.summary.rowCount ?? 0;
  int rowsBefore(int childIndex) => content.blocks?.rowsBefore(childIndex) ?? 0;
  DocumentRow rowAt(int row) {
    RangeError.checkValueInInterval(row, 0, rowCount - 1, 'row');
    var node = this, position = type == 'doc' ? -1 : 0;
    final path = <int>[];
    while (!node.isTextblock && !node.isLeaf && node.type != 'tableRow') {
      final (index, before) = node.blocks.childForRow(row);
      row -= before;
      position += 1 + node.content.positionAt(index);
      path.add(index);
      node = node.child(index);
    }
    return DocumentRow(node, position, List.unmodifiable(path));
  }

  int rowIndexAt(int position) {
    final resolved = resolve(position);
    var count = 0;
    for (var d = 0; d <= resolved.depth; d++) {
      final parent = resolved.node(d);
      if (parent.isTextblock || parent.isLeaf || parent.type == 'tableRow') {
        break;
      }
      count += parent.rowsBefore(resolved.index(d));
    }
    return count.clamp(0, math.max(0, rowCount - 1));
  }

  Iterable<DocumentRow> rows({int from = 0, int? to}) sync* {
    for (var i = from; i < (to ?? rowCount); i++) {
      yield rowAt(i);
    }
  }

  bool get isOpaque => _raw != null;
  bool get isAtom => isOpaque ? schema.opaqueAtomTypes.contains(type) : isLeaf;
  bool get isText => type == 'text';
  bool get isTextblock => !isOpaque && schema.nodes[type]?.textblock == true;
  bool get isLeaf => isOpaque || schema.nodes[type]?.leaf == true;
  int get nodeSize => isOpaque
      ? _opaqueSize
      : isText
      ? text!.length
      : isLeaf
      ? 1
      : 2 + content.size;
  int get textLength =>
      isOpaque ? _opaqueTextLength : text?.length ?? content.textLength;
  int get childCount => content.length;
  Node child(int index) => content[index];
  BlockTree get blocks =>
      content.blocks ?? (throw StateError('Not a document'));
  String get textContent =>
      text ??
      content.map((n) => n.type == 'hardBreak' ? '\n' : n.textContent).join();
  bool eq(Node other) =>
      identical(this, other) ||
      type == other.type &&
          text == other.text &&
          _equal(attrs, other.attrs) &&
          _equal(marks, other.marks) &&
          _equal(_raw, other._raw) &&
          content.eq(other.content);
  Node copy(Fragment content) => Node._(
    schema,
    type,
    attrs,
    !isTextblock && !isLeaf && content.blocks == null
        ? Fragment.blocks(content)
        : content,
    text,
    marks,
    _raw,
  );
  Node withText(String text) {
    if (!isText || text.isEmpty) throw ArgumentError('Expected nonempty text');
    return Node._(schema, type, attrs, content, text, marks, _raw);
  }

  Node withMarks(List<Mark> marks) => Node._(
    schema,
    type,
    attrs,
    content,
    text,
    List.unmodifiable(marks),
    _raw,
  );
  Node withAttrs(Map<String, Object?> attrs) =>
      Node._(schema, type, _attrs(const {}, attrs), content, text, marks, _raw);
  Node replaceBlocks(int from, int to, Iterable<Node> nodes) =>
      copy(Fragment._blocks(blocks.replace(from, to, nodes)));
  bool validContent(Fragment content) => schema.validContent(type, content);
  ContentMatch contentMatchAt(int index) =>
      schema.contentMatch(type).matchFragment(content, end: index)!;
  bool canReplace(int from, int to, [Fragment? replacement]) {
    final match = contentMatchAt(from)
        .matchFragment(replacement ?? Fragment.empty);
    final end = match?.matchFragment(content, start: to);
    return end?.validEnd == true &&
        (schema.nodes[type]?.code != true ||
            (replacement ?? Fragment.empty).every((n) => n.marks.isEmpty));
  }

  Node replace(int from, int to, Slice slice) =>
      _replace(resolve(from), resolve(to), slice);
  Slice slice(int from, int to, {bool includeParents = false}) {
    if (from == to) return Slice.empty;
    final a = resolve(from), b = resolve(to);
    final depth = includeParents ? 0 : a.sharedDepth(to);
    return Slice(
      a.node(depth).content.cut(from - a.start(depth), to - a.start(depth)),
      a.depth - depth,
      b.depth - depth,
    );
  }

  Node? nodeAt(int pos) {
    final resolved = resolve(pos);
    return resolved.nodeAfter;
  }

  ResolvedPos resolve(int pos) => ResolvedPos._resolve(this, pos);
  Map<String, Object?> toJson() =>
      _raw ??
      {
        'type': type,
        if (attrs.isNotEmpty) 'attrs': attrs,
        if (content.isNotEmpty)
          'content': content.map((n) => n.toJson()).toList(),
        if (marks.isNotEmpty) 'marks': marks.map((m) => m.toJson()).toList(),
        if (text != null) 'text': text,
      };
  String toJsonString() => _defaultCodec.encodeNode(this);
}

class _EncodedJson {
  _EncodedJson(this.parts, this.generation, this.incremental);
  final int generation;
  final bool incremental;
  final List<Object> parts;
  String? flat;
  void write(StringBuffer out) {
    if (flat case final text?) {
      out.write(text);
      return;
    }
    for (final part in parts) {
      if (part is _EncodedJson) {
        part.write(out);
      } else {
        out.write(part);
      }
    }
  }

  String flatten() {
    if (flat case final text?) return text;
    final out = StringBuffer();
    write(out);
    return flat = out.toString();
  }
}

class DocumentCodec {
  final _nodes = Expando<_EncodedJson>();
  final _trees = Expando<_EncodedJson>();
  int _generation = 0, _reuse = 0;
  int get encodedBlocks => _encodedBlocks;
  int get encodedNodes => _encodedNodes;
  int _encodedBlocks = 0, _encodedNodes = 0;
  String encode(Node doc) {
    if (doc.type != 'doc') throw ArgumentError('Expected document');
    return encodeNode(doc);
  }

  String encodeNode(Node node) {
    _encodedBlocks = 0;
    _encodedNodes = 0;
    _generation++;
    final encoded = _encode(node), result = encoded.flatten();
    // History retains document identities. Keep their piece trees, not a full
    // output-sized String for each undo event.
    if (node.type == 'doc') encoded.flat = null;
    return result;
  }

  _EncodedJson _encode(Node node) {
    if (_nodes[node] case final cached?) {
      if (cached.generation != _generation || cached.incremental) _reuse++;
      return cached;
    }
    final before = _reuse;
    _encodedNodes++;
    if (node.isOpaque) {
      return _nodes[node] = _piece([jsonEncode(node.toJson())], before);
    }
    final parts = <Object>['{"type":', jsonEncode(node.type)];
    if (node.attrs.isNotEmpty) {
      parts.addAll([',"attrs":', jsonEncode(node.attrs)]);
    }
    if (node.content.isNotEmpty) {
      parts.add(',"content":[');
      final tree = node.content.blocks?._root;
      if (tree != null) {
        parts.add(_tree(tree, top: node.type == 'doc'));
      } else {
        var first = true;
        for (final child in node.content) {
          if (!first) parts.add(',');
          parts.add(_encode(child));
          first = false;
        }
      }
      parts.add(']');
    }
    if (node.marks.isNotEmpty) {
      parts.addAll([
        ',"marks":',
        jsonEncode(node.marks.map((m) => m.toJson()).toList()),
      ]);
    }
    if (node.text != null) parts.addAll([',"text":', jsonEncode(node.text)]);
    parts.add('}');
    return _nodes[node] = _piece(parts, before);
  }

  _EncodedJson _piece(List<Object> parts, int before) {
    final value = _EncodedJson(parts, _generation, _reuse != before);
    if (!value.incremental) value.flatten();
    return value;
  }

  _EncodedJson _tree(_Tree tree, {bool top = false}) {
    if (_trees[tree] case final cached?) {
      if (cached.generation != _generation || cached.incremental) _reuse++;
      return cached;
    }
    final before = _reuse;
    if (tree.node case final node?) {
      if (top && _nodes[node] == null) _encodedBlocks++;
      return _trees[tree] = _encode(node);
    }
    return _trees[tree] = _piece([
      _tree(tree.left!, top: top),
      ',',
      _tree(tree.right!, top: top),
    ], before);
  }
}

final _defaultCodec = DocumentCodec();

class Slice {
  const Slice(this.content, this.openStart, this.openEnd);
  final Fragment content;
  final int openStart;
  final int openEnd;
  int get size => content.size - openStart - openEnd;
  static final empty = Slice(Fragment.empty, 0, 0);
}

class ResolvedPos {
  ResolvedPos._(
    this.doc,
    this.pos,
    this.blockIndex,
    this.blockStart,
    this._nodes,
    this._indices,
    this._starts,
    this.parentOffset,
    this.textOffset,
  );
  final Node doc;
  final int pos;
  final int blockIndex;
  final int blockStart;
  final List<Node> _nodes;
  final List<int> _indices;
  final List<int> _starts;
  final int parentOffset;
  final int textOffset;
  int get depth => _nodes.length - 1;
  Node get parent => _nodes.last;
  int _depth(int? depth) => depth == null
      ? this.depth
      : depth < 0
      ? this.depth + depth
      : depth;
  Node node([int? depth]) => _nodes[_depth(depth)];
  int index([int? depth]) => _indices[_depth(depth)];
  int start([int? depth]) => _starts[_depth(depth)];
  int end([int? depth]) => start(depth) + node(depth).content.size;
  int before([int? depth]) {
    final d = _depth(depth);
    if (d == 0) throw RangeError('No position before document');
    if (d == this.depth + 1) return pos;
    return start(d) - 1;
  }

  int after([int? depth]) {
    final d = _depth(depth);
    return d == this.depth + 1 ? pos : before(d) + node(d).nodeSize;
  }

  int indexAfter([int? depth]) {
    final d = _depth(depth);
    return index(d) + (d == this.depth && textOffset == 0 ? 0 : 1);
  }

  int sharedDepth(int pos) {
    for (var d = depth; d > 0; d--) {
      if (start(d) <= pos && end(d) >= pos) return d;
    }
    return 0;
  }

  int posAtIndex(int index, [int? depth]) =>
      start(depth) + node(depth).content.positionAt(index);
  Node? get nodeAfter {
    if (index() == parent.childCount) return null;
    final child = parent.child(index());
    return textOffset == 0
        ? child
        : child.withText(child.text!.substring(textOffset));
  }

  Node? get nodeBefore {
    if (textOffset > 0) {
      return parent
          .child(index())
          .withText(parent.child(index()).text!.substring(0, textOffset));
    }
    return index() == 0 ? null : parent.child(index() - 1);
  }

  List<Mark> get marks {
    if (!parent.isTextblock || parent.content.isEmpty) return const [];
    var offset = 0;
    Node? before, after;
    for (final n in parent.content) {
      if (offset < parentOffset && parentOffset < offset + n.nodeSize) {
        return n.marks;
      }
      if (offset + n.nodeSize == parentOffset) before = n;
      if (offset == parentOffset) {
        after = n;
        break;
      }
      offset += n.nodeSize;
    }
    final base = before ?? after;
    return List.unmodifiable(
      (base?.marks ?? const <Mark>[]).where(
        (mark) =>
            doc.schema.marks[mark.type]?.inclusive != false ||
            (before != null &&
                after != null &&
                before.marks.contains(mark) &&
                after.marks.contains(mark)),
      ),
    );
  }

  static ResolvedPos _resolve(Node doc, int pos) {
    RangeError.checkValueInInterval(pos, 0, doc.content.size, 'pos');
    final bi = doc.content.indexAt(pos);
    final bs = doc.content.positionAt(bi);
    final nodes = <Node>[doc], indices = <int>[bi], starts = <int>[0];
    var parent = doc, offset = pos, index = bi, childStart = bs, textOffset = 0;
    while (index < parent.childCount) {
      final child = parent.child(index);
      if (offset == childStart || child.isLeaf) {
        if (child.isText) textOffset = offset - childStart;
        break;
      }
      offset -= childStart + 1;
      starts.add(starts.last + childStart + 1);
      nodes.add(child);
      parent = child;
      index = parent.content.indexAt(offset);
      childStart = parent.content.positionAt(index);
      indices.add(index);
    }
    return ResolvedPos._(
      doc,
      pos,
      bi,
      bs,
      List.unmodifiable(nodes),
      List.unmodifiable(indices),
      List.unmodifiable(starts),
      offset,
      textOffset,
    );
  }
}

/// A textblock or atom and its ProseMirror boundary in the owning document.
class DocumentRow {
  const DocumentRow(this.node, this.position, this.path);
  final Node node;
  final int position;
  final List<int> path;
}

/// Row indices before and after an immutable document change.
class RowChange {
  const RowChange(this.from, this.oldTo, this.newTo);
  final int from, oldTo, newTo;
}

extension DocumentRows on Node {
  /// Finds shared row prefixes/suffixes by skipping persistent subtrees, including
  /// when an insertion rotates or splits their containing sum tree.
  RowChange changedRows(Node next) {
    int common(bool reverse) {
      final a = <(_Tree, String)>[
        if (content.blocks?._root case final root?) (root, ''),
      ];
      final b = <(_Tree, String)>[
        if (next.content.blocks?._root case final root?) (root, ''),
      ];
      var count = 0;
      void expand(List<(_Tree, String)> stack) {
        final (tree, context) = stack.removeLast();
        stack.addAll(
          reverse
              ? [(tree.left!, context), (tree.right!, context)]
              : [(tree.right!, context), (tree.left!, context)],
        );
      }

      while (a.isNotEmpty && b.isNotEmpty) {
        final (left, leftContext) = a.last;
        final (right, rightContext) = b.last;
        if (leftContext != rightContext) break;
        if (identical(left, right) ||
            left.node != null && identical(left.node, right.node)) {
          count += left.summary.rowCount;
          a.removeLast();
          b.removeLast();
        } else if (left.node != null && right.node != null) {
          final x = left.node!, y = right.node!;
          if (x.type == 'tableRow' ||
              y.type == 'tableRow' ||
              x.isTextblock ||
              x.isLeaf ||
              y.isTextblock ||
              y.isLeaf ||
              x.type != y.type ||
              !_equal(x.attrs, y.attrs)) {
            break;
          }
          a.removeLast();
          b.removeLast();
          if (x.content.blocks?._root case final root?) {
            a.add((root, '$leftContext/${x.type}'));
          }
          if (y.content.blocks?._root case final root?) {
            b.add((root, '$rightContext/${y.type}'));
          }
        } else if (left.node == null &&
            (right.node != null ||
                left.summary.rowCount >= right.summary.rowCount)) {
          expand(a);
        } else {
          expand(b);
        }
      }
      return count;
    }

    if (identical(this, next)) return RowChange(rowCount, rowCount, rowCount);
    final prefix = common(false);
    final suffix = math.min(
      common(true),
      math.min(rowCount, next.rowCount) - prefix,
    );
    return RowChange(prefix, rowCount - suffix, next.rowCount - suffix);
  }
}
