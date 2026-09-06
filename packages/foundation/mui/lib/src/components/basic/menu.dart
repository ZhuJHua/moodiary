import 'package:mui/mui.dart';

class MMenuEntry<T> {
  final T value;
  final String label;
  final IconData? icon;

  final bool isDestructive;
  final bool enabled;

  const MMenuEntry({
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

abstract final class MMenu {
  static Future<T?> show<T>({
    required BuildContext anchorContext,
    required List<MMenuEntry<T>> entries,
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
      _MMenuRoute<T>(
        anchor: anchor,
        entries: entries,
        selected: selected,
        preferAbove: preferAbove,
        capturedThemes: InheritedTheme.capture(
          from: anchorContext,
          to: navigator.context,
        ),
        barrierLabelText: MaterialLocalizations.of(anchorContext)
            .modalBarrierDismissLabel,
      ),
    );
  }
}

class MMenuButton<T> extends StatelessWidget {
  final List<MMenuEntry<T>> entries;
  final ValueChanged<T> onSelected;
  final T? selected;
  final Widget child;
  final String? tooltip;

  const MMenuButton({
    super.key,
    required this.entries,
    required this.onSelected,
    required this.child,
    this.selected,
    this.tooltip,
  });

  Future<void> _open(BuildContext context) async {
    final result = await MMenu.show<T>(
      anchorContext: context,
      entries: entries,
      selected: selected,
    );
    if (result != null) onSelected(result);
  }

  @override
  Widget build(BuildContext context) {
    final button = MInkWell(
      onTap: () => _open(context),
      borderRadius: MuiRadius.lg,
      child: child,
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class _MMenuRoute<T> extends PopupRoute<T> {
  final Rect anchor;
  final List<MMenuEntry<T>> entries;
  final T? selected;
  final bool preferAbove;
  final CapturedThemes capturedThemes;
  final String barrierLabelText;

  _MMenuRoute({
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
    final screenPadding = MediaQuery.viewPaddingOf(context);
    final menu = Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: _MMenuBody<T>(route: this, animation: animation),
    );
    return CustomSingleChildLayout(
      delegate: _MMenuLayout(
        anchor: anchor,
        preferAbove: preferAbove,
        screenPadding: screenPadding,
        textDirection: Directionality.of(context),
      ),
      child: capturedThemes.wrap(menu),
    );
  }
}

class _MMenuBody<T> extends StatefulWidget {
  final _MMenuRoute<T> route;
  final Animation<double> animation;

  const _MMenuBody({required this.route, required this.animation});

  @override
  State<_MMenuBody<T>> createState() => _MMenuBodyState<T>();
}

class _MMenuBodyState<T> extends State<_MMenuBody<T>> {
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

  int _autofocusIndex(List<MMenuEntry<T>> entries) {
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
        borderRadius: MuiRadius.lg,
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
                      _MMenuItem<T>(
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

class _MMenuItem<T> extends StatelessWidget {
  final MMenuEntry<T> entry;
  final bool selected;
  final bool showLeadingSlot;
  final bool showTrailingSlot;
  final bool autofocus;
  final VoidCallback onTap;

  const _MMenuItem({
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
        borderRadius: MuiRadius.md,
        clipBehavior: .antiAlias,
        child: MInkWell(
          onTap: entry.enabled ? onTap : null,
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

class _MMenuLayout extends SingleChildLayoutDelegate {
  final Rect anchor;
  final bool preferAbove;
  final EdgeInsets screenPadding;
  final TextDirection textDirection;

  _MMenuLayout({
    required this.anchor,
    required this.preferAbove,
    required this.screenPadding,
    required this.textDirection,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(constraints.biggest)
        .deflate(const EdgeInsets.all(_kMenuScreenPadding) + screenPadding);
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
  bool shouldRelayout(_MMenuLayout oldDelegate) {
    return anchor != oldDelegate.anchor ||
        preferAbove != oldDelegate.preferAbove ||
        screenPadding != oldDelegate.screenPadding ||
        textDirection != oldDelegate.textDirection;
  }
}
