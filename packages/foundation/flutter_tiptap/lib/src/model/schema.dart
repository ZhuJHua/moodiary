part of '../model.dart';

class NodeSpec {
  const NodeSpec({
    this.textblock = false,
    this.inline = false,
    this.leaf = false,
    this.attrs = const {},
    this.content,
    this.group = 'block',
    this.code = false,
  });
  final String? content;
  final String group;
  final bool code;
  final bool textblock;
  final bool inline;
  final bool leaf;
  final Map<String, Object?> attrs;
}

class MarkSpec {
  const MarkSpec({
    this.inclusive = true,
    this.keepOnSplit = true,
    this.excludes = const {},
    this.attrs = const {},
  });
  final bool inclusive;
  final bool keepOnSplit;
  final Set<String> excludes;
  final Map<String, Object?> attrs;
}

/// Defines node and mark types, content rules and JSON parsing for documents.
class Schema {
  Schema({
    required Map<String, NodeSpec> nodes,
    required Map<String, MarkSpec> marks,
    Set<String> opaqueAtomTypes = const {'horizontalRule', 'image'},
  }) : nodes = Map.unmodifiable(nodes),
       marks = Map.unmodifiable(marks),
       opaqueAtomTypes = Set.unmodifiable(opaqueAtomTypes);

  factory Schema.standard({
    Set<String> opaqueAtomTypes = const {'horizontalRule', 'image'},
  }) => Schema(
    opaqueAtomTypes: opaqueAtomTypes,
    nodes: const {
      'doc': NodeSpec(attrs: {'v': 2}, content: 'block+', group: ''),
      'paragraph': NodeSpec(textblock: true),
      'heading': NodeSpec(textblock: true, attrs: {'level': 1}),
      'text': NodeSpec(inline: true, leaf: true, group: 'inline'),
      'hardBreak': NodeSpec(inline: true, leaf: true, group: 'inline'),
      'bulletList': NodeSpec(content: 'listItem+'),
      'orderedList': NodeSpec(
        content: 'listItem+',
        attrs: {'start': 1, 'type': null},
      ),
      'listItem': NodeSpec(content: 'paragraph block*', group: ''),
      'taskList': NodeSpec(content: 'taskItem+'),
      'taskItem': NodeSpec(
        content: 'paragraph block*',
        group: '',
        attrs: {'checked': false},
      ),
      'blockquote': NodeSpec(content: 'block+'),
      'codeBlock': NodeSpec(
        textblock: true,
        code: true,
        content: 'text*',
        attrs: {'language': null},
      ),
      'table': NodeSpec(content: 'tableRow+'),
      'tableRow': NodeSpec(content: 'table_cell*', group: ''),
      'tableCell': NodeSpec(
        content: 'block+',
        group: 'table_cell',
        attrs: {'colspan': 1, 'rowspan': 1, 'colwidth': null, 'align': null},
      ),
      'tableHeader': NodeSpec(
        content: 'block+',
        group: 'table_cell',
        attrs: {'colspan': 1, 'rowspan': 1, 'colwidth': null, 'align': null},
      ),
      'image': NodeSpec(
        leaf: true,
        attrs: {'src': null, 'name': null, 'widthPercent': null},
      ),
      'video': NodeSpec(
        leaf: true,
        attrs: {'src': null, 'name': null, 'widthPercent': null},
      ),
      'audio': NodeSpec(leaf: true, attrs: {'src': null, 'name': null}),
      'attachment': NodeSpec(
        leaf: true,
        attrs: {'src': null, 'name': null, 'mime': null, 'size': null},
      ),
      referenceNodeType: NodeSpec(
        inline: true,
        leaf: true,
        group: 'inline',
        attrs: {'id': null, 'label': null},
      ),
      'horizontalRule': NodeSpec(
        leaf: true,
        attrs: {'variant': 'solid', 'label': null},
      ),
    },
    // ProseMirror orders marks by schema rank, not by the order they were applied.
    marks: const {
      'link': MarkSpec(
        inclusive: false,
        keepOnSplit: false,
        attrs: {'href': null},
      ),
      'bold': MarkSpec(),
      'code': MarkSpec(excludes: {'*'}),
      'italic': MarkSpec(),
      'strike': MarkSpec(),
      'underline': MarkSpec(),
      'highlight': MarkSpec(attrs: {'color': null}),
    },
  );

  final Map<String, ContentMatch> _matches = {};
  ContentMatch contentMatch(String type) => _matches.putIfAbsent(type, () {
    final spec = nodes[type];
    final expression =
        spec?.content ?? (spec?.textblock == true ? 'inline*' : '');
    return ContentMatch._compile(this, expression);
  });
  bool validContent(String type, Fragment content) {
    final result = contentMatch(type).matchFragment(content);
    return result != null &&
        result.validEnd &&
        (nodes[type]?.code != true || content.every((n) => n.marks.isEmpty));
  }

