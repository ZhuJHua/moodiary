import 'package:flutter/material.dart';
import 'package:moodiary_core/moodiary_core.dart';

/// 工具栏上的一枚动作。不带激活态：只触发命令，不反映当前选区格式状态。
class EditorToolbarAction {
  final IconData icon;
  final String? tooltip;
  final VoidCallback onPressed;

  const EditorToolbarAction({
    required this.icon,
    this.tooltip,
    required this.onPressed,
  });
}

/// 移动端编辑器底部工具栏，Markdown 与 RichText 共用以保证视觉一致。放在 `Column`
/// 底部即可——靠 `Scaffold.resizeToAvoidBottomInset` 自动顶到键盘上方。
class EditorToolbar extends StatelessWidget {
  /// 行首的媒体 / 详情等旁路动作。
  final List<EditorToolbarAction> leadingActions;

  /// 文字格式化动作。
  final List<EditorToolbarAction> formatActions;

  const EditorToolbar({
    super.key,
    this.leadingActions = const [],
    required this.formatActions,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final hasLeading = leadingActions.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(
            context,
          ).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                for (final action in leadingActions)
                  _ToolbarButton(action: action),
                if (hasLeading) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 1,
                    height: 24,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 4),
                ],
                for (final action in formatActions)
                  _ToolbarButton(action: action),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final EditorToolbarAction action;

  const _ToolbarButton({required this.action});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final button = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: action.onPressed,
          borderRadius: BorderRadius.circular(8),
          highlightColor: scheme.surfaceContainerHighest,
          child: Container(
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(action.icon, size: 20, color: scheme.onSurface),
          ),
        ),
      ),
    );
    final tooltip = action.tooltip;
    if (tooltip == null) return button;
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: button,
    );
  }
}
