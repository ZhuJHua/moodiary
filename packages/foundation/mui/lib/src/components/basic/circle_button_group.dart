import 'package:mui/mui.dart';

class MCircleButtonItem {
  final Widget icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const MCircleButtonItem({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });
}

class MCircleButtonGroup extends StatelessWidget {
  final List<MCircleButtonItem> items;
  final double size;

  const MCircleButtonGroup({super.key, required this.items, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    const shape = StadiumBorder();
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: context.theme.overlay,
        shape: shape,
        shadows: MGlassSurface.defaultShadows(scheme),
      ),
      child: ClipPath(
        clipper: const ShapeBorderClipper(shape: shape),
        child: Column(
          mainAxisSize: .min,
          children: [
            for (final (i, item) in items.indexed) ...[
              if (i > 0)
                SizedBox(
                  width: size - 20,
                  child: Divider(height: 1, color: scheme.outlineVariant),
                ),
              Tooltip(
                message: item.tooltip,
                child: Semantics(
                  button: true,
                  label: item.tooltip,
                  child: MInkWell(
                    onTap: item.onPressed,
                    child: SizedBox.square(
                      dimension: size,
                      child: IconTheme.merge(
                        data: IconThemeData(
                          size: size * 0.45,
                          color: scheme.onSurface,
                        ),
                        child: Center(child: item.icon),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
