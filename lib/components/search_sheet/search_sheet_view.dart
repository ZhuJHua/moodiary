import 'package:flutter/material.dart';
import 'package:mood_diary/common/values/border.dart';
import 'package:mood_diary/components/search_card/search_card_logic.dart';
import 'package:mood_diary/components/search_card/search_card_view.dart';
import 'package:mood_diary/main.dart';
import 'package:refreshed/refreshed.dart';

import 'search_sheet_logic.dart';

class SearchSheetComponent extends StatelessWidget {
  const SearchSheetComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(SearchSheetLogic());
    final state = Bind.find<SearchSheetLogic>().state;
    final colorScheme = Theme.of(context).colorScheme;
    return GetBuilder<SearchSheetLogic>(
      assignId: true,
      builder: (_) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(
                  left: 8.0, right: 8.0, top: 8.0, bottom: 4.0),
              child: TextField(
                maxLines: 1,
                controller: logic.textEditingController,
                focusNode: logic.focusNode,
                decoration: InputDecoration(
                  fillColor: colorScheme.secondaryContainer,
                  border: const UnderlineInputBorder(
                    borderRadius: AppBorderRadius.smallBorderRadius,
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  labelText: l10n.diarySearch,
                  suffixIcon: IconButton(
                    onPressed: () {
                      logic.search();
                    },
                    icon: const Icon(Icons.search),
                  ),
                ),
              ),
            ),
            Obx(() {
              return Expanded(
                child: state.isSearching.value
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : ListView.builder(
                        itemCount: state.searchList.length,
                        padding: EdgeInsets.zero,
                        itemBuilder: (context, index) {
                          Bind.lazyPut(() => SearchCardLogic(),
                              tag: index.toString());
                          return Padding(
                            padding: const EdgeInsets.only(
                                left: 8.0, right: 8.0, top: 4.0, bottom: 4.0),
                            child: SearchCardComponent(
                              diary: state.searchList[index],
                              index: index.toString(),
                            ),
                          );
                        }),
              );
            }),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Obx(() {
                return Text(l10n.diarySearchResult(state.totalCount.value));
              }),
            )
          ],
        );
      },
    );
  }
}
