import 'package:mui/mui.dart';

class MSliverSettingGroup extends StatelessWidget {
  final String? title;

  final List<Widget> children;

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
    final radius = Radius.circular(theme.radii.lg);
    return SliverMainAxisGroup(
      slivers: [
        if (title != null)
          SliverToBoxAdapter(child: SettingTitleTile(title: title)),
        DecoratedSliver(
          decoration: ShapeDecoration(
            color: color ?? theme.colors.surfaceContainerLow,
            shape: RoundedRectangleBorder(borderRadius: .all(radius)),
          ),
          sliver: SliverClipRRect(
            borderRadius: .all(radius),
            clipOverlap: .none,
            sliver: SliverList.separated(
              itemCount: children.length,
              itemBuilder: (_, i) => children[i],
              separatorBuilder: (_, _) => const MSettingDivider(),
            ),
          ),
        ),
      ],
    );
  }
}
