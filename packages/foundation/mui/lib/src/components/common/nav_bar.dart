import 'package:mui/mui.dart';

const double kMoodiaryNavBarHeight = 60;
const double kMoodiaryNavBarSideMargin = 16;
const double kMoodiaryNavBarBottomGap = 10;

const double _kActionSize = 60;
const double _kActionSpacing = 10;

const double _kTrackInset = 6;

const double _kMaxTextScale = 1.15;

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

  static double bandHeight(BuildContext context) =>
      kMoodiaryNavBarHeight +
      kMoodiaryNavBarBottomGap +
      MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _kMaxTextScale,
      child: Padding(
        padding: .fromLTRB(
          kMoodiaryNavBarSideMargin,
          0,
          kMoodiaryNavBarSideMargin,
          bottom + kMoodiaryNavBarBottomGap,
        ),
        child: SizedBox(
          height: kMoodiaryNavBarHeight,
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
    );
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
                      color: scheme.secondaryContainer,
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
    final target = selected
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: GestureDetector(
        behavior: .opaque,
        onTap: onTap,
        child: ExcludeSemantics(
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: target),
            duration: Durations.medium2,
            builder: (context, color, _) {
              return Column(
                mainAxisAlignment: .center,
                children: [
                  IconTheme.merge(
                    data: IconThemeData(size: 21, color: color),
                    child: destination.icon,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    destination.label,
                    maxLines: 1,
                    overflow: .ellipsis,
                    style: context.theme.typography.labelSmall.onSurfaceVariant
                        .copyWith(color: color),
                  ),
                ],
              );
            },
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
    Widget button = DecoratedBox(
      decoration: ShapeDecoration(
        shape: const CircleBorder(),
        shadows: MGlassSurface.defaultShadows(scheme),
      ),
      child: Material(
        color: scheme.primary,
        shape: const CircleBorder(),
        clipBehavior: .antiAlias,
        child: MInkWell(
          onTap: action.onPressed,
          child: SizedBox.square(
            dimension: _kActionSize,
            child: IconTheme.merge(
              data: IconThemeData(size: 22, color: scheme.onPrimary),
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
