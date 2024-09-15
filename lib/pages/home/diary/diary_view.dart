import 'package:extended_nested_scroll_view/extended_nested_scroll_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/values/view_mode.dart';
import 'package:mood_diary/components/diary_tab_view/diary_tab_view_view.dart';
import 'package:mood_diary/components/search_sheet/search_sheet_view.dart';

import 'diary_logic.dart';

class DiaryPage extends StatelessWidget {
  const DiaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<DiaryLogic>();
    final state = Bind.find<DiaryLogic>().state;
    final colorScheme = Theme.of(context).colorScheme;
    final statusBarHeight = MediaQuery.paddingOf(context).top;
    final i18n = AppLocalizations.of(context)!;

    final SliverOverlapAbsorberHandle appBar = SliverOverlapAbsorberHandle();
    final SliverOverlapAbsorberHandle tabBar = SliverOverlapAbsorberHandle();

    //生成TabBar
    Widget buildTabBar() {
      //默认的全部tab
      var allTab = [const Tab(text: '全部')];
      //根据分类生成分类Tab
      allTab += List.generate(state.categoryList.length, (index) {
        return Tab(text: state.categoryList[index].categoryName);
      });
      return !state.isFetching.value
          ? Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                controller: logic.tabController,
                isScrollable: true,
                dividerHeight: .0,
                tabAlignment: TabAlignment.start,
                indicatorSize: TabBarIndicatorSize.label,
                splashFactory: NoSplash.splashFactory,
                indicator: UnderlineTabIndicator(
                  borderSide: BorderSide(
                    color: colorScheme.primary,
                    width: 4.0,
                  ),
                  borderRadius: const BorderRadius.all(Radius.circular(2.0)),
                ),
                indicatorWeight: .0,
                indicatorPadding: const EdgeInsets.all(4.0),
                tabs: allTab,
                onTap: (value) {
                  logic.updateTabViewIndex(value);
                },
              ),
            )
          : const SizedBox.shrink();
    }

    //生成TabBarView
    Widget buildTabBarView() {
      //全部日记页面
      var allView = [const DiaryTabViewComponent(tag: '0')];
      //分类日记页面
      allView += List.generate(state.categoryList.length, (index) {
        return DiaryTabViewComponent(
          categoryId: state.categoryList[index].id,
          tag: (index + 1).toString(),
        );
      });
      return !state.isFetching.value
          ? TabBarView(
              controller: logic.tabController,
              children: allView,
            )
          : const SizedBox.shrink();
    }

    return GetBuilder<DiaryLogic>(
      init: logic,
      assignId: true,
      builder: (logic) {
        return NestedScrollView(
          key: state.nestedScrollKey,
          headerSliverBuilder: (context, _) {
            return [
              SliverAppBar(
                title: Text(
                  state.customTitleName.isNotEmpty ? state.customTitleName : i18n.appName,
                  overflow: TextOverflow.ellipsis,
                ),
                pinned: true,
                floating: true,
                actions: [
                  IconButton(
                    onPressed: () {
                      showModalBottomSheet(
                          context: context,
                          showDragHandle: true,
                          useSafeArea: true,
                          builder: (context) {
                            return const SearchSheetComponent();
                          });
                    },
                    icon: const Icon(Icons.search),
                    tooltip: i18n.diaryPageSearchButton,
                  ),
                  PopupMenuButton(
                    offset: const Offset(0, 46),
                    tooltip: i18n.diaryPageViewModeButton,
                    itemBuilder: (context) {
                      return <PopupMenuEntry<String>>[
                        CheckedPopupMenuItem(
                          checked: state.viewModeType.value == ViewModeType.list,
                          onTap: () async {
                            await logic.changeViewMode(ViewModeType.list);
                          },
                          child: Text(i18n.diaryViewModeList),
                        ),
                        const PopupMenuDivider(),
                        CheckedPopupMenuItem(
                          checked: state.viewModeType.value == ViewModeType.grid,
                          onTap: () async {
                            await logic.changeViewMode(ViewModeType.grid);
                          },
                          child: Text(i18n.diaryViewModeGrid),
                        ),
                      ];
                    },
                  ),
                ],
                bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(46.0),
                    child: Obx(() {
                      return buildTabBar();
                    })),
              )
            ];
          },
          body: Obx(() {
            return buildTabBarView();
          }),
        );
      },
    );
  }
}