  bool compatibleContent(String a, String b) =>
      a == b ||
      contentMatch(a).next.any((e) => contentMatch(b).matchType(e.$1) != null);
  Node? createAndFill(
    String type, {
    Map<String, Object?>? attrs,
    Fragment? content,
  }) {
    var fragment = content ?? Fragment.empty;
    final before = contentMatch(type).fillBefore(fragment);
    if (before == null) return null;
    fragment = before.append(fragment);
    final after = contentMatch(type)
        .matchFragment(fragment)
        ?.fillBefore(Fragment.empty, toEnd: true);
    return after == null
        ? null
        : node(type, attrs: attrs, content: fragment.append(after));
  }

  final Map<String, NodeSpec> nodes;
  final Map<String, MarkSpec> marks;
  final Set<String> opaqueAtomTypes;

  Mark mark(String type, [Map<String, Object?>? attrs]) =>
      Mark._(type, _attrs(marks[type]?.attrs ?? const {}, attrs));

  List<Mark> addMark(List<Mark> set, Mark mark) {
    final spec = marks[mark.type];
    if (set.any((m) => m == mark)) return set;
    if (set.any(
      (m) =>
          m.type != mark.type &&
          (marks[m.type]?.excludes.contains('*') == true ||
              marks[m.type]?.excludes.contains(mark.type) == true),
    )) {
      return set;
    }
    final result =
        set
            .where(
              (m) =>
                  m.type != mark.type &&
                  spec?.excludes.contains('*') != true &&
                  spec?.excludes.contains(m.type) != true,
            )
            .toList()
          ..add(mark);
    final ranks = marks.keys.toList();
    int rank(String name) {
      final i = ranks.indexOf(name);
      return i < 0 ? ranks.length : i;
    }

    result.sort((a, b) => rank(a.type).compareTo(rank(b.type)));
    return List.unmodifiable(result);
  }

  Node node(
    String type, {
    Map<String, Object?>? attrs,
    Iterable<Node> content = const [],
    String? text,
    List<Mark> marks = const [],
  }) {
    final spec = nodes[type];
    if (spec == null) {
      throw ArgumentError.value(type, 'type', 'Unregistered node');
    }
    final values = _attrs(spec.attrs, attrs);
    if (type == 'heading' &&
        (values['level'] is! int ||
            (values['level']! as int) < 1 ||
            (values['level']! as int) > 6)) {
      throw ArgumentError.value(values['level'], 'level');
    }
    if (type == 'text' && (text == null || text.isEmpty)) {
      throw ArgumentError('Text nodes must be nonempty');
    }
    return Node._(
      this,
      type,
      values,
      spec.textblock || spec.inline
          ? Fragment(content)
          : Fragment.blocks(content),
      text,
      marks.isEmpty ? const [] : List.unmodifiable(marks),
      null,
    );
  }

  Node fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    if (!nodes.containsKey(type)) {
      final raw = _freeze(json)! as Map<String, Object?>;
      return Node._(this, type, const {}, Fragment.empty, null, const [], raw);
    }
    return node(
      type,
      attrs: _normalizeNodeAttrs(
        type,
        (json['attrs'] as Map?)?.cast<String, Object?>(),
      ),
      text: json['text'] as String?,
      content: (json['content'] as List? ?? const []).map(
        (n) => fromJson((n as Map).cast<String, dynamic>()),
      ),
      marks: (json['marks'] as List? ?? const []).map((m) {
        final data = m as Map;
        final name = data['type'] as String;
        if (!marks.containsKey(name)) {
          return Mark._(
            name,
            _attrs(const {}, (data['attrs'] as Map?)?.cast<String, Object?>()),
            _freeze(data)! as Map<String, Object?>,
          );
        }
        return mark(
          name,
          name == 'link'
              ? {'href': (data['attrs'] as Map?)?['href']}
              : (data['attrs'] as Map?)?.cast<String, Object?>(),
        );
      }).toList(),
    );
  }

  Node parse(String json) =>
      fromJson((jsonDecode(json) as Map).cast<String, dynamic>());
  Future<Node> parseAsync(String json) => Isolate.run(() => parse(json));
}

class Mark {
  const Mark._(this.type, this.attrs, [this._raw]);
  final Map<String, Object?>? _raw;
  final String type;
  final Map<String, Object?> attrs;
  Map<String, Object?> toJson() =>
      _raw ?? {'type': type, if (attrs.isNotEmpty) 'attrs': attrs};
  @override
  bool operator ==(Object other) =>
      other is Mark &&
      type == other.type &&
      _equal(attrs, other.attrs) &&
      _equal(_raw, other._raw);
  @override
  int get hashCode => type.hashCode;
}
