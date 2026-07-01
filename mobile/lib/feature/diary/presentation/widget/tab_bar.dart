import 'package:flutter/material.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';

class DiaryCategoryTabBar extends StatelessWidget {
  final List<Category> categories;
  final TabController? tabController;

  const DiaryCategoryTabBar({
    super.key,
    required this.categories,
    required this.tabController,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> allTabs = [];
    allTabs.add(
      Padding(
        padding: const .symmetric(horizontal: 8.0),
        child: Tab(text: context.l10n.categoryAll),
      ),
    );
    allTabs.addAll(
      List.generate(categories.length, (index) {
        return Padding(
          padding: const .symmetric(horizontal: 8.0),
          child: Tab(text: categories[index].categoryName),
        );
      }),
    );
    return SizedBox(
      height: 24.0,
      child: TabBar(
        controller: tabController,
        isScrollable: true,
        indicatorSize: .label,
        splashFactory: NoSplash.splashFactory,
        dragStartBehavior: .start,
        unselectedLabelStyle: context.textTheme.labelSmall,
        labelStyle: context.textTheme.labelMedium,
        overlayColor: .all(Colors.transparent),
        dividerHeight: .0,
        indicator: ShapeDecoration(
          shape: const StadiumBorder(),
          color: context.theme.colorScheme.primaryContainer,
        ),
        indicatorWeight: .0,
        unselectedLabelColor: context.theme.colorScheme.onSurface.withValues(
          alpha: 0.8,
        ),
        labelColor: context.theme.colorScheme.onPrimaryContainer,
        labelPadding: const .symmetric(horizontal: 12.0),
        tabs: allTabs,
        tabAlignment: .start,
      ),
    );
  }
}
