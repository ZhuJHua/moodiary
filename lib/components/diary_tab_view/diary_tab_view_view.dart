import 'package:flutter/material.dart';
import 'package:moodiary/common/values/view_mode.dart';
import 'package:moodiary/components/diary_card/grid_diary_card_view.dart';
import 'package:moodiary/components/diary_card/list_diary_card_view.dart';
import 'package:moodiary/components/loading/loading.dart';
import 'package:moodiary/main.dart';
import 'package:refreshed/refreshed.dart';
import 'package:sliver_tools/sliver_tools.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

import 'diary_tab_view_logic.dart';

class DiaryTabViewComponent extends StatelessWidget {
  const DiaryTabViewComponent({super.key, required this.categoryId});

  final String? categoryId;

  Widget _buildPlaceholder(double height) {
    return SliverToBoxAdapter(
      key: const ValueKey('placeholder'),
      child: SizedBox(
        height: height,
        child: const Align(
          alignment: Alignment.bottomCenter,
          child: EditingLoading(),
        ),
      ),
    );
  }

  Widget _buildEmpty(double height) {
    return SliverToBoxAdapter(
      key: const ValueKey('empty'),
      child: SizedBox(
        height: height,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Text(l10n.diaryTabViewEmpty),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logicTag = categoryId ?? 'default';
    final logic =
        Get.put(DiaryTabViewLogic(categoryId: categoryId), tag: logicTag);
    final state = Bind.find<DiaryTabViewLogic>(tag: logicTag).state;
    final size = MediaQuery.sizeOf(context);
    final placeholderHeight = size.height / 2 - kToolbarHeight - 46;

    Widget buildGrid() {
      return Obx(
        () {
          return SliverWaterfallFlow(
            gridDelegate:
                const SliverWaterfallFlowDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 250),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return GirdDiaryCardComponent(
                  diary: state.diaryList[index],
                );
              },
              childCount: state.diaryList.length,
            ),
          );
        },
        key: const ValueKey('grid'),
      );
    }

    Widget buildList() {
      return Obx(() {
        return SliverList.builder(
          itemBuilder: (context, index) {
            return ListDiaryCardComponent(
              tag: index.toString(),
              diary: state.diaryList[index],
            );
          },
          itemCount: state.diaryList.length,
        );
      }, key: const ValueKey('list'));
    }

    return CustomScrollView(
      cacheExtent: size.height * 2,
      slivers: [
        SliverOverlapInjector(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          sliver: Obx(
            () {
              return SliverAnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                reverseDuration: const Duration(milliseconds: 100),
                child: state.isFetching.value
                    ? _buildPlaceholder(placeholderHeight)
                    : state.diaryList.isEmpty
                        ? _buildEmpty(placeholderHeight)
                        : switch (logic.diaryLogic.state.viewModeType.value) {
                            ViewModeType.list => buildList(),
                            ViewModeType.grid => buildGrid(),
                          },
              );
            },
          ),
        ),
      ],
    );
  }
}
