import 'package:mui/mui.dart';

/// 一组设置项：标题 + 一张圆角卡片，卡片内每两项之间一条分隔线。
///
/// **分隔线与圆角都不再由每一项自己反推**，三样东西各司其职：
///
///   * [SliverMainAxisGroup] 把标题和列表并成一个 sliver，调用方按组摆即可；
///   * [SliverList.separated] 天然在项与项之间插分隔线 —— 以前是每个 tile 看
///     `isFirst` 决定要不要在自己头上画一条，等于让每一项去猜自己在列表里的位置；
///   * [DecoratedSliver] 画圆角填充底，首/末项各自套一层 [ClipRRect] 修边。
///
/// 圆角落在**每一项**上而不是整组外面套一层：sliver 没法直接 `ClipRRect`（SDK 至今没有
/// sliver 裁剪组件）。而包在项上就够了，因为按压反馈走的是 [MInkWell] 的自绘遮罩 ——
/// 遮罩画在自己子树里，外面一层普通裁剪就收得住。（换成 [ListTile] 那套就不行：ink
/// feature 是祖先 [Material] 的 render object 画的，后代的裁剪盖不住它。）
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
      return ClipRRect(
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
