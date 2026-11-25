import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as liquid;
import 'package:mui/mui.dart';

import 'glass_platform.dart';

class MGlassNavDestination {
  final Widget icon;
  final String label;

  const MGlassNavDestination({required this.icon, required this.label});
}

class MGlassNavAction {
  final Widget icon;
  final String? tooltip;
  final VoidCallback? onPressed;

  const MGlassNavAction({required this.icon, this.tooltip, this.onPressed});
}

class MGlassNavBar extends StatelessWidget {
  final List<MGlassNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final MGlassNavAction? action;

  const MGlassNavBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    if (usesLiquidGlass) {
      final tooltip = action?.tooltip;
      final colors = context.theme.colors;
      return MediaQuery.withNoTextScaling(
        child: liquid.GlassTabBar.bottom(
          quality: liquid.GlassQuality.premium,
          iconSize: 25,
          iconLabelSpacing: 2,
          selectedIconColor: colors.primary,
          selectedLabelColor: colors.primary,
          tabs: [
            for (final destination in destinations)
              liquid.GlassTab(icon: destination.icon, label: destination.label),
          ],
          selectedIndex: selectedIndex,
          onTabSelected: onDestinationSelected,
          extraButton: action == null
              ? null
              : liquid.GlassTabBarExtraButton(
                  icon: tooltip == null
                      ? action.icon
                      : Tooltip(message: tooltip, child: action.icon),
                  label: tooltip ?? '',
                  onTap: action.onPressed ?? () {},
                  enabled: action.onPressed != null,
                ),
        ),
      );
    }

    return _MGlassNavBarCommon(
      destinations: destinations,
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      action: action,
    );
  }
}

class _MGlassNavBarCommon extends StatefulWidget {
  final List<MGlassNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final MGlassNavAction? action;

  const _MGlassNavBarCommon({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.action,
  });

  @override
  State<_MGlassNavBarCommon> createState() => _MGlassNavBarCommonState();
}

