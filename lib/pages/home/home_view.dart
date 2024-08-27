import 'dart:math';

import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/values/view_mode.dart';
import 'package:mood_diary/components/home_tab_view/home_tab_view_view.dart';
import 'package:mood_diary/components/search_sheet/search_sheet_view.dart';
import 'package:mood_diary/components/side_bar/side_bar_view.dart';

import 'home_logic.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<HomeLogic>();
    final state = Bind
        .find<HomeLogic>()
        .state;
    final colorScheme = Theme
        .of(context)
        .colorScheme;
    final i18n = AppLocalizations.of(context)!;
    //生成日历选择器
    Widget buildDatePicker() {
      return CalendarDatePicker2(
        config: CalendarDatePicker2Config(
          calendarViewMode: CalendarDatePicker2Mode.day,
          calendarType: CalendarDatePicker2Type.range,
        ),
        value: state.selectDateTime.value,
      );
    }

    //生成tab
    List<Widget> buildTabBar() {
      //默认的全部tab
      var allTab = [const Tab(text: '全部')];
      //根据分类生成分类Tab
      return allTab +
          List.generate(state.categoryList.length, (index) {
            return Tab(text: state.categoryList[index].categoryName);
          });
    }

    //列表布局
    Widget buildListView() {
      //全部日记页面
      var allView = [const HomeTabViewComponent(tag: '0')];
      //分类日记页面
      allView += List.generate(state.categoryList.length, (index) {
        return HomeTabViewComponent(
          categoryId: state.categoryList[index].id,
          tag: (index + 1).toString(),
        );
      });
      return TabBarView(
          controller: logic.tabController, physics: const NeverScrollableScrollPhysics(), children: allView);
    }

    Widget buildModal() {
      return AnimatedBuilder(
          animation: logic.fabAnimation,
          builder: (context, child) {
            return state.isFabExpanded.value
                ? ModalBarrier(
              color: Color.lerp(Colors.transparent, Colors.black54, logic.fabAnimation.value),
            )
                : const SizedBox.shrink();
          });
    }

    Widget buildToTopButton() {
      return state.isToTopShow.value && state.isFabExpanded.value == false
          ? Transform(
        transform: Matrix4.identity()
          ..translate(.0, -(56.0 + 8.0)),
        alignment: FractionalOffset.center,
        child: InkWell(
          onTap: () async {
            await logic.toTop();
          },
          child: Container(
            decoration: ShapeDecoration(
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16.0))),
                color: colorScheme.tertiaryContainer),
            width: 56.0,
            height: 56.0,
            child: const Icon(Icons.arrow_upward),
          ),
        ),
      )
          : const SizedBox.shrink();
    }

    Widget buildAddDiaryButton() {
      return AnimatedBuilder(
        animation: logic.fabAnimation,
        child: InkWell(
          onTap: () async {
            await logic.toEditPage();
          },
          child: Container(
            decoration: ShapeDecoration(
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16.0))),
                color: colorScheme.primaryContainer),
            width: 140.0,
            height: 56.0,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.edit,
                  color: colorScheme.onPrimaryContainer,
                ),
                const SizedBox(
                  width: 8.0,
                ),
                Text(
                  '新建日记',
                  style: TextStyle(color: colorScheme.onPrimaryContainer),
                ),
              ],
            ),
          ),
        ),
        builder: (context, child) {
          return Transform(
            transform: Matrix4.identity()
              ..scale(pow(logic.fabAnimation.value, 2).toDouble(), logic.fabAnimation.value)
              ..translate(.0, -((56.0 + 8.0)) * logic.fabAnimation.value),
            alignment: FractionalOffset.centerRight,
            child: child,
          );
        },
      );
    }

    Widget buildFabButton() {
      return AnimatedBuilder(
          animation: logic.fabAnimation,
          child: const Icon(Icons.add),
          builder: (context, child) {
            return FloatingActionButton(
              onPressed: () async {
                state.isFabExpanded.value ? await logic.closeFab() : await logic.openFab();
              },
              backgroundColor:
              Color.lerp(colorScheme.primaryContainer, colorScheme.tertiaryContainer, logic.fabAnimation.value),
              child: Transform.rotate(
                angle: 3 * pi / 4 * logic.fabAnimation.value,
                child: child,
              ),
            );
          });
    }

    return GetBuilder<HomeLogic>(
      init: logic,
      assignId: true,
      builder: (logic) {
        return Scaffold(
          drawer: const SideBarComponent(),
          drawerEnableOpenDragGesture: false,
          body: Stack(
            children: [
              NestedScrollView(
                key: state.nestedScrollKey,
                headerSliverBuilder: (context, _) {
                  return [
                    SliverAppBar(
                      title: Tooltip(
                        message: '侧边栏',
                        child: InkWell(
                          onTap: () {
                            Scaffold.of(context).openDrawer();
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  state.customTitleName.isNotEmpty ? state.customTitleName : i18n.appName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.chevron_right)
                            ],
                          ),
                        ),
                      ),
                      automaticallyImplyLeading: false,
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
                          tooltip: '搜索',
                        ),
                        PopupMenuButton(
                          offset: const Offset(0, 46),
                          tooltip: '更多',
                          itemBuilder: (context) {
                            return <PopupMenuEntry<String>>[
                              CheckedPopupMenuItem(
                                checked: state.viewModeType.value == ViewModeType.list,
                                onTap: () async {
                                  await logic.changeViewMode(ViewModeType.list);
                                },
                                child: Text(i18n.homeViewModeList),
                              ),
                              CheckedPopupMenuItem(
                                checked: state.viewModeType.value == ViewModeType.calendar,
                                onTap: () async {
                                  await logic.changeViewMode(ViewModeType.calendar);
                                },
                                child: Text(i18n.homeViewModeCalendar),
                              ),
                            ];
                          },
                        ),
                      ],
                      bottom: PreferredSize(
                        preferredSize: const Size.fromHeight(46.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TabBar(
                            controller: logic.tabController,
                            isScrollable: true,
                            dividerHeight: .0,
                            tabAlignment: TabAlignment.start,
                            indicatorSize: TabBarIndicatorSize.tab,
                            splashFactory: NoSplash.splashFactory,
                            indicator:
                            ShapeDecoration(shape: const StadiumBorder(), color: colorScheme.secondaryContainer),
                            indicatorWeight: .0,
                            indicatorPadding: const EdgeInsets.all(8.0),
                            tabs: buildTabBar(),
                          ),
                        ),
                      ),
                    )
                  ];
                },
                body: switch (state.viewModeType.value) {
                  ViewModeType.list => buildListView(),
                  ViewModeType.calendar => buildDatePicker()
                },
              ),
              //如果fab打开了，显示一个蒙层
              buildModal(),
            ],
          ),
          floatingActionButton: SizedBox(
            height: 56 + (56 + 8),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Obx(() {
                  return buildToTopButton();
                }),
                buildAddDiaryButton(),
                buildFabButton(),
              ],
            ),
          ),
        );
      },
    );
  }
}
