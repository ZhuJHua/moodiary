import 'package:mui/mui.dart';

enum MCircleButtonTone {
  filled,

  tonal,

  plain,
}

class MCircleButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final MCircleButtonTone tone;

  final double size;

  final double? iconSize;

  final bool elevated;

  const MCircleButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.tone = MCircleButtonTone.filled,
    this.size = 40,
    this.iconSize,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final states = context.theme.states;
    final enabled = onPressed != null;

    final (Color background, Color foreground) = switch (tone) {
      MCircleButtonTone.filled => (scheme.primary, scheme.onPrimary),
      MCircleButtonTone.tonal => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      MCircleButtonTone.plain => (
        scheme.surfaceContainerHigh,
        scheme.onSurfaceVariant,
      ),
    };

    final fill = enabled
        ? background
        : scheme.onSurface.withValues(alpha: states.disabledContainerOpacity);
    final ink = enabled
        ? foreground
        : scheme.onSurface.withValues(alpha: states.disabledOpacity);

    Widget button = DecoratedBox(
      decoration: ShapeDecoration(
        color: fill,
        shape: const CircleBorder(),
        shadows: elevated && enabled
            ? MGlassSurface.defaultShadows(scheme)
            : null,
      ),
      child: MInkWell(
        shape: const CircleBorder(),
        onTap: onPressed,
        overlayColor: tone == MCircleButtonTone.filled
            ? foreground.withValues(alpha: states.pressedOpacity)
            : null,
        child: SizedBox.square(
          dimension: size,
          child: IconTheme.merge(
            data: IconThemeData(size: iconSize ?? size * 0.45, color: ink),
            child: Center(child: icon),
          ),
        ),
      ),
    );

    final message = tooltip;
    if (message != null) button = Tooltip(message: message, child: button);
    return Semantics(button: true, label: tooltip, child: button);
  }
}
