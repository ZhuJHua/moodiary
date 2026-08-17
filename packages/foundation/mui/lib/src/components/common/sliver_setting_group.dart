import 'package:mui/mui.dart';

/// 一组设置项：标题 + 一张圆角卡片，卡片内每两项之间一条分隔线。
///
/// **分隔线与圆角都不再由每一项自己反推**，三样东西各司其职：
///
///   * [SliverMainAxisGroup] 把标题和列表并成一个 sliver，调用方按组摆即可；
///   * [SliverList.separated] 天然在项与项之间插分隔线 —— 以前是每个 tile 看
///     `isFirst` 决定要不要在自己头上画一条，等于让每一项去猜自己在列表里的位置；
///   * [DecoratedSliver] 画圆角填充底，首/末项各自套一层圆角 [Material] 收住水波。
///
/// 为什么圆角要落到**每一项**上，而不是在外面套一层裁剪：[ListTile] 的水波是由祖先
/// [Material] 的 render object 画的，一个后代的裁剪图层盖不住它。今天 `ListTile.shape`
/// 能收住水波，靠的是它把 shape 转给了 `InkWell.customBorder`。所以这里给首/末项各包一层
/// 带圆角、`clipBehavior: antiAlias` 的透明 [Material]：水波画在这层上，就被这层裁住了。
/// 包 [Material] 而不是 `ClipRRect`，也让 [AppLockTile] 那种自己是多行的复合项一并成立。
///
/// 分隔线是 [MSettingDivider]（恰好一个设备像素）。外边距由调用方用 [SliverPadding]
/// 给，本组件不管。
class MSliverSettingGroup extends StatelessWidget {
  /// 组标题。给 null 就没有标题行。
  final String? title;

  /// 组内各项。通常是 [SettingListTile] / [SettingSwitchListTile] 之类。
  ///
  /// 卡片圆角与分隔线都归本组件，所以**这些项不必再传 `isFirst` / `isLast`**。
  final List<Widget> children;

  /// 卡片填充色。默认 `surfaceContainerLow`。
  final Color? color;

  const MSliverSettingGroup({
    super.key,
    this.title,
    required this.children,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    // 与 cardTheme 同一档：卡片与菜单用 lg。
    final radius = Radius.circular(theme.radii.lg);
    final last = children.length - 1;

    Widget item(int i) {
      final isFirst = i == 0;
      final isLast = i == last;
      // 中间项不需要圆角，也就不必多包一层。
      if (!isFirst && !isLast) return children[i];
      return Material(
        type: .transparency,
        clipBehavior: .antiAlias,
        borderRadius: .vertical(
          top: isFirst ? radius : Radius.zero,
          bottom: isLast ? radius : Radius.zero,
        ),
        child: children[i],
      );
    }

    return SliverMainAxisGroup(
      slivers: [
        if (title != null)
          SliverToBoxAdapter(child: SettingTitleTile(title: title)),
        DecoratedSliver(
          decoration: ShapeDecoration(
            color: color ?? theme.colors.surfaceContainerLow,
            shape: RoundedRectangleBorder(borderRadius: .all(radius)),
          ),
          sliver: SliverList.separated(
            itemCount: children.length,
            itemBuilder: (_, i) => item(i),
            separatorBuilder: (_, _) => const MSettingDivider(),
          ),
        ),
      ],
    );
  }
}
