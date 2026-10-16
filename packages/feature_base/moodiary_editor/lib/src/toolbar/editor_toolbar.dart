import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';

import 'context_items.dart';
import 'toolbar_button.dart';
import 'toolbar_tools.dart';

class EditorToolbar extends StatelessWidget {
  final ToolbarContextKind contextKind;
  final List<Widget> contextItems;
  final List<ToolbarTool> tools;
  final ToolbarButtonTone Function(ToolbarTool tool) toneOf;
  final bool Function(ToolbarTool tool) enabledOf;
  final ValueChanged<ToolbarTool> onTool;
  final bool keyboardShown;
  final VoidCallback onKeyboardToggle;

  const EditorToolbar({
    super.key,
    this.contextKind = .none,
    this.contextItems = const [],
    required this.tools,
    required this.toneOf,
    required this.enabledOf,
    required this.onTool,
    required this.keyboardShown,
    required this.onKeyboardToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final t = context.l10n.editor.toolbar;
    final grouped = contextItems.isNotEmpty && !contextKind.replacesTools;
    final row = EdgeFadeScroll(
      key: ValueKey(contextKind),
      child: Row(
        spacing: 4,
        children: [
          if (grouped) ...[
            ToolbarContextGroup(children: contextItems),
            const ToolbarDivider(),
          ] else
            ...contextItems,
          for (final tool in tools)
            ToolbarIconButton(
              icon: tool.icon,
              tooltip: tool.label(context),
              tone: toneOf(tool),
              onTap: enabledOf(tool) ? () => onTool(tool) : null,
            ),
        ],
      ),
    );
    return ExcludeFocus(
      child: Container(
        height: 45,
        padding: const .symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          border: Border(
            top: BorderSide(color: colors.surfaceContainerHighest),
          ),
        ),
        child: Row(
          children: [
            Expanded(child: row),
            if (tools.isNotEmpty || contextItems.isNotEmpty)
              const ToolbarDivider(),
            ToolbarIconButton(
              icon: keyboardShown
                  ? LucideIcons.chevronDown
                  : LucideIcons.keyboard,
              tooltip: keyboardShown ? t.hideKeyboard : t.showKeyboard,
              onTap: onKeyboardToggle,
            ),
          ],
        ),
      ),
    );
  }
}

class EdgeFadeScroll extends StatefulWidget {
  final Widget child;

  const EdgeFadeScroll({super.key, required this.child});

  @override
  State<EdgeFadeScroll> createState() => _EdgeFadeScrollState();
}

class _EdgeFadeScrollState extends State<EdgeFadeScroll> {
  static const _fade = 28.0;

  bool _hiddenBefore = false;
  bool _hiddenAfter = false;

  void _update(ScrollMetrics m) {
    final before = m.pixels > m.minScrollExtent + 0.5;
    final after = m.pixels < m.maxScrollExtent - 0.5;
    if (before == _hiddenBefore && after == _hiddenAfter) return;
    setState(() {
      _hiddenBefore = before;
      _hiddenAfter = after;
    });
  }

  @override
  Widget build(BuildContext context) {
    final solid = context.theme.colors.onSurface;
    final clear = solid.withValues(alpha: 0);
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) {
        _update(n.metrics);
        return false;
      },
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: (n) {
          _update(n.metrics);
          return false;
        },
        child: ShaderMask(
          blendMode: .dstIn,
          shaderCallback: (bounds) {
            final f = (_fade / bounds.width).clamp(0.0, 0.5);
            return LinearGradient(
              colors: [
                _hiddenBefore ? clear : solid,
                solid,
                solid,
                _hiddenAfter ? clear : solid,
              ],
              stops: [0, f, 1 - f, 1],
            ).createShader(bounds);
          },
          child: SingleChildScrollView(
            scrollDirection: .horizontal,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
