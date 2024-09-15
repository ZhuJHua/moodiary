import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/values/view_mode.dart';
import 'package:mood_diary/components/diary_card/large_diary_card/large_diary_card_view.dart';
import 'package:mood_diary/components/diary_card/small_diary_card/small_diary_card_view.dart';

import 'diary_tab_view_logic.dart';

class DiaryTabViewComponent extends StatelessWidget {
  const DiaryTabViewComponent({super.key, this.categoryId, required this.tag});

  final String? categoryId;
  final String tag;

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(DiaryTabViewLogic(), tag: tag);
    final state = Bind.find<DiaryTabViewLogic>(tag: tag).state;
    final i18n = AppLocalizations.of(context)!;
    Widget buildGrid() {
      return MasonryGridView.builder(
        gridDelegate: const SliverSimpleGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 250),
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          return LargeDiaryCardComponent(
            diary: state.diaryList.value[index],
            tabViewTag: tag,
          );
        },
        itemCount: state.diaryList.value.length,
      );
    }

    Widget buildList() {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          return SmallDiaryCardComponent(
            tag: index.toString(),
            diary: state.diaryList.value[index],
            tabViewTag: tag,
          );
        },
        itemCount: state.diaryList.value.length,
      );
    }

    return GetBuilder<DiaryTabViewLogic>(
        assignId: true,
        init: logic,
        tag: tag,
        initState: (_) {
          logic.initDiary(categoryId);
        },
        builder: (logic) {
          return Obx(() {
            if (state.isFetching.value) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.diaryList.value.isEmpty) {
              return Center(child: Text(i18n.diaryTabViewEmpty));
            }
            return Obx(() {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: switch (logic.diaryLogic.state.viewModeType.value) {
                  ViewModeType.list => buildList(),
                  ViewModeType.grid => buildGrid(),
                },
              );
            });
          });
        });
  }
}
