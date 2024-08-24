import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:mood_diary/components/diary_card/large_diary_card/large_diary_card_view.dart';
import 'package:mood_diary/components/diary_card/small_diary_card/small_diary_card_view.dart';

import 'home_tab_view_logic.dart';

class HomeTabViewComponent extends StatelessWidget {
  const HomeTabViewComponent({super.key, this.categoryId, required this.tag});

  final String? categoryId;
  final String tag;

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(HomeTabViewLogic(), tag: tag);
    final state = Bind.find<HomeTabViewLogic>(tag: tag).state;

    Widget buildGrid() {
      return MasonryGridView.builder(
        gridDelegate: const SliverSimpleGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 440),
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        shrinkWrap: true,
        itemBuilder: (context, index) {
          final aspect = state.diaryList.value[index].aspect;
          //如果是横图，显示大卡片，竖图或者没有图显示小卡片
          if (aspect != null && aspect > 1.0) {
            return LargeDiaryCardComponent(tag: index.toString(), diary: state.diaryList.value[index]);
          } else {
            return SmallDiaryCardComponent(tag: index.toString(), diary: state.diaryList.value[index]);
          }
        },
        itemCount: state.diaryList.value.length,
      );
    }

    return GetBuilder<HomeTabViewLogic>(
      assignId: true,
      init: logic,
      tag: tag,
      initState: (_) {
        logic.initDiary(categoryId);
      },
      builder: (logic) {
        return Obx(() {
          return state.isFetching.value
              ? const Center(child: CircularProgressIndicator())
              : (state.diaryList.value.isNotEmpty
                  ? buildGrid()
                  : const Center(
                      child: Text('这里一片荒芜'),
                    ));
        });
      },
    );
  }
}
