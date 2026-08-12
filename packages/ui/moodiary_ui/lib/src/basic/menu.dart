import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:mui/mui.dart';

/// 圆角弹出菜单的单个条目。
class MoodiaryMenuEntry<T> {
  final T value;
  final String label;
  final IconData? icon;

  /// 破坏性操作（如删除）以 error 色呈现。
  final bool isDestructive;
  final bool enabled;

  const MoodiaryMenuEntry({
    required this.value,
    required this.label,
    this.icon,
    this.isDestructive = false,
    this.enabled = true,
  });
}

const double _kMenuScreenPadding = 12.0;
const double _kMenuAnchorGap = 6.0;
const double _kMenuMinWidth = 168.0;
const double _kMenuMaxWidth = 320.0;

/// 圆角风格的弹出菜单：锚定在 [anchorContext] 对应的控件下方（空间不足时向上），
/// 选中项以次级容器色高亮并带勾选标记。返回被选中的值；未选择（点空白/返回键关闭）时为
/// null，故条目的值应为非空 —— 值本身为 null 的条目会与「未选择」混淆。
Future<T?> showMoodiaryMenu<T>({
  required BuildContext anchorContext,
  required List<MoodiaryMenuEntry<T>> entries,
  T? selected,
}) {
  final navigator = Navigator.of(anchorContext);
  final button = anchorContext.findRenderObject() as RenderBox;
  final overlay = navigator.overlay!.context.findRenderObject() as RenderBox;
  final anchor = Rect.fromPoints(
    button.localToGlobal(.zero, ancestor: overlay),
    button.localToGlobal(button.size.bottomRight(.zero), ancestor: overlay),
  );
  final preferAbove = anchor.top > overlay.size.height - anchor.bottom;

  return navigator.push(
    _MoodiaryMenuRoute<T>(
      anchor: anchor,
      entries: entries,
      selected: selected,
      preferAbove: preferAbove,
      capturedThemes: InheritedTheme.capture(
        from: anchorContext,
        to: navigator.context,
      ),
      barrierLabelText: MaterialLocalizations.of(
        anchorContext,
      ).modalBarrierDismissLabel,
    ),
  );
}

/// [PopupMenuButton] 的圆角替代：点击 [child] 弹出 [showMoodiaryMenu]。
class MoodiaryMenuButton<T> extends StatelessWidget {
  final List<MoodiaryMenuEntry<T>> entries;
  final ValueChanged<T> onSelected;
  final T? selected;
  final Widget child;
  final String? tooltip;

  const MoodiaryMenuButton({
    super.key,
    required this.entries,
    required this.onSelected,
    required this.child,
    this.selected,
    this.tooltip,
  });

  Future<void> _open(BuildContext context) async {
    final result = await showMoodiaryMenu<T>(
      anchorContext: context,
      entries: entries,
      selected: selected,
    );
    if (result != null) onSelected(result);
  }

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
      onTap: () => _open(context),
      borderRadius: AppBorderRadius.largeBorderRadius,
      child: child,
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class _MoodiaryMenuRoute<T> extends PopupRoute<T> {
  final Rect anchor;
  final List<MoodiaryMenuEntry<T>> entries;
  final T? selected;
  final bool preferAbove;
  final CapturedThemes capturedThemes;
  final String barrierLabelText;

  _MoodiaryMenuRoute({
    required this.anchor,
    required this.entries,
    required this.selected,
    required this.preferAbove,
    required this.capturedThemes,
    required this.barrierLabelText,
  });

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 130);

  @override
  bool get barrierDismissible => true;

  @override
  Color? get barrierColor => null;

  @override
  String get barrierLabel => barrierLabelText;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    // 从路由（overlay）上下文读安全区 padding：锚点所在的深层上下文可能已被
    // Scaffold/SafeArea 消费掉顶部 padding，会导致上翻时钻到状态栏下面。
    final screenPadding = MediaQuery.viewPaddingOf(context);
    final menu = Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: _MoodiaryMenuBody<T>(route: this, animation: animation),
    );
    return CustomSingleChildLayout(
      delegate: _MoodiaryMenuLayout(
        anchor: anchor,
        preferAbove: preferAbove,
        screenPadding: screenPadding,
        textDirection: Directionality.of(context),
      ),
      child: capturedThemes.wrap(menu),
    );
  }
}

class _MoodiaryMenuBody<T> extends StatefulWidget {
  final _MoodiaryMenuRoute<T> route;
  final Animation<double> animation;

  const _MoodiaryMenuBody({required this.route, required this.animation});

  @override
  State<_MoodiaryMenuBody<T>> createState() => _MoodiaryMenuBodyState<T>();
}

