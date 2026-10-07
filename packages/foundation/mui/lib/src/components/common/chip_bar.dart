import 'package:flutter/services.dart';
import 'package:mui/mui.dart';

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

class MChipBar<T> extends StatefulWidget {
  final List<MChipData<T>> items;
  final T selected;
  final ValueChanged<T> onSelected;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final double height;

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
              Center(
                child: MChip(
                  key: _chipKeys.putIfAbsent(
                    widget.items[i].value,
                    GlobalKey.new,
                  ),
                  item: widget.items[i],
                  selected: widget.selected == widget.items[i].value,
                  height: widget.height,
                  onSelected: widget.onSelected,
                ),
              ),
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
}

class MChip<T> extends StatelessWidget {
  final MChipData<T> item;
  final bool selected;
  final ValueChanged<T> onSelected;
  final double height;

  const MChip({
    super.key,
    required this.item,
    required this.selected,
    required this.onSelected,
    this.height = 32,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final dark = context.theme.isDark;
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

    return AnimatedContainer(
      duration: Durations.short4,
      curve: Curves.easeOut,
      height: height,
      decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
      child: MInkWell(
        shape: const StadiumBorder(),
        onTap: () {
          HapticFeedback.selectionClick();
          onSelected(item.value);
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
                      : context.theme.typography.labelMedium.onSurfaceVariant,
                  child: Text(item.label, maxLines: 1, overflow: .ellipsis),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
