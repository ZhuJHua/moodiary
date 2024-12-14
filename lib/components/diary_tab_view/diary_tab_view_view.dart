import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/values/view_mode.dart';
import 'package:mood_diary/components/diary_card/large_diary_card/large_diary_card_view.dart';
import 'package:mood_diary/components/diary_card/small_diary_card/small_diary_card_view.dart';
import 'package:sliver_tools/sliver_tools.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

import '../../main.dart';
import 'diary_tab_view_logic.dart';

class DiaryTabViewComponent extends StatelessWidget {
  const DiaryTabViewComponent({super.key, required this.categoryId});

  final String? categoryId;

  @override
  Widget build(BuildContext context) {
    final logicTag = categoryId ?? 'default';
    final logic = Get.put(DiaryTabViewLogic(categoryId: categoryId), tag: logicTag);
    final state = Bind.find<DiaryTabViewLogic>(tag: logicTag).state;

    final size = MediaQuery.sizeOf(context);

    Widget buildGrid() {
      return SliverWaterfallFlow(
        gridDelegate: const SliverWaterfallFlowDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 250),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return LargeDiaryCardComponent(
              diary: state.diaryList[index],
            );
          },
          childCount: state.diaryList.length,
        ),
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
      if (state.isFetching) {
        return const CircularProgressIndicator();
      } else if (state.diaryList.isEmpty) {
        return Text(l10n.diaryTabViewEmpty);
      } else {
        return const SizedBox.shrink();
      }
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        GetBuilder<DiaryTabViewLogic>(
            tag: logicTag,
            id: 'PlaceHolder',
            builder: (_) {
              return buildPlaceHolder();
            }),
        GetBuilder<DiaryTabViewLogic>(
            id: 'TabView',
            tag: logicTag,
            builder: (_) {
              return CustomScrollView(
                primary: true,
                cacheExtent: size.height * 2,
                slivers: [
                  SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
                  SliverPadding(
                    padding: const EdgeInsets.all(4.0),
                    sliver: SliverAnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: switch (logic.diaryLogic.state.viewModeType) {
                        ViewModeType.list => buildList(),
                        ViewModeType.grid => buildGrid(),
                      },
                    ),
                  ),
                ],
              );
            }),
      ],
    );
  }
}
