enum EditorBlock {
  paragraph,
  heading1,
  heading2,
  heading3,
  heading4,
  heading5,
  heading6,
  blockquote,
  codeBlock;

  int? get headingLevel => switch (this) {
    heading1 => 1,
    heading2 => 2,
    heading3 => 3,
    heading4 => 4,
    heading5 => 5,
    heading6 => 6,
    _ => null,
  };
}

enum EditorList { bullet, ordered, task }

enum EditorPanel { insert, format, divider, block }

enum EditorSelectionKind { caret, text, node }

enum EditorMark { bold, italic, underline, strike, code, highlight, link }

enum EditorNodeType { image, video, audio, attachment, horizontalRule }

typedef EditorSelectedNode = ({
  EditorNodeType type,
  Map<String, Object?> attrs,
});

typedef EditorLinkInfo = ({String href, String text});

final class EditorState {
  final Set<EditorMark> marks;
  final EditorBlock block;
  final EditorList? list;
  final bool canIndent;
  final bool canOutdent;
  final bool canUndo;
  final bool canRedo;
  final EditorSelectionKind selection;
  final EditorSelectedNode? node;
  final bool inTable;
  final EditorLinkInfo? link;
  final String selectedText;

  const EditorState({
    this.marks = const {},
    this.block = .paragraph,
    this.list,
    this.canIndent = false,
    this.canOutdent = false,
    this.canUndo = false,
    this.canRedo = false,
    this.selection = .caret,
    this.node,
    this.inTable = false,
    this.link,
    this.selectedText = '',
  });

  static const empty = EditorState();

  factory EditorState.fromJson(Map<String, Object?> json) {
    final marks = json['marks'];
    final node = json['node'];
    final link = json['link'];
    final nodeType = node is Map
        ? EditorNodeType.values.asNameMap()[node['type']]
        : null;
    return EditorState(
      marks: {
        if (marks is Map)
          for (final mark in EditorMark.values)
            if (marks[mark.name] == true) mark,
      },
      block: EditorBlock.values.asNameMap()[json['block']] ?? .paragraph,
      list: EditorList.values.asNameMap()[json['list']],
      canIndent: json['canIndent'] == true,
      canOutdent: json['canOutdent'] == true,
      canUndo: json['canUndo'] == true,
      canRedo: json['canRedo'] == true,
      selection:
          EditorSelectionKind.values.asNameMap()[json['selection']] ?? .caret,
      node: node is Map && nodeType != null
          ? (
              type: nodeType,
              attrs: {
                if (node['attrs'] case final Map attrs)
                  for (final e in attrs.entries) '${e.key}': e.value,
              },
            )
          : null,
      inTable: json['inTable'] == true,
      link: link is Map && link['href'] is String
          ? (
              href: link['href'] as String,
              text: link['text'] is String ? link['text'] as String : '',
            )
          : null,
      selectedText: json['selectedText'] is String
          ? json['selectedText'] as String
          : '',
    );
  }

  bool has(EditorMark mark) => marks.contains(mark);

  bool get textSelected => selection == .text;

  bool get inCodeBlock => block == .codeBlock;

  EditorNodeType? get nodeType => selection == .node ? node?.type : null;
}
