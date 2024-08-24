import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/components/search_card/search_card_view.dart';

import 'search_sheet_logic.dart';

class SearchSheetComponent extends StatelessWidget {
  const SearchSheetComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(SearchSheetLogic());
    final state = Bind.find<SearchSheetLogic>().state;
    final colorScheme = Theme.of(context).colorScheme;
    return GetBuilder<SearchSheetLogic>(
      init: logic,
      assignId: true,
      builder: (logic) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: TextField(
                maxLines: 1,
                controller: logic.textEditingController,
                focusNode: logic.focusNode,
                decoration: InputDecoration(
                  fillColor: colorScheme.secondaryContainer,
                  border: const UnderlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8.0)),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  labelText: '搜索',
                  suffixIcon: IconButton(
                    onPressed: () {
                      logic.search();
                    },
                    icon: const Icon(Icons.search),
                  ),
                ),
              ),
            ),
            const SizedBox(
              height: 2.0,
            ),
            Obx(() {
              return Expanded(
                child: state.isSearching.value
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : ListView.builder(
                        itemCount: state.searchList.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 8.0, bottom: 0.0),
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
                return Text('共有${state.totalCount.value}篇');
              }),
            )
          ],
        );
      },
    );
  }
}
