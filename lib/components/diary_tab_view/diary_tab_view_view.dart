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
      return SliverMasonryGrid(
        gridDelegate: const SliverSimpleGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 250),
        delegate: SliverChildBuilderDelegate((context, index) {
          return LargeDiaryCardComponent(
            diary: state.diaryList[index],
            tabViewTag: tag.toString(),
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
            tabViewTag: tag.toString(),
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

    Widget buildCustomScrollView({required Widget sliver}) {
      return CustomScrollView(
        key: UniqueKey(),
        slivers: [
          SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
          sliver,
        ],
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
          return Stack(
            children: [
              buildPlaceHolder(),
              Obx(() {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: switch (logic.diaryLogic.state.viewModeType.value) {
                    ViewModeType.list => buildCustomScrollView(sliver: Obx(() {
                        return buildList();
                      })),
                    ViewModeType.grid => buildCustomScrollView(sliver: Obx(() {
                        return buildGrid();
                      })),
                  },
                );
              }),
            ],
          );
        });
  }
}