class _MGlassNavBarCommonState extends State<_MGlassNavBarCommon>
    with SingleTickerProviderStateMixin {
  static final _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 560,
    ratio: 0.8,
  );

  late final _position = AnimationController.unbounded(
    vsync: this,
    value: widget.selectedIndex.toDouble(),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.reduceMotionOf(context)) {
      _position.value = widget.selectedIndex.toDouble();
    }
  }

  @override
  void didUpdateWidget(covariant _MGlassNavBarCommon oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = widget.selectedIndex.toDouble();
    if (oldWidget.destinations.length != widget.destinations.length ||
        (MediaQuery.disableAnimationsOf(context) ||
            MediaQuery.reduceMotionOf(context))) {
      _position.value = target;
    } else if (oldWidget.selectedIndex != widget.selectedIndex) {
      _position.animateWith(
        SpringSimulation(
          _spring,
          _position.value,
          target,
          _position.velocity,
          snapToEnd: true,
          tolerance: const Tolerance(distance: 0.001, velocity: 0.02),
        ),
      );
    }
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    final bottom = math.max(20.0, MediaQuery.viewPaddingOf(context).bottom);
    final tabCount = widget.destinations.length;
    final scheme = context.theme.colors;
    return MediaQuery.withNoTextScaling(
      child: Padding(
        padding: .fromLTRB(20, 20, 20, bottom),
        child: SizedBox(
          height: 64,
          child: CustomMultiChildLayout(
            delegate: _NavBarLayout(
              position: _position,
              tabCount: tabCount,
              textDirection: Directionality.of(context),
            ),
            children: [
              LayoutId(
                id: _NavBarSlot.track,
                child: const MGlassContainer(
                  borderRadius: 32,
                  child: SizedBox.expand(),
                ),
              ),
              if (tabCount > 0)
                LayoutId(
                  id: _NavBarSlot.indicator,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: scheme.primary.withValues(alpha: 0.16),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              for (var index = 0; index < tabCount; index++)
                LayoutId(
                  id: index,
                  child: _Tab(
                    destination: widget.destinations[index],
                    selected: index == widget.selectedIndex,
                    onTap: () => widget.onDestinationSelected(index),
                  ),
                ),
              if (action != null)
                LayoutId(
                  id: _NavBarSlot.action,
                  child: _ActionButton(action: action),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _NavBarSlot { track, indicator, action }

class _NavBarLayout extends MultiChildLayoutDelegate {
  _NavBarLayout({
    required this.position,
    required this.tabCount,
    required this.textDirection,
  }) : super(relayout: position);

  static const _trackInset = 4.0;
  static const _actionGap = 8.0;

  final AnimationController position;
  final int tabCount;
  final TextDirection textDirection;

  @override
  void performLayout(Size size) {
    final hasAction = hasChild(_NavBarSlot.action);
    final actionSize = hasAction ? size.shortestSide : 0.0;
    final gap = hasAction ? math.min(_actionGap, size.width - actionSize) : 0.0;
    final trackWidth = size.width - actionSize - gap;
    final rtl = textDirection == .rtl;
    final trackLeft = rtl ? actionSize + gap : 0.0;
    layoutChild(
      _NavBarSlot.track,
      BoxConstraints.tightFor(width: trackWidth, height: size.height),
    );
    positionChild(_NavBarSlot.track, Offset(trackLeft, 0));

    if (hasAction) {
      layoutChild(
        _NavBarSlot.action,
        BoxConstraints.tight(Size.square(actionSize)),
      );
      positionChild(
        _NavBarSlot.action,
        Offset(
          rtl ? 0 : size.width - actionSize,
          (size.height - actionSize) / 2,
        ),
      );
    }

    if (tabCount == 0) return;
    final inset = math.min(_trackInset, math.min(trackWidth, size.height) / 2);
    final contentWidth = trackWidth - inset * 2;
    final tabWidth = contentWidth / tabCount;
    final tabHeight = size.height - inset * 2;
    final tabsLeft = trackLeft + inset;
    final tabConstraints = BoxConstraints.tightFor(
      width: tabWidth,
      height: tabHeight,
    );
    for (var index = 0; index < tabCount; index++) {
      final column = rtl ? tabCount - 1 - index : index;
      layoutChild(index, tabConstraints);
      positionChild(index, Offset(tabsLeft + column * tabWidth, inset));
    }

    final stretch = math.min(position.velocity.abs() * 0.02, 0.2);
    final width = math.min(tabWidth * (1 + stretch), trackWidth);
    final height = tabHeight / (1 + stretch);
    final column = rtl ? tabCount - 1 - position.value : position.value;
    final overhang = inset / 2;
    final left = (column * tabWidth - (width - tabWidth) / 2).clamp(
      -overhang,
      math.max(-overhang, contentWidth - width + overhang),
    );
    layoutChild(
      _NavBarSlot.indicator,
      BoxConstraints.tightFor(width: width, height: height),
    );
    positionChild(
      _NavBarSlot.indicator,
      Offset(tabsLeft + left, (size.height - height) / 2),
    );
  }

  @override
  bool shouldRelayout(_NavBarLayout oldDelegate) =>
      position != oldDelegate.position ||
      tabCount != oldDelegate.tabCount ||
      textDirection != oldDelegate.textDirection;
}

class _Tab extends StatelessWidget {
  final MGlassNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final label = theme.typography.labelSmall;
    final inheritedStyle = DefaultTextStyle.of(context).style;
    final labelStyle = (selected ? label.emphasized : label).onSurface.copyWith(
      height: inheritedStyle.height,
      letterSpacing: inheritedStyle.letterSpacing,
    );
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: GestureDetector(
        behavior: .opaque,
        onTap: onTap,
        child: ExcludeSemantics(
          child: SizedBox.expand(
            child: FittedBox(
              fit: .scaleDown,
              child: Column(
                mainAxisSize: .min,
                spacing: 2.0,
                children: [
                  IconTheme.merge(
                    data: IconThemeData(
                      size: 25,
                      color: selected
                          ? theme.colors.primary
                          : theme.colors.onSurface,
                    ),
                    child: destination.icon,
                  ),
                  Text(
                    destination.label,
                    maxLines: 1,
                    overflow: .ellipsis,
                    textAlign: .center,
                    style: labelStyle,
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

class _ActionButton extends StatefulWidget {
  final MGlassNavAction action;

  const _ActionButton({required this.action});

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  static const _pressedScale = 0.96;
  static final _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 550,
    ratio: 0.8,
  );

  late final _scale = AnimationController.unbounded(vsync: this, value: 1);

  void _press(TapDownDetails details) {
    _scale.animateTo(
      _pressedScale,
      duration: const Duration(milliseconds: 75),
      curve: Curves.easeOutCubic,
    );
  }

  void _release() {
    _scale.animateWith(
      SpringSimulation(
        _spring,
        _scale.value,
        1,
        0,
        snapToEnd: true,
        tolerance: const Tolerance(distance: 0.0001, velocity: 0.001),
      ),
    );
  }

  void _tap() {
    if (_scale.value >= 1) _scale.value = (1 + _pressedScale) / 2;
    _release();
    widget.action.onPressed?.call();
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final action = widget.action;
    final onPressed = action.onPressed;
    final tooltip = action.tooltip;
    final animate =
        onPressed != null &&
        !(MediaQuery.disableAnimationsOf(context) ||
            MediaQuery.reduceMotionOf(context));
    Widget button = GestureDetector(
      excludeFromSemantics: true,
      behavior: HitTestBehavior.opaque,
      onTapDown: animate ? _press : null,
      onTap: animate ? _tap : onPressed,
      onTapCancel: animate ? _release : null,
      child: ScaleTransition(
        scale: animate ? _scale : const AlwaysStoppedAnimation(1.0),
        child: MGlassContainer.circle(
          child: IconTheme.merge(
            data: IconThemeData(size: 24, color: scheme.onSurface),
            child: Center(child: action.icon),
          ),
        ),
      ),
    );
    if (tooltip != null) {
      button = Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: button,
      );
    }
    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      label: tooltip,
      onTap: onPressed,
      child: button,
    );
  }
}
