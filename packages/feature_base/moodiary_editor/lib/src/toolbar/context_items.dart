import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';

import 'editor_state.dart';
import 'panel_parts.dart';
import 'toolbar_button.dart';

enum ToolbarPopover { width, table }

enum ToolbarContextKind {
  none,
  text,
  block,
  table,
  list,
  code;

  bool get replacesTools => this == .text || this == .block;
}

typedef ToolbarContext = ({ToolbarContextKind kind, List<Widget> items});

ToolbarContext buildToolbarContext(
  BuildContext context, {
  required EditorState state,
  required EditorExec exec,
  required ToolbarPopover? popover,
  required bool dividerPanelOpen,
  required ValueChanged<ToolbarPopover> onTogglePopover,
  required VoidCallback onToggleDividerPanel,
  required VoidCallback onRenameMedia,
}) {
  final s = state;
  final t = context.l10n.editor.toolbar;
  Widget button(
    IconData icon,
    String tooltip,
    VoidCallback? onTap, {
    bool pressed = false,
  }) => ToolbarIconButton(
    icon: icon,
    tooltip: tooltip,
    tone: pressed ? .pressed : .plain,
    onTap: onTap,
  );
  Widget width() => button(
    LucideIcons.moveHorizontal,
    t.width,
    () => onTogglePopover(.width),
    pressed: popover == .width,
  );
  final moveAndDelete = [
    button(LucideIcons.arrowUp, t.moveUp, () => exec(.moveBlockUp)),
    button(LucideIcons.arrowDown, t.moveDown, () => exec(.moveBlockDown)),
    button(LucideIcons.trash2, t.delete, () => exec(.deleteBlock)),
  ];
  Widget nameChip(IconData icon, String placeholder) => ToolbarNameChip(
    icon: icon,
    name: s.node?.attrs['name'] as String?,
    placeholder: placeholder,
    tooltip: t.rename,
    onTap: onRenameMedia,
  );
  const none = (kind: ToolbarContextKind.none, items: <Widget>[]);
  if (s.textSelected && !s.inCodeBlock) {
    return (kind: .text, items: const []);
  }
  final block = switch (s.nodeType) {
    .image => [
      nameChip(LucideIcons.image, t.image),
      button(LucideIcons.maximize2, t.view, () => exec(.previewImage)),
      width(),
      ...moveAndDelete,
    ],
    .video => [nameChip(LucideIcons.video, t.video), width(), ...moveAndDelete],
    .audio => [nameChip(LucideIcons.music, t.audio), ...moveAndDelete],
    .attachment => [
      nameChip(LucideIcons.paperclip, t.attachment),
      button(LucideIcons.externalLink, t.open, () => exec(.openAttachment)),
      ...moveAndDelete,
    ],
    .horizontalRule => [
      ToolbarLabelButton(
        icon: LucideIcons.chevronDown,
        label: t.style,
        pressed: dividerPanelOpen,
        onTap: onToggleDividerPanel,
      ),
      ...moveAndDelete,
    ],
    null => null,
  };
  if (block != null) return (kind: .block, items: block);
  if (s.link != null) return none;
  if (s.inTable) {
    return (
      kind: .table,
      items: [
        button(
          LucideIcons.betweenHorizontalEnd,
          t.tableAddRow,
          () => exec(.tableAddRowAfter),
        ),
        button(
          LucideIcons.listX,
          t.tableDeleteRow,
          () => exec(.tableDeleteRow),
        ),
        button(
          LucideIcons.betweenVerticalEnd,
          t.tableAddColumn,
          () => exec(.tableAddColumnAfter),
        ),
        button(
          LucideIcons.squareMinus,
          t.tableDeleteColumn,
          () => exec(.tableDeleteColumn),
        ),
        button(
          LucideIcons.tableProperties,
          t.tableMenu,
          () => onTogglePopover(.table),
          pressed: popover == .table,
        ),
      ],
    );
  }
  if (s.list != null) {
    return (
      kind: .list,
      items: [
        button(
          LucideIcons.listIndentDecrease,
          t.outdent,
          s.canOutdent ? () => exec(.outdent) : null,
        ),
        button(
          LucideIcons.listIndentIncrease,
          t.indent,
          s.canIndent ? () => exec(.indent) : null,
        ),
      ],
    );
  }
  if (s.inCodeBlock) {
    return (
      kind: .code,
      items: [
        button(LucideIcons.copy, t.copyCode, () => exec(.copyCode)),
        button(LucideIcons.arrowDownToLine, t.exitCode, () => exec(.exitCode)),
      ],
    );
  }
  return none;
}