class _MoodiaryMenuBodyState<T> extends State<_MoodiaryMenuBody<T>> {
  late final CurvedAnimation _curved = CurvedAnimation(
    parent: widget.animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void dispose() {
    _curved.dispose();
    super.dispose();
  }

  /// 打开时聚焦的条目：优先选中项，否则首个可用项 —— 让键盘方向键/回车可直接操作。
  int _autofocusIndex(List<MoodiaryMenuEntry<T>> entries) {
    final selectedIndex = entries.indexWhere(
      (e) => e.enabled && e.value == widget.route.selected,
    );
    if (selectedIndex != -1) return selectedIndex;
    return entries.indexWhere((e) => e.enabled);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final entries = widget.route.entries;
    final hasIcon = entries.any((e) => e.icon != null);
    final hasSelected = entries.any((e) => e.value == widget.route.selected);
    final autofocusIndex = _autofocusIndex(entries);
    final alignY = widget.route.preferAbove ? 1.0 : -1.0;

    return AnimatedBuilder(
      animation: _curved,
      builder: (context, child) {
        return Opacity(
          opacity: _curved.value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.9 + 0.1 * _curved.value,
            alignment: Alignment(0, alignY),
            child: child,
          ),
        );
      },
      child: Material(
        type: .card,
        color: scheme.surfaceContainerHigh,
        elevation: 8,
        shadowColor: scheme.shadow.withValues(alpha: 0.24),
        surfaceTintColor: Colors.transparent,
        borderRadius: AppBorderRadius.largeBorderRadius,
        clipBehavior: .antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _kMenuMinWidth,
            maxWidth: _kMenuMaxWidth,
          ),
          child: IntrinsicWidth(
            child: SingleChildScrollView(
              padding: const .all(6),
              child: FocusTraversalGroup(
                child: Column(
                  mainAxisSize: .min,
                  crossAxisAlignment: .stretch,
                  children: [
                    for (final (index, entry) in entries.indexed)
                      _MoodiaryMenuItem<T>(
                        entry: entry,
                        selected: entry.value == widget.route.selected,
                        showLeadingSlot: hasIcon,
                        showTrailingSlot: hasSelected,
                        autofocus: index == autofocusIndex,
                        onTap: () => Navigator.of(context).pop(entry.value),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoodiaryMenuItem<T> extends StatelessWidget {
  final MoodiaryMenuEntry<T> entry;
  final bool selected;
  final bool showLeadingSlot;
  final bool showTrailingSlot;
  final bool autofocus;
  final VoidCallback onTap;

  const _MoodiaryMenuItem({
    required this.entry,
    required this.selected,
    required this.showLeadingSlot,
    required this.showTrailingSlot,
    required this.autofocus,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final Color fg;
    if (!entry.enabled) {
      fg = scheme.onSurface.withValues(
        alpha: context.theme.states.disabledOpacity,
      );
    } else if (entry.isDestructive) {
      fg = scheme.error;
    } else if (selected) {
      fg = scheme.onSecondaryContainer;
    } else {
      fg = scheme.onSurface;
    }

    return Padding(
      padding: const .symmetric(vertical: 2),
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        borderRadius: AppBorderRadius.mediumBorderRadius,
        clipBehavior: .antiAlias,
        child: InkWell(
          onTap: entry.enabled ? onTap : null,
          autofocus: autofocus && entry.enabled,
          focusColor: scheme.onSurface.withValues(alpha: 0.08),
          child: Padding(
            padding: .fromLTRB(showLeadingSlot ? 12 : 14, 10, 12, 10),
            child: Row(
              children: [
                if (showLeadingSlot) ...[
                  SizedBox(
                    width: 20,
                    child: entry.icon != null
                        ? Icon(entry.icon, size: 19, color: fg)
                        : null,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    entry.label,
                    maxLines: 1,
                    overflow: .ellipsis,
                    style:
                        (selected
                                ? context.theme.typography.bodyMedium.emphasized
                                : context
                                      .theme
                                      .typography
                                      .bodyMedium
                                      .emphasized)
                            .onSurface
                            .copyWith(color: fg),
                  ),
                ),
                if (showTrailingSlot) ...[
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 18,
                    child: selected
                        ? Icon(LucideIcons.check, size: 18, color: fg)
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 定位委托：优先在锚点下方左对齐弹出，空间不足则上方，并夹在安全区内。
class _MoodiaryMenuLayout extends SingleChildLayoutDelegate {
  final Rect anchor;
  final bool preferAbove;
  final EdgeInsets screenPadding;
  final TextDirection textDirection;

  _MoodiaryMenuLayout({
    required this.anchor,
    required this.preferAbove,
    required this.screenPadding,
    required this.textDirection,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(
      constraints.biggest,
    ).deflate(const EdgeInsets.all(_kMenuScreenPadding) + screenPadding);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final topLimit = _kMenuScreenPadding + screenPadding.top;
    final bottomLimit =
        size.height - _kMenuScreenPadding - screenPadding.bottom;
    final belowSpace = bottomLimit - anchor.bottom;
    final aboveSpace = anchor.top - topLimit;

    double y;
    if (!preferAbove && childSize.height <= belowSpace) {
      y = anchor.bottom + _kMenuAnchorGap;
    } else if (preferAbove && childSize.height <= aboveSpace) {
      y = anchor.top - _kMenuAnchorGap - childSize.height;
    } else if (belowSpace >= aboveSpace) {
      y = anchor.bottom + _kMenuAnchorGap;
    } else {
      y = anchor.top - _kMenuAnchorGap - childSize.height;
    }
    y = y.clamp(
      topLimit,
      (bottomLimit - childSize.height).clamp(topLimit, bottomLimit),
    );

    final leftLimit = _kMenuScreenPadding + screenPadding.left;
    final rightLimit = size.width - _kMenuScreenPadding - screenPadding.right;
    double x = textDirection == .rtl
        ? anchor.right - childSize.width
        : anchor.left;
    x = x.clamp(
      leftLimit,
      (rightLimit - childSize.width).clamp(leftLimit, rightLimit),
    );

    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_MoodiaryMenuLayout oldDelegate) {
    return anchor != oldDelegate.anchor ||
        preferAbove != oldDelegate.preferAbove ||
        screenPadding != oldDelegate.screenPadding ||
        textDirection != oldDelegate.textDirection;
  }
}
