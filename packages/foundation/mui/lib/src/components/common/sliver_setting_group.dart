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
    final last = children.length - 1;

    Widget item(int i) {
      final isFirst = i == 0;
      final isLast = i == last;
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
