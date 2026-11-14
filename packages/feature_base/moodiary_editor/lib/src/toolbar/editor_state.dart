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

enum EditorPanel { insert, format, block }

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
  final bool contentError;

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
    this.contentError = false,
  });

  static const empty = EditorState();

  @override
  bool operator ==(Object other) =>
      other is EditorState &&
      block == other.block &&
      list == other.list &&
      canIndent == other.canIndent &&
      canOutdent == other.canOutdent &&
      canUndo == other.canUndo &&
      canRedo == other.canRedo &&
      selection == other.selection &&
      inTable == other.inTable &&
      link == other.link &&
      contentError == other.contentError &&
      selectedText == other.selectedText &&
      marks.length == other.marks.length &&
      marks.containsAll(other.marks) &&
      node?.type == other.node?.type &&
      (node == null ||
          node!.attrs.length == other.node!.attrs.length &&
              node!.attrs.entries.every(
                (e) => other.node!.attrs[e.key] == e.value,
              ));
  @override
  int get hashCode => Object.hash(
    block,
    list,
    canIndent,
    canOutdent,
    canUndo,
    canRedo,
    selection,
    inTable,
    link,
    selectedText,
    Object.hashAllUnordered(marks),
    node?.type,
  );
  bool has(EditorMark mark) => marks.contains(mark);

  bool get textSelected => selection == .text;

  bool get inCodeBlock => block == .codeBlock;

  EditorNodeType? get nodeType =>
      selection == .node || selection == .caret && node?.type == .horizontalRule
      ? node?.type
      : null;
}
