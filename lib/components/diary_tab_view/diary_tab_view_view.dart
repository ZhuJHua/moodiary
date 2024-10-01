import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/values/view_mode.dart';
import 'package:mood_diary/components/diary_card/large_diary_card/large_diary_card_view.dart';
import 'package:mood_diary/components/diary_card/small_diary_card/small_diary_card_view.dart';
import 'package:sliver_tools/sliver_tools.dart';

import 'diary_tab_view_logic.dart';

class DiaryTabViewComponent extends StatelessWidget {
  const DiaryTabViewComponent({super.key, required this.categoryId});

  final String? categoryId;

  @override
  Widget build(BuildContext context) {
    final logicTag = categoryId ?? 'default';
    final logic = Get.put(DiaryTabViewLogic(categoryId: categoryId), tag: logicTag);
    final state = Bind.find<DiaryTabViewLogic>(tag: logicTag).state;
    final i18n = AppLocalizations.of(context)!;

    Widget buildGrid() {
      return SliverMasonryGrid(
        gridDelegate: const SliverSimpleGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 250),
        delegate: SliverChildBuilderDelegate((context, index) {
          return LargeDiaryCardComponent(
            diary: state.diaryList[index],
          );
        }, childCount: state.diaryList.length),
      );
    }

    Widget buildList() {
      return SliverList.builder(
        itemBuilder: (context, index) {
          return SmallDiaryCardComponent(
            tag: index.toString(),
            diary: state.diaryList[index],
          );
        },
        itemCount: state.diaryList.length,
      );
    }

    Widget buildPlaceHolder() {
      return Center(
        child: Obx(() {
          if (state.isFetching.value) {
            return const CircularProgressIndicator();
          } else if (state.diaryList.isEmpty) {
            return Text(i18n.diaryTabViewEmpty);
          } else {
            return const SizedBox.shrink();
          }
        }),
      );
    }

    return GetBuilder<DiaryTabViewLogic>(
        assignId: true,
        init: logic,
        tag: logicTag,
        autoRemove: false,
        builder: (logic) {
          return Stack(
            children: [
              buildPlaceHolder(),
              CustomScrollView(
                slivers: [
                  SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
                  SliverPadding(
                      padding: const EdgeInsets.all(4.0),
                      sliver: Obx(() {
                        return SliverAnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          child: switch (logic.diaryLogic.state.viewModeType.value) {
                            ViewModeType.list => buildList(),
                            ViewModeType.grid => buildGrid(),
                          },
                        );
                      })),
                ],
              ),
            ],
          );
        });
  }
}
