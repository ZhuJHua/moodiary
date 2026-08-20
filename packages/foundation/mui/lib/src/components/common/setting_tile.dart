import 'package:mui/mui.dart';

/// 行的最小高度。与 M3 的 [ListTile] 对齐：单行 56、带副标题 72。
const double _kOneLineHeight = 56;
const double _kTwoLineHeight = 72;

/// 横向留白。与 [MSettingDivider] 的缩进是同一个数 —— 分隔线两端正好停在文字的左右
/// 边界上。
const double _kHorizontalPadding = 16;

/// 主图标 / 尾部控件与文字之间的距离。
const double _kSlotGap = 16;

/// 组标题行。
class SettingTitleTile extends StatelessWidget {
  const SettingTitleTile({super.key, required this.title, this.subtitle});

  final dynamic title;

  final dynamic subtitle;

  @override
  Widget build(BuildContext context) {
    assert(
      title is String || title is Widget,
      'title must be a String or a Widget',
    );
    assert(
      subtitle == null || subtitle is String || subtitle is Widget,
      'subtitle must be a String or a Widget',
    );
    final theme = context.theme;
    return Padding(
      padding: const .fromLTRB(_kHorizontalPadding, 16, _kHorizontalPadding, 8),
      child: Column(
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        children: [
          _asText(title, theme.typography.titleLarge.primary)!,
          if (subtitle != null)
            _asText(subtitle, theme.typography.bodyMedium.onSurfaceVariant)!,
        ],
      ),
    );
  }
}

/// String / Widget 两收。传 [Text] 时：**带了样式就原样放行**，不带才按给定样式渲染 ——
/// 否则「重置数据」那种 error 色标题会被悄悄套回 onSurface，红色没了也不报错。
Widget? _asText(dynamic value, TextStyle style) => switch (value) {
  null => null,
  String() => Text(value, style: style),
  Text(style: null, data: final data?) => Text(data, style: style),
  Widget() => value,
  _ => throw ArgumentError('必须是 String 或 Widget，收到 ${value.runtimeType}'),
};

/// 设置组内两项之间的分隔线。
///
/// `thickness: 0` 在 Skia 里就是 hairline —— **恰好一个设备像素**，见 divider.dart 对
/// thickness 的注释。别改成 `1 / devicePixelRatio`：那条线按逻辑像素排版，落点多半不在
/// 设备像素边界上，会跨两行各画一半，反而显出一条更宽更灰的边。
///
/// 正常情况下不用手写它 —— [MSliverSettingGroup] 会在项与项之间自动插。只有**自己就是
/// 一组多行的复合项**（比如应用锁那一块）才需要用它隔开自己内部的行。
class MSettingDivider extends StatelessWidget {
  const MSettingDivider({super.key});

  @override
  Widget build(BuildContext context) => const Divider(
    height: 0,
    thickness: 0,
    indent: _kHorizontalPadding,
    endIndent: _kHorizontalPadding,
  );
}

