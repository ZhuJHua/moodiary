import 'package:mui/mui.dart';

/// 圆形图标按钮的着色档。
enum MCircleButtonTone {
  /// 主色实底。页面上唯一的主操作（发送、确认）。
  filled,

  /// 次级容器色。与 filled 同形不同重，用于并列的次要动作。
  tonal,

  /// 无底色，只有图标。浮在内容上、不想抢视线时用。
  plain,
}

/// 圆形图标按钮。
///
/// 单独收一个组件而不是在调用点改 `IconButton` 的 style，是因为
/// `iconButtonTheme` 把全仓 `IconButton` 的形状钉成了圆角矩形（[MuiRadius.md]）——
/// 想要圆形就得在调用点覆盖 `ButtonStyle`，而那正是主题要消灭的那种漂移。
///
/// 不含 `Material`：按压反馈由 [MInkWell] 画在自己子树里。
class MCircleButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final MCircleButtonTone tone;

  /// 直径。默认 40 —— 与 M3 的紧凑图标按钮同高，且达到最小点击目标。
  final double size;

  /// 图标字号。默认按直径的 0.45 取，两者一起改才不会失衡。
  final double? iconSize;

  /// 与底栏胶囊同款的投影。浮在内容上时才开。
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

    // 禁用态按 M3 的两档透明度：容器一档、内容另一档，不是整体调透明 ——
    // 整体调透明会让按钮把背后的东西透出来。
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
        // 深色实底上的默认遮罩（onSurface 系）看不出来，取内容色反着压。
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
