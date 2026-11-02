import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as glass;
import 'package:mui/mui.dart';

const double _kBarHeight = 62;
const double _kSideMargin = 20;
const double _kBottomGap = 20;

const double _kActionSize = 62;
const double _kActionSpacing = 8;

const double _kTrackInset = 4;

const double _kIconSize = 24;
const double _kLabelFontSize = 10;

const double _kMaxTextScale = 1.15;

const double _kGlassBorderWidth = 0.5;

List<BoxShadow> _glassShadows(ColorScheme scheme) =>
    scheme.brightness == Brightness.dark
    ? const []
    : glass.LiquidGlassSettings.ios27Light.shadow ?? const [];

Color? _glassBorderColor(ColorScheme scheme) =>
    scheme.brightness == Brightness.dark
    ? null
    : scheme.onSurface.withValues(alpha: 0.3);

class MNavDestination {
  final Widget icon;
  final String label;

  const MNavDestination({required this.icon, required this.label});
}

class MNavAction {
  final Widget icon;
  final String? tooltip;
  final VoidCallback? onPressed;

  const MNavAction({required this.icon, this.tooltip, this.onPressed});
}

class MNavBar extends StatelessWidget {
  final List<MNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final MNavAction? action;

  const MNavBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.action,
  });

  static double _bottomMargin(BuildContext context) =>
      defaultTargetPlatform == TargetPlatform.iOS
      ? _kBottomGap
      : math.max(
          _kBottomGap,
          MediaQuery.viewPaddingOf(context).bottom,
        );

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _kMaxTextScale,
      child: Padding(
        padding: EdgeInsets.only(bottom: _bottomMargin(context)),
        child: ios
            ? glass.GlassTabBar.bottom(
                quality: glass.GlassQuality.premium,
                tabs: [
                  for (final destination in destinations)
                    glass.GlassTab(
                      icon: destination.icon,
                      label: destination.label,
                    ),
                ],
                selectedIndex: selectedIndex,
                onTabSelected: onDestinationSelected,
                extraButton: action == null
                    ? null
                    : glass.GlassTabBarExtraButton(
                        icon: _actionIcon(action!),
                        label: action!.tooltip ?? '',
                        onTap: action!.onPressed ?? () {},
                        enabled: action!.onPressed != null,
                        iconColor: scheme.onSurface,
                        placement: glass.GlassExtraButtonPlacement.right,
                        size: _kActionSize,
                      ),
                spacing: _kActionSpacing,
                barHeight: _kBarHeight,
                horizontalPadding: _kSideMargin,
                verticalPadding: 0,
                iconSize: _kIconSize,
                labelFontSize: _kLabelFontSize,
                selectedIconColor: scheme.onSurface,
                selectedLabelColor: scheme.onSurface,
                unselectedIconColor: scheme.onSurface,
                unselectedLabelColor: scheme.onSurface,
                settings: scheme.brightness == Brightness.dark
                    ? glass.LiquidGlassSettings.ios27Dark
                    : glass.LiquidGlassSettings.ios27Light,
              )
            : Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _kSideMargin,
                ),
                child: SizedBox(
                  height: _kBarHeight,
                  child: Row(
                    children: [
                      Expanded(
                        child: _Capsule(
                          destinations: destinations,
                          selectedIndex: selectedIndex,
                          onDestinationSelected: onDestinationSelected,
                        ),
                      ),
                      if (action != null) ...[
                        const SizedBox(width: _kActionSpacing),
                        _ActionButton(action: action!),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _actionIcon(MNavAction action) {
    final icon = IconTheme.merge(
      data: const IconThemeData(size: _kIconSize),
      child: action.icon,
    );
    return action.tooltip == null
        ? icon
        : Tooltip(message: action.tooltip!, child: icon);
  }
}

class _Capsule extends StatelessWidget {
  final List<MNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const _Capsule({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return MGlassSurface(
      shape: const StadiumBorder(),
      shadows: _glassShadows(scheme),
      borderColor: _glassBorderColor(scheme),
      borderWidth: _kGlassBorderWidth,
      child: Padding(
        padding: const .all(_kTrackInset),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final count = destinations.length;
            final tabWidth = constraints.maxWidth / count;
            return Stack(
              fit: .expand,
              children: [
                AnimatedPositioned(
                  duration: Durations.medium2,
                  curve: Easing.emphasizedDecelerate,
                  left: tabWidth * selectedIndex,
                  top: 0,
                  width: tabWidth,
                  height: constraints.maxHeight,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: scheme.onSurface.withValues(alpha: 0.1),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < count; i++)
                      Expanded(
                        child: _Tab(
                          destination: destinations[i],
                          selected: i == selectedIndex,
                          onTap: () => onDestinationSelected(i),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final MNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: GestureDetector(
        behavior: .opaque,
        onTap: onTap,
        child: ExcludeSemantics(
          child: Column(
            mainAxisAlignment: .center,
            children: [
              IconTheme.merge(
                data: IconThemeData(size: _kIconSize, color: scheme.onSurface),
                child: destination.icon,
              ),
              const SizedBox(height: 2),
              Text(
                destination.label,
                maxLines: 1,
                overflow: .ellipsis,
                style: context.theme.typography.labelSmall.onSurfaceVariant
                    .copyWith(
                      color: scheme.onSurface,
                      fontSize: _kLabelFontSize,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final MNavAction action;

  const _ActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    Widget button = MGlassSurface(
      shape: const CircleBorder(),
      shadows: _glassShadows(scheme),
      borderColor: _glassBorderColor(scheme),
      borderWidth: _kGlassBorderWidth,
      child: Semantics(
        button: true,
        enabled: action.onPressed != null,
        child: MInkWell(
          onTap: action.onPressed,
          child: SizedBox.square(
            dimension: _kActionSize,
            child: IconTheme.merge(
              data: IconThemeData(size: _kIconSize, color: scheme.onSurface),
              child: Center(child: action.icon),
            ),
          ),
        ),
      ),
    );
    final tooltip = action.tooltip;
    if (tooltip != null) button = Tooltip(message: tooltip, child: button);
    return button;
  }
}
