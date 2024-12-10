import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/values/view_mode.dart';
import 'package:mood_diary/components/diary_tab_view/diary_tab_view_view.dart';
import 'package:mood_diary/components/keepalive/keepalive.dart';
import 'package:mood_diary/components/scroll/fix_scroll.dart';
import 'package:mood_diary/components/search_sheet/search_sheet_view.dart';
import 'package:mood_diary/components/web_dav_dashboard/web_dav_dashboard_view.dart';

import 'diary_logic.dart';

class DiaryPage extends StatelessWidget {
  const DiaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(DiaryLogic());
    final state = Bind.find<DiaryLogic>().state;
    final colorScheme = Theme.of(context).colorScheme;
    final i18n = AppLocalizations.of(context)!;

    //生成TabBar
    Widget buildTabBar() {
      List<Widget> allTabs = [];
      //默认的全部tab
      allTabs.add(const Tab(text: '全部'));
      //根据分类生成分类Tab
      allTabs.addAll(List.generate(state.categoryList.length, (index) {
        return Tab(text: state.categoryList[index].categoryName);
      }));
      return Align(
        alignment: Alignment.centerLeft,
        child: TabBar(
          controller: logic.tabController,
          isScrollable: true,
          dividerHeight: .0,
          tabAlignment: TabAlignment.start,
          indicatorSize: TabBarIndicatorSize.label,
          splashFactory: NoSplash.splashFactory,
          dragStartBehavior: DragStartBehavior.start,
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(
              color: colorScheme.primary,
              width: 4.0,
            ),
            borderRadius: const BorderRadius.all(Radius.circular(2.0)),
          ),
          indicatorWeight: .0,
          indicatorPadding: const EdgeInsets.symmetric(vertical: 4.0),
          tabs: allTabs,
        ),
      );
    }

    // 单个页面
    Widget buildDiaryView(int index, key, String? categoryId) {
      return KeepAliveWrapper(
        child: PrimaryScrollWrapper(
          key: key,
          child: DiaryTabViewComponent(categoryId: categoryId),
        ),
      );
    }

    Widget buildTabBarView() {
      List<Widget> allViews = [];
      // 添加全部日记页面
      allViews.add(buildDiaryView(0, state.keyMap['default'], null));
      // 添加分类日记页面
      allViews.addAll(List.generate(state.categoryList.length, (index) {
        return buildDiaryView(index + 1, state.keyMap[state.categoryList[index].id], state.categoryList[index].id);
      }));

      return NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          if (notification.metrics.axis == Axis.horizontal) {
            logic.checkPageChange();
          }
          return true;
        },
        child: TabBarView(
          controller: logic.tabController,
          dragStartBehavior: DragStartBehavior.start,
          children: allViews,
        ),
      );
    }

    return GetBuilder<DiaryLogic>(
        id: 'All',
        assignId: true,
        builder: (_) {
          return NestedScrollView(
            key: state.nestedScrollKey,
            headerSliverBuilder: (context, _) {
              return [
                SliverOverlapAbsorber(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                  sliver: SliverAppBar(
                    title: GetBuilder<DiaryLogic>(
                        id: 'Title',
                        builder: (_) {
                          return Text(
                            state.customTitleName.isNotEmpty ? state.customTitleName : i18n.appName,
                            overflow: TextOverflow.ellipsis,
                          );
                        }),
                    pinned: true,
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
                      IconButton(
                        onPressed: () {
                          showModalBottomSheet(
                              context: context,
                              builder: (context) {
                                return const WebDavDashboardComponent();
                              },
                              showDragHandle: true,
                              useSafeArea: true);
                        },
                        icon: const Icon(Icons.cloud_sync_outlined),
                      ),
                      PopupMenuButton(
                        offset: const Offset(0, 46),
                        tooltip: i18n.diaryPageViewModeButton,
                        itemBuilder: (context) {
                          return <PopupMenuEntry<String>>[
                            CheckedPopupMenuItem(
                              checked: state.viewModeType == ViewModeType.list,
                              onTap: () async {
                                await logic.changeViewMode(ViewModeType.list);
                              },
                              child: Text(i18n.diaryViewModeList),
                            ),
                            const PopupMenuDivider(),
                            CheckedPopupMenuItem(
                              checked: state.viewModeType == ViewModeType.grid,
                              onTap: () async {
                                await logic.changeViewMode(ViewModeType.grid);
                              },
                              child: Text(i18n.diaryViewModeGrid),
                            ),
                          ];
                        },
                      ),
                    ],
                    bottom: PreferredSize(preferredSize: const Size.fromHeight(46.0), child: buildTabBar()),
                  ),
                ),
              ];
            },
            body: GetBuilder<DiaryLogic>(
                id: 'TabBarView',
                builder: (_) {
                  return buildTabBarView();
                }),
          );
        });
  }
}
