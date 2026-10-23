import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';

import 'editor_command.dart';
import 'editor_state.dart';
import 'panel_parts.dart';

class FormatPanel extends StatelessWidget {
  final EditorState state;
  final EditorExec exec;

  const FormatPanel({super.key, required this.state, required this.exec});

  @override
  Widget build(BuildContext context) {
    final t = context.l10n.editor.toolbar;
    final typo = context.theme.typography;
    final marksEnabled = !state.inCodeBlock;
    Widget heading(int level, double size) => PanelSegment(
      selected: state.block.headingLevel == level,
      onTap: () => exec(.setHeading, {'level': level}),
      semanticLabel: 'H$level',
      child: SegmentText(
        'H$level',
        style: typo.titleMedium.emphasized.onSurface.copyWith(fontSize: size),
      ),
    );
    Widget mark(
      EditorMark mark,
      IconData icon,
      String label,
      EditorCommand c,
    ) => PanelSegment(
      selected: state.has(mark),
      onTap: marksEnabled ? () => exec(c) : null,
      semanticLabel: label,
      child: Icon(icon, size: 20),
    );
    Widget list(
      EditorList list,
      IconData icon,
      String label,
      EditorCommand c,
    ) => PanelSegment(
      selected: state.list == list,
      onTap: () => exec(c),
      semanticLabel: label,
      child: _IconLabel(icon: icon, label: label, vertical: true),
    );
    return PanelScroll(
      top: 16,
      gap: 12,
      children: [
        PanelSegmentGroup(
          height: 48,
          children: [
            PanelSegment(
              selected: state.block == .paragraph,
              onTap: () => exec(.setParagraph),
              semanticLabel: t.paragraph,
              child: SegmentText(t.paragraph, style: typo.labelLarge.onSurface),
            ),
            heading(1, 19),
            heading(2, 17),
            heading(3, 15),
          ],
        ),
        SizedBox(
          height: 52,
          child: Row(
            spacing: 10,
            children: [
              Expanded(
                flex: 4,
                child: PanelSegmentGroup(
                  children: [
                    mark(.bold, LucideIcons.bold, t.bold, .toggleBold),
                    mark(.italic, LucideIcons.italic, t.italic, .toggleItalic),
                    mark(
                      .underline,
                      LucideIcons.underline,
                      t.underline,
                      .toggleUnderline,
                    ),
                    mark(
                      .strike,
                      LucideIcons.strikethrough,
                      t.strike,
                      .toggleStrike,
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: PanelSegmentGroup(
                  children: [
                    mark(
                      .highlight,
                      LucideIcons.highlighter,
                      t.highlight,
                      .toggleHighlight,
                    ),
                    mark(.code, LucideIcons.code, t.inlineCode, .toggleCode),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 60,
          child: Row(
            spacing: 10,
            children: [
              Expanded(
                flex: 3,
                child: PanelSegmentGroup(
                  children: [
                    list(
                      .bullet,
                      LucideIcons.list,
                      t.bulletList,
                      .toggleBulletList,
                    ),
                    list(
                      .ordered,
                      LucideIcons.listOrdered,
                      t.orderedList,
                      .toggleOrderedList,
                    ),
                    list(
                      .task,
                      LucideIcons.listTodo,
                      t.taskList,
                      .toggleTaskList,
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: PanelSegmentGroup(
                  children: [
                    PanelSegment(
                      onTap: state.canOutdent ? () => exec(.outdent) : null,
                      semanticLabel: t.outdent,
                      child: _IconLabel(
                        icon: LucideIcons.listIndentDecrease,
                        label: t.outdent,
                        vertical: true,
                      ),
                    ),
                    PanelSegment(
                      onTap: state.canIndent ? () => exec(.indent) : null,
                      semanticLabel: t.indent,
                      child: _IconLabel(
                        icon: LucideIcons.listIndentIncrease,
                        label: t.indent,
                        vertical: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 52,
          child: Row(
            spacing: 10,
            children: [
              Expanded(
                flex: 2,
                child: PanelSegmentGroup(
                  children: [
                    PanelSegment(
                      selected: state.block == .blockquote,
                      onTap: () => exec(.toggleBlockquote),
                      semanticLabel: t.quote,
                      child: _IconLabel(
                        icon: LucideIcons.textQuote,
                        label: t.quote,
                      ),
                    ),
                    PanelSegment(
                      selected: state.block == .codeBlock,
                      onTap: () => exec(.toggleCodeBlock),
                      semanticLabel: t.codeBlock,
                      child: _IconLabel(
                        icon: LucideIcons.squareCode,
                        label: t.codeBlock,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _PanelButton(
                  onTap: () => exec(.clearFormatting),
                  child: _IconLabel(
                    icon: LucideIcons.removeFormatting,
                    label: t.clearFormat,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PanelButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const _PanelButton({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return MInkWell(
      onTap: onTap,
      borderRadius: .circular(context.theme.radii.md),
      child: Container(
        alignment: .center,
        decoration: BoxDecoration(
          color: panelGroupColor(context),
          borderRadius: .circular(context.theme.radii.md),
        ),
        child: IconTheme.merge(
          data: IconThemeData(color: colors.onSurface),
          child: child,
        ),
      ),
    );
  }
}

class _IconLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool vertical;

  const _IconLabel({
    required this.icon,
    required this.label,
    this.vertical = false,
  });

  @override
  Widget build(BuildContext context) {
    final typo = context.theme.typography;
    final text = SegmentText(
      label,
      style: vertical ? typo.labelSmall.onSurface : typo.labelLarge.onSurface,
    );
    return vertical
        ? Column(
            mainAxisAlignment: .center,
            spacing: 3,
            children: [Icon(icon, size: 20), text],
          )
        : Row(
            mainAxisAlignment: .center,
            mainAxisSize: .min,
            spacing: 6,
            children: [
              Icon(icon, size: 18),
              Flexible(child: text),
            ],
          );
  }
}