/// 设置项的一行。
///
/// **不用 [ListTile]**：那一套的按压高亮是祖先 [Material] 上的 ink feature，被任何不透明
/// 底色盖住不说，还得靠 `shape → InkWell.customBorder` 才收得住形状。全仓的按压反馈统一
/// 走 [MInkWell] 的自绘遮罩 —— 与背景解耦、嵌套时内层赢、没有回调时整行退化成不可点。
class SettingListTile extends StatelessWidget {
  const SettingListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.leading,
    this.isFirst,
    this.isLast,
    this.contentPadding,
    this.tileColor,
    this.shape,
    this.selected = false,
  });

  final dynamic title;

  final dynamic subtitle;

  final Widget? trailing;

  final Widget? leading;

  final VoidCallback? onTap;

  /// 组内首/末项的圆角。**[MSliverSettingGroup] 里不必再传** —— 那边由组统一包一层
  /// [ClipRRect]。这两个参数留给还没迁到 sliver 组的页面。
  final bool? isFirst;

  final bool? isLast;

  final EdgeInsets? contentPadding;

  final Color? tileColor;

  final ShapeBorder? shape;

  /// 桌面 master-detail 左栏选中态高亮（对应右栏当前打开的项）。
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final fg = selected ? theme.colors.onSecondaryContainer : null;
    final titleStyle = selected
        ? theme.typography.bodyLarge.emphasized.onSecondaryContainer
        : theme.typography.bodyLarge.onSurface;
    final subtitleStyle = selected
        ? theme.typography.bodyMedium.onSecondaryContainer
        : theme.typography.bodyMedium.onSurfaceVariant;

    final titleWidget = _asText(title, titleStyle)!;
    final subtitleWidget = _asText(subtitle, subtitleStyle);

    Widget row = Padding(
      padding:
          contentPadding ??
          const .symmetric(horizontal: _kHorizontalPadding, vertical: 8),
      child: Row(
        children: [
          if (leading != null) ...[
            IconTheme.merge(
              data: IconThemeData(color: fg ?? theme.colors.onSurfaceVariant),
              child: leading!,
            ),
            const SizedBox(width: _kSlotGap),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              mainAxisSize: .min,
              children: [titleWidget, ?subtitleWidget],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: _kSlotGap),
            IconTheme.merge(
              data: IconThemeData(color: fg ?? theme.colors.onSurfaceVariant),
              child: trailing!,
            ),
          ],
        ],
      ),
    );

    row = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: subtitleWidget == null ? _kOneLineHeight : _kTwoLineHeight,
      ),
      child: Align(alignment: .centerLeft, child: row),
    );

    final background = selected ? theme.colors.secondaryContainer : tileColor;
    if (background != null) row = ColoredBox(color: background, child: row);

    return MInkWell(
      onTap: onTap,
      borderRadius: shape == null ? _groupRadius(context) : null,
      shape: shape,
      child: row,
    );
  }

  /// 还没迁到 [MSliverSettingGroup] 的页面仍按 `isFirst` / `isLast` 自己圆角。
  BorderRadius? _groupRadius(BuildContext context) {
    if (isFirst != true && isLast != true) return null;
    final r = Radius.circular(context.theme.radii.lg);
    return .vertical(
      top: isFirst == true ? r : Radius.zero,
      bottom: isLast == true ? r : Radius.zero,
    );
  }
}

/// 带开关的一行。整行可点即切换 —— 只戳那颗 [Switch] 太小。
class SettingSwitchListTile extends StatelessWidget {
  const SettingSwitchListTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.isFirst,
    this.isLast,
    this.secondary,
    this.isSingle,
  });

  final dynamic title;

  final dynamic subtitle;

  final bool value;

  final ValueChanged<bool>? onChanged;

  final Widget? secondary;

  final bool? isFirst;

  final bool? isLast;

  final bool? isSingle;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return SettingListTile(
      title: title,
      subtitle: subtitle,
      leading: secondary,
      isFirst: isSingle == true ? true : isFirst,
      isLast: isSingle == true ? true : isLast,
      // 开关自己也收指针，但 MInkWell 嵌套时内层赢，所以整行的高亮不会跟着亮。
      trailing: Switch(value: value, onChanged: onChanged),
      onTap: onChanged == null ? null : () => onChanged(!value),
    );
  }
}

/// 弹输入框录入单个字符串值的一行（API Key 等）。
class SettingInputTile extends StatelessWidget {
  const SettingInputTile({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.leading,
    this.onValue,
    this.isFirst = false,
    this.isLast = false,
    this.hintText,
    this.obscureText = false,
  });

  final String title;

  final String? subtitle;

  final String value;

  final Widget? leading;

  final bool isFirst;

  final bool isLast;

  final void Function(String value)? onValue;

  final String? hintText;

  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final hasValue = value.trim().isNotEmpty;
    return SettingListTile(
      isFirst: isFirst,
      isLast: isLast,
      title: title,
      leading: leading,
      subtitle:
          subtitle ??
          (hasValue
              ? context.muiL10n.configured
              : context.muiL10n.notConfigured),
      trailing: IconButton.filled(
        tooltip: context.muiL10n.input,
        icon: Icon(LucideIcons.squarePen, color: scheme.onPrimary),
        onPressed: () => _showInputDialog(context),
      ),
    );
  }

  Future<void> _showInputDialog(BuildContext context) async {
    final result = await MAlert.prompt(
      context,
      title: title,
      initialValue: value,
      hintText: hintText,
      obscureText: obscureText,
      confirmLabel: MaterialLocalizations.of(context).saveButtonLabel,
    );
    if (result != null && result.isNotEmpty) onValue?.call(result);
  }
}
