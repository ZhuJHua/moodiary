import 'package:flutter/services.dart';
import 'package:mui/mui.dart';


/// 圆角胶囊筛选条的单个条目。[accentColor] 提供时以小圆点 + 选中态着色（分类色）；
/// [icon] 提供时改为前置图标（媒体类型等）；二者皆空则纯文字。
class MChipData<T> {
  final T value;
  final String label;
  final IconData? icon;
  final Color? accentColor;

  const MChipData({
    required this.value,
    required this.label,
    this.icon,
    this.accentColor,
  });
}

/// 横向滚动的圆角胶囊筛选条（首页日记分类同款）：选中项高亮，右侧渐隐，切换时
/// 自动滚动到可见，点选带轻触反馈。[trailing] 可放一个尾随按钮（如分类切换器）。
class MChipBar<T> extends StatefulWidget {
  final List<MChipData<T>> items;
  final T selected;
  final ValueChanged<T> onSelected;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final double height;

  /// 右侧渐隐所融入的底色，默认取 surface。
  final Color? fadeColor;

  const MChipBar({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
    this.trailing,
    this.padding = const .symmetric(horizontal: 12),
    this.height = 32,
    this.fadeColor,
  });

  @override
  State<MChipBar<T>> createState() => _MChipBarState<T>();
}

class _MChipBarState<T> extends State<MChipBar<T>> {
  final Map<T, GlobalKey> _chipKeys = {};

  @override
  void didUpdateWidget(covariant MChipBar<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
    }
  }

  void _revealSelected() {
    if (!mounted) return;
    final chipContext = _chipKeys[widget.selected]?.currentContext;
    if (chipContext == null) return;
    Scrollable.ensureVisible(
      chipContext,
      alignment: 0.5,
      duration: Durations.medium2,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fade = widget.fadeColor ?? context.theme.colors.surface;
    final values = {for (final it in widget.items) it.value};
    _chipKeys.removeWhere((k, _) => !values.contains(k));

    final scroller = Stack(
      children: [
        ListView(
          scrollDirection: .horizontal,
          padding: widget.padding,
          children: [
            for (var i = 0; i < widget.items.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Center(child: _chip(context, widget.items[i])),
            ],
            const SizedBox(width: 4),
          ],
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Container(
              width: 20,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [fade.withValues(alpha: 0), fade],
                ),
              ),
            ),
          ),
        ),
      ],
    );

    return SizedBox(
      height: widget.height,
      child: widget.trailing == null
          ? scroller
          : Row(
              children: [
                Expanded(child: scroller),
                widget.trailing!,
              ],
            ),
    );
  }

  Widget _chip(BuildContext context, MChipData<T> item) {
    final key = _chipKeys.putIfAbsent(item.value, GlobalKey.new);
    final scheme = context.theme.colors;
    final dark = context.theme.isDark;
    final selected = widget.selected == item.value;
    final color = item.accentColor;

    final Color bg;
    final Color fg;
    if (!selected) {
      bg = scheme.surfaceContainerHigh;
      fg = scheme.onSurfaceVariant;
    } else if (color == null) {
      bg = scheme.secondaryContainer;
      fg = scheme.onSecondaryContainer;
    } else {
      bg = .alphaBlend(
        color.withValues(alpha: dark ? 0.30 : 0.16),
        scheme.surfaceContainerHigh,
      );
      fg = categoryTextColor(color, dark: dark);
    }

    return KeyedSubtree(
      key: key,
      child: AnimatedContainer(
        duration: Durations.short4,
        curve: Curves.easeOut,
        height: widget.height,
        decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
        child: Material(
          type: .transparency,
          shape: const StadiumBorder(),
          clipBehavior: .antiAlias,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onSelected(item.value);
            },
            child: Padding(
              padding: const .symmetric(horizontal: 13),
              child: Row(
                mainAxisSize: .min,
                children: [
                  if (item.icon != null) ...[
                    Icon(item.icon, size: 16, color: fg),
                    const SizedBox(width: 6),
                  ] else if (color != null) ...[
                    AnimatedContainer(
                      duration: Durations.short4,
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(color: color, shape: .circle),
                    ),
                    const SizedBox(width: 6),
                  ],
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: AnimatedDefaultTextStyle(
                      duration: Durations.short4,
                      // 选中态配色：无强调色走 onSecondaryContainer，业务强调色
                      // （分类色）在其上 copyWith 覆盖，对齐 bg 那侧的 fg 计算。
                      style: selected
                          ? (color == null
                                ? context
                                      .theme
                                      .typography
                                      .labelMedium
                                      .emphasized
                                      .onSecondaryContainer
                                : context
                                      .theme
                                      .typography
                                      .labelMedium
                                      .emphasized
                                      .onSecondaryContainer
                                      .copyWith(color: fg))
                          : context
                                .theme
                                .typography
                                .labelMedium
                                .onSurfaceVariant,
                      child: Text(item.label, maxLines: 1, overflow: .ellipsis),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
